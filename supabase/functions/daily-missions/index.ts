// supabase/functions/daily-missions/index.ts
//
// Writes the wording of the day's missions with Claude Haiku 5.5: one greeting
// and a reason for each of three missions picked from the app's list.
//
//   POST /functions/v1/daily-missions   Authorization: Bearer <user JWT>
//   body { day: "yyyy-MM-dd", stats: { ... } }   (see logic.ts for the fields)
//
//   200 { mode: "ai", greeting, missions: [{ id, reason }] }
//   200 { mode: "fallback", reason: "not_configured" | "daily_cap" | "busy"
//                                  | "failed" | "error" }
//        the app then plans the day by its own rules
//   400 { error }   the body is not what logic.ts accepts
//   401 { error }   no valid user token
//   405 { error }   not a POST
//   500 { error }   the function itself is not set up
//
// NOT DEPLOYED. Deploying needs, from the owner: the ANTHROPIC_API_KEY secret,
// the `daily_mission_plans` migration, `deno check`, one call against a
// sandbox key, and `supabase functions deploy`. See supabase/README.md.
//
// Order matters:
//   1. Who is asking comes from the caller's JWT, never from the body.
//   2. No ANTHROPIC_API_KEY → fallback, before anything is read or written.
//   3. The body is checked (Content-Length first, then logic.ts: only listed
//      fields, ranges, no free text).
//   4. The caller's own row for the day comes first (logic.ts classifyRow):
//      done → its payload; failed → fallback; pending for under a minute →
//      busy; pending for longer → the caller takes it over with a conditional
//      update (only one of several racing takeovers can match).
//   5. Only when there is no row: the site-wide daily cap, then the claim
//      insert (INSERT ... ON CONFLICT DO NOTHING). Only the request that wins
//      the claim, or the takeover, may call Claude, so one person costs at
//      most one call a day however many requests arrive at once.
//   6. Call Claude. A refusal, an empty or invalid answer marks the row failed.
//   7. Nothing from the model's raw text or from the key ever leaves this
//      function; errors are logged by name and status only.
//
// Mobile only, so no CORS. The function checks the token itself.

import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk@1.3.0';
import { zodOutputFormat } from 'npm:@anthropic-ai/sdk@1.3.0/helpers/zod';
import { z } from 'npm:zod@4.6.7';

import {
  MAX_BODY_CHARS,
  MISSION_IDS,
  PENDING_STALE_MS,
  buildPrompt,
  classifyRow,
  validateInput,
  validateOutput,
} from './logic.ts';

const MODEL = 'claude-haiku-5-5';
const TIMEOUT_MS = 8000;
const DAILY_CAP = 5000;
const TABLE = 'daily_mission_plans';

// The model's answer is checked again by validateOutput (lengths, banned
// words, three distinct ids), so the schema only has to give it a shape.
const Schema = z.object({
  greeting: z.string(),
  missions: z.array(z.object({ id: z.enum(MISSION_IDS), reason: z.string() })),
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function fallback(reason: string): Response {
  return json({ mode: 'fallback', reason }, 200);
}

/** Midnight UTC today, as an ISO string. */
function startOfUtcDay(): string {
  const now = new Date();
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  ).toISOString();
}

function logError(what: string, e: unknown): void {
  // An error's message can quote the request; log only what it is.
  const status = (e as { status?: number } | null)?.status;
  console.error(`daily-missions: ${what}: ${(e as Error)?.name ?? 'Error'} ${status ?? ''}`.trim());
}

Deno.serve(async (req: Request) => {
  try {
    return await handle(req);
  } catch (e) {
    logError('unhandled', e);
    return json({ error: 'internal' }, 500);
  }
});

async function handle(req: Request): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  // 1. Who is asking.
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'unauthorized' }, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    console.error('daily-missions: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing');
    return json({ error: 'server_misconfigured' }, 500);
  }
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: 'unauthorized' }, 401);

  // 2. No key, no call, no write.
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) return fallback('not_configured');

  // 3. The body: the declared size first, so a huge one is never read.
  const declared = Number(req.headers.get('Content-Length'));
  if (Number.isFinite(declared) && declared > MAX_BODY_CHARS) {
    return json({ error: 'bad_request' }, 400);
  }
  let raw: unknown;
  try {
    const text = await req.text();
    if (text.length > MAX_BODY_CHARS) return json({ error: 'bad_request' }, 400);
    raw = JSON.parse(text);
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const input = validateInput(raw);
  if (!input.ok) return json({ error: 'bad_request', field: input.error }, 400);
  const { day, stats } = input.value;
  const userId = user.id;

  // 4. The caller's own row first.
  const { data: row, error: readError } = await admin
    .from(TABLE)
    .select('status, payload, created_at')
    .eq('user_id', userId)
    .eq('day', day)
    .maybeSingle();
  if (readError) {
    console.error(`daily-missions: read failed: ${readError.code ?? 'error'}`);
    return fallback('error');
  }

  if (row) {
    const verdict = classifyRow(row, Date.now());
    if (verdict.kind === 'ai') return json({ mode: 'ai', ...verdict.output }, 200);
    if (verdict.kind === 'failed') return fallback('failed');
    if (verdict.kind === 'busy') return fallback('busy');
    // Stale pending: take it over. Setting created_at to now means a second
    // request racing for the same takeover no longer matches the condition.
    const { data: taken, error: takeError } = await admin
      .from(TABLE)
      .update({ created_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('day', day)
      .eq('status', 'pending')
      .lt('created_at', new Date(Date.now() - PENDING_STALE_MS).toISOString())
      .select('user_id');
    if (takeError) {
      console.error(`daily-missions: takeover failed: ${takeError.code ?? 'error'}`);
      return fallback('error');
    }
    if (!taken || taken.length !== 1) return fallback('busy');
  } else {
    // 5. No row yet: the site-wide cap, then the claim. With ignoreDuplicates
    //    this is INSERT ... ON CONFLICT DO NOTHING and the response holds only
    //    the rows that were really inserted.
    const { count, error: countError } = await admin
      .from(TABLE)
      .select('user_id', { count: 'exact', head: true })
      .gte('created_at', startOfUtcDay());
    if (countError) {
      console.error(`daily-missions: cap check failed: ${countError.code ?? 'error'}`);
      return fallback('error');
    }
    if ((count ?? 0) >= DAILY_CAP) return fallback('daily_cap');

    const { data: claimed, error: claimError } = await admin
      .from(TABLE)
      .upsert({ user_id: userId, day, status: 'pending' }, {
        onConflict: 'user_id,day',
        ignoreDuplicates: true,
      })
      .select('user_id');
    if (claimError) {
      console.error(`daily-missions: claim failed: ${claimError.code ?? 'error'}`);
      return fallback('error');
    }
    // Lost the race to a request that came in between the read and the insert.
    if (!claimed || claimed.length === 0) return fallback('busy');
  }

  // 6. Ask Claude. Whatever happens next, the row must leave "pending", and a
  //    database error while saying so must not become a 500.
  const finish = async (status: 'done' | 'failed', payload: unknown): Promise<void> => {
    try {
      const { error } = await admin
        .from(TABLE)
        .update({ status, payload: payload ?? null })
        .eq('user_id', userId)
        .eq('day', day);
      if (error) console.error(`daily-missions: update failed: ${error.code ?? 'error'}`);
    } catch (e) {
      logError('update threw', e);
    }
  };

  try {
    const client = new Anthropic({ apiKey, timeout: TIMEOUT_MS, maxRetries: 0 });
    const { system, user: content } = buildPrompt(stats, day);
    const response = await client.messages.parse({
      model: MODEL,
      max_tokens: 2000,
      system,
      messages: [{ role: 'user', content }],
      output_config: { effort: 'low', format: zodOutputFormat(Schema) },
    });

    if (response.stop_reason === 'refusal' || response.parsed_output == null) {
      await finish('failed', null);
      return fallback('failed');
    }
    const checked = validateOutput(response.parsed_output);
    if (!checked) {
      await finish('failed', null);
      return fallback('failed');
    }
    await finish('done', checked);
    return json({ mode: 'ai', ...checked }, 200);
  } catch (e) {
    logError('claude call failed', e);
    await finish('failed', null);
    return fallback('failed');
  }
}
