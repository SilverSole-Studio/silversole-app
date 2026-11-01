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
// the `daily_mission_plans` migration, and `supabase functions deploy`.
// See supabase/README.md.
//
// Order matters:
//   1. Who is asking comes from the caller's JWT, never from the body.
//   2. No ANTHROPIC_API_KEY → fallback, before anything is written.
//   3. The body is checked (logic.ts: only listed fields, ranges, no free text).
//   4. A site-wide daily cap on rows.
//   5. Claim the (user, day) row with insert-on-conflict-do-nothing. Only the
//      request that wins the insert may call Claude, so one person costs at
//      most one call a day however many requests arrive at once.
//   6. Call Claude. A refusal, an empty or invalid answer marks the row failed.
//   7. Nothing from the model's raw text or from the key ever leaves this
//      function; errors are logged by name and status only.
//
// Mobile only, so no CORS. The function checks the token itself.

import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { zodOutputFormat } from 'npm:@anthropic-ai/sdk/helpers/zod';
import { z } from 'npm:zod';

import {
  MAX_BODY_CHARS,
  MISSION_IDS,
  buildPrompt,
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

Deno.serve(async (req: Request) => {
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

  // 3. The body.
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

  // 4. Site-wide cap for today.
  const { count, error: countError } = await admin
    .from(TABLE)
    .select('user_id', { count: 'exact', head: true })
    .gte('created_at', startOfUtcDay());
  if (countError) {
    console.error(`daily-missions: cap check failed: ${countError.code ?? 'error'}`);
    return fallback('error');
  }
  if ((count ?? 0) >= DAILY_CAP) return fallback('daily_cap');

  // 5. Claim the row. With ignoreDuplicates this is INSERT ... ON CONFLICT DO
  //    NOTHING and the response holds only the rows that were really inserted.
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
  if (!claimed || claimed.length === 0) {
    // Someone (usually the same person, a moment ago) got there first.
    const { data: row, error: readError } = await admin
      .from(TABLE)
      .select('status, payload')
      .eq('user_id', userId)
      .eq('day', day)
      .maybeSingle();
    if (readError || !row) return fallback('error');
    if (row.status === 'done') {
      const saved = validateOutput(row.payload);
      if (saved) return json({ mode: 'ai', ...saved }, 200);
      return fallback('failed');
    }
    return fallback(row.status === 'pending' ? 'busy' : 'failed');
  }

  // 6. Ask Claude. Whatever happens next, the row must leave "pending".
  const finish = async (status: 'done' | 'failed', payload: unknown) => {
    const { error } = await admin
      .from(TABLE)
      .update({ status, payload: payload ?? null })
      .eq('user_id', userId)
      .eq('day', day);
    if (error) console.error(`daily-missions: update failed: ${error.code ?? 'error'}`);
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
    // The error's message can quote the request; log only what it is.
    const status = (e as { status?: number } | null)?.status;
    console.error(`daily-missions: claude call failed: ${(e as Error)?.name ?? 'Error'} ${status ?? ''}`);
    await finish('failed', null);
    return fallback('failed');
  }
});
