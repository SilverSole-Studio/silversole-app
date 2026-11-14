-- 2026-11-14 好友對戰邀請：對方剛按「不要」時照實講，不再跟「邀請太多」共用 invitee_busy
--
-- user：「好友邀請又跳繁忙中」。查下來是對方按過「不要」（mp_declines 5 分鐘冷卻），
-- 前端卻顯示「對方忙碌中」，看起來像系統壞掉。
-- 改法：mp_invite、mp_invite_to 的冷卻那一段改回
--   { ok:false, reason:'invitee_declined', wait_s:<還要等幾秒> }
-- 待回覆邀請 ≥5 那一段維持 invitee_busy。冷卻時間、限流、權限都不動。
-- 網頁端（laojie-world c15ec87）已同步：invitee_declined 顯示「對方剛說下次再玩，約 N 分鐘後可以再邀請」。
-- 2026-11-14 已由 Claude 經 user 同意套到東京正式庫（imeoncydtgyywbovjxwq）；這份是紀錄＋給新環境重建用。
-- 寫法：直接改現有函式定義裡那一段（找不到就報錯，不會默默略過），CREATE OR REPLACE 保留原本的 EXECUTE 權限。

do $$
declare
  f text;
  d text;
  old text := $o$  if v_until is not null and v_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;$o$;
  new text := $n$  if v_until is not null and v_until > now() then
    -- 2026-11-14 對方剛按「不要」：照實回 invitee_declined＋還要等幾秒（前端顯示「對方剛說下次再玩，約 N 分鐘後可以再邀請」）
    return jsonb_build_object('ok', false, 'reason', 'invitee_declined', 'wait_s', ceil(extract(epoch from v_until - now()))::int);
  end if;$n$;
begin
  foreach f in array array['public.mp_invite(uuid,text)', 'public.mp_invite_to(uuid,uuid)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position(new in d) > 0 then
      continue; -- 已經是新版
    end if;
    if position(old in d) = 0 then
      raise exception 'mp_invite_declined: % 找不到要換的那一段', f;
    end if;
    execute replace(d, old, new);
  end loop;
end $$;
