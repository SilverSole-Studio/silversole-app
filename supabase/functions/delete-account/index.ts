// supabase/functions/delete-account/index.ts
//
// Deletes the calling user's account (App Store guideline 5.1.1(v)).
//
//   POST /functions/v1/delete-account   Authorization: Bearer <user JWT>
//   200 { ok: true }      the account is gone
//   401 { error }         no valid user token (the app treats this as "already gone")
//   405 { error }         not a POST
//   500 { error }         the account could not be deleted
//
// Order matters:
//   1. Resolve the caller from their own JWT — never from the request body, so
//      nobody can delete someone else's account.
//   2. Remove their avatar photos (storage objects are not deleted by any FK).
//   3. Remove their `user_devices` rows: `user_devices.user_id` references
//      auth.users with ON DELETE NO ACTION, so deleteUser fails while any exist.
//   4. auth.admin.deleteUser — everything in the friends schema (profiles and
//      what hangs off it) cascades from auth.users.
//
// Steps 2 and 3 are best effort for *missing* things: the friends migrations
// (and the avatars bucket) may not be applied to a project yet, so a missing
// bucket or table is logged and skipped. A real failure to delete rows that
// exist would make step 4 fail, which is reported as a 500.
//
// Mobile only, so no CORS. The function checks the token itself, so it works
// whether or not it is deployed with --no-verify-jwt.

import { createClient } from 'npm:@supabase/supabase-js@2';

const AVATARS_BUCKET = 'avatars';

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'unauthorized' }, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    console.error('delete-account: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing');
    return json({ error: 'server_misconfigured' }, 500);
  }

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Who is asking. getUser(token) asks the Auth server, so an expired,
  //    forged or already-deleted user's token is rejected here.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: 'unauthorized' }, 401);
  }
  const userId = user.id;

  // 2. Avatar photos live under avatars/{user_id}/.
  try {
    const { data: files, error: listError } = await admin.storage
      .from(AVATARS_BUCKET)
      .list(userId, { limit: 1000 });
    if (listError) {
      console.warn(`delete-account: listing avatars skipped: ${listError.message}`);
    } else if (files && files.length > 0) {
      const paths = files.map((f) => `${userId}/${f.name}`);
      const { error: removeError } = await admin.storage
        .from(AVATARS_BUCKET)
        .remove(paths);
      if (removeError) {
        console.warn(`delete-account: removing avatars failed: ${removeError.message}`);
      }
    }
  } catch (e) {
    console.warn(`delete-account: avatars step skipped: ${e}`);
  }

  // 3. user_devices blocks deleteUser (ON DELETE NO ACTION) while rows exist.
  try {
    const { error: devicesError } = await admin
      .from('user_devices')
      .delete()
      .eq('user_id', userId);
    if (devicesError) {
      console.warn(`delete-account: user_devices step skipped: ${devicesError.message}`);
    }
  } catch (e) {
    console.warn(`delete-account: user_devices step skipped: ${e}`);
  }

  // 4. The account itself; the friends tables cascade from auth.users.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error(`delete-account: deleteUser failed: ${deleteError.message}`);
    return json({ error: 'delete_failed' }, 500);
  }

  return json({ ok: true }, 200);
});
