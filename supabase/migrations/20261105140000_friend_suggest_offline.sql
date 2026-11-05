-- supabase/migrations/20261105140000_friend_suggest_offline.sql
--
-- *** 2026-11-05 已套用到正式庫（user 同意；先試套還原、再正式套）。 ***
-- 要先套好 20261105120000_friend_suggest.sql（這支只改寫它的 mp_suggest_online）。
--
-- user 2026-11-05：「好友建議就算沒有上線也顯示」→ 推薦名單不再只限 90 秒內在線的人：
--   - 其他條件全部照舊（不是好友、雙方沒封鎖、對方開著「讓別人推薦我」、有暱稱、彼此沒有還開著的邀請、
--     不在被拒冷卻期、我沒按過「不要」）。
--   - 排序：在線上的最前面 → 最近上線過的（mp_presence.last_seen 新的在前；那張表一天沒動的列會被 mp_cleanup 清掉）
--     → 其他人照「同一天同一個人看到的順序固定」的亂序。最多 10 位（原本 8）。
--   - 每筆多一個 online（true／false），小鎮畫綠點或灰點。不在線上只透露「不在線上」，不回最後上線時間。
-- 推薦名單只在玩家切到「交朋友」分頁時抓一次（小鎮不輪詢），每次 mp_take 花 3，一樣受限流。

create or replace function public.mp_suggest_online()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
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
    limit 10
  loop
    v_ref := left(md5(gen_random_uuid()::text), 12);
    insert into public.friend_suggest_shown (user_id, other, ref, shown_at)
    values (v_me, r.user_id, v_ref, now())
    on conflict (user_id, other) do update set ref = excluded.ref, shown_at = excluded.shown_at;
    v_list := v_list || jsonb_build_object('ref', v_ref, 'name', r.nickname, 'avatar', r.avatar_preset, 'online', r.online);
  end loop;
  return jsonb_build_object('ok', true, 'on', true, 'list', v_list);
end
$$;
