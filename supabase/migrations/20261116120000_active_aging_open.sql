-- supabase/migrations/20261116120000_active_aging_open.sql
--
-- 銀足樂齡模式改成「登入就能用」（user 2026-11-16：入口直接打開，不要邀請碼；
-- 之後官網賣課程包時再用開通碼）。
--
-- 只換 aa_gate：
--   - 沒有角色列＝當作 instructor（登入的人都能開課、記錄自己的場次）。
--   - 角色列被停用（revoked_at 有值）＝一樣擋掉（not_member），公司仍可停權。
--   - 有角色列就照原本的 role（assistant 仍是 assistant）。
-- 其餘不變：每人限流、場次只看得到自己的（aa_session_for 仍檢查成員）、
-- 範圍與白名單檢查、稽核。邀請碼表與 aa_invite_redeem 保留，之後改成開通碼用。

create or replace function public.aa_gate(p_cost real, p_need_role boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_role text;
  v_revoked boolean;
begin
  if v_me is null then
    return jsonb_build_object('reason', 'signed_out');
  end if;
  if not public.aa_take(v_me, p_cost) then
    return jsonb_build_object('reason', 'rate_limited');
  end if;
  select r.role, r.revoked_at is not null into v_role, v_revoked
  from public.aa_roles r
  where r.user_id = v_me;
  if coalesce(v_revoked, false) then
    if p_need_role then
      return jsonb_build_object('reason', 'not_member');
    end if;
    return jsonb_build_object('uid', v_me, 'role', null);
  end if;
  return jsonb_build_object('uid', v_me, 'role', coalesce(v_role, 'instructor'));
end
$$;

revoke all on function public.aa_gate(real, boolean) from public, anon, authenticated;
