-- supabase/migrations/20261104130000_cleanup_cron.sql
--
-- *** 套正式庫前要先問 user。 ***
-- 每天自動清舊資料（2026-11-04）：mp_cleanup()（線上對戰：2 小時沒動的房間作廢、14 天前結束的房間刪除）
-- 與 friend_helps_cleanup()（好友澆水紀錄：14 天前的刪除）。兩支函式在
-- 20261103120000_mp_rooms.sql、20261104120000_friend_farm.sql 裡，只開給 service_role；
-- 這裡用 pg_cron 以資料庫擁有者身分每天跑一次（台灣時間 04:00＝UTC 20:00，用量最低）。
-- 重跑這支不會重複排程：cron.schedule 同名工作會覆蓋。

create extension if not exists pg_cron;

select cron.schedule(
  'silversole-mp-cleanup',
  '0 20 * * *',
  $$select public.mp_cleanup()$$
);

select cron.schedule(
  'silversole-friend-helps-cleanup',
  '5 20 * * *',
  $$select public.friend_helps_cleanup()$$
);
