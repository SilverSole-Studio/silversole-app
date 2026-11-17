-- supabase/migrations/20261117120000_friend_suggest_pool_20.sql
--
-- *** 尚未套用到正式庫（東京 imeoncydtgyywbovjxwq）。套用前要先問 user、技術長看過。 ***
--
-- user 2026-11-17：「推薦好友也太多人，可以改成固定推薦五個、會刷新？」「正常業界怎麼做」→
-- 照業界：畫面一次 5 個＋「換一批」鈕＋重開頁面時更新，不做計時自動換（遊戲 repo #25 已上線）。
-- 伺服器原本一次最多回 10 個，換一批換一次就繞回來；user 選「放寬到 20 人」。
--
-- 做了什麼：只把 mp_suggest_online() 的 limit 10 改 20，其他一個字都沒動。
--   - 底稿是正式庫目前的定義（2026-11-17 用 pg_get_functiondef 讀出）。那一版來自
--     feat/friend-suggest 分支的 20261105140000_friend_suggest_offline.sql（含離線的人、在線的排前面），
--     那支 migration 沒合進 main；這支把正式庫現況補進 main，之後以這支為準。
--   - 排序照舊：在線的排前面、再依最後上線、最後用「每天換一次」的 md5 固定順序（同一天重抓順序不跳）。
--   - 頁面端 engine/mp.js 的 suggestOnline 原本 slice(0, 10)，要一起改 20（遊戲 repo 另開 PR，先上也不會壞）。
--
-- RPC 濫用自查：花費照舊 mp_take 3；多回 10 筆只多 10 列 friend_suggest_shown upsert，
-- 每筆仍只有 {ref, name, avatar, online}，不回 user id、好友碼。限流與送邀請上限全部不變。

begin;

create or replace function public.mp_suggest_online()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_me uuid := auth.uid();
  v_on boolean;
  v_list jsonb := '[]'::jsonb;
  r record;
  v_ref text;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select suggest_me into v_on from public.profiles where user_id = v_me;
  if v_on is null then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;
  if not v_on then
    return jsonb_build_object('ok', true, 'on', false, 'list', v_list);
  end if;
  for r in
    select p.user_id, p.nickname, p.avatar_preset,
           coalesce(m.last_seen > now() - interval '90 seconds', false) as online
    from public.profiles p
    left join public.mp_presence m on m.user_id = p.user_id
    where p.user_id <> v_me
      and p.suggest_me
      and p.nickname is not null and not p.nickname_removed
      and not exists (
        select 1 from public.friendships f
        where f.user_low = least(v_me, p.user_id) and f.user_high = greatest(v_me, p.user_id))
      and not public.friends_blocked_either(v_me, p.user_id)
      and not exists (
        select 1 from public.friend_requests q
        where q.status in ('pending', 'declined') and q.expires_at > now()
          and ((q.from_user = v_me and q.to_user = p.user_id)
            or (q.from_user = p.user_id and q.to_user = v_me)))
      and not public.friends_cooling(v_me, p.user_id)
      and not exists (
        select 1 from public.friend_suggest_hides h
        where h.user_id = v_me and h.other = p.user_id and h.hidden_until > now())
    order by online desc, m.last_seen desc nulls last,
      md5(v_me::text || p.user_id::text || (now() at time zone 'Asia/Taipei')::date::text)
    limit 20
  loop
    v_ref := left(md5(gen_random_uuid()::text), 12);
    insert into public.friend_suggest_shown (user_id, other, ref, shown_at)
    values (v_me, r.user_id, v_ref, now())
    on conflict (user_id, other) do update set ref = excluded.ref, shown_at = excluded.shown_at;
    v_list := v_list || jsonb_build_object('ref', v_ref, 'name', r.nickname, 'avatar', r.avatar_preset, 'online', r.online);
  end loop;
  return jsonb_build_object('ok', true, 'on', true, 'list', v_list);
end
$function$;

revoke all on function public.mp_suggest_online() from public, anon;
grant execute on function public.mp_suggest_online() to authenticated;

commit;
