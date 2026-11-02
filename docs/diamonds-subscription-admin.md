# 鑽石與訂閱：管理者手動開通

還沒接金流（user 2026-11-02：先手動開通）。App 裡的「已訂閱」以伺服器為準：`subscriptions` 表裡自己那一列，`active_until >= 今天（台灣日期）`才算訂閱中。一般使用者只讀得到自己那一列，寫入只有管理者（Supabase SQL editor、service role）。

設計與數字：總倉庫 `02_產品/鞋墊_SilverSole/_鑽石設計_2026-11-02.md`。資料表與函式：`supabase/migrations/20261102120000_diamonds.sql`（**還沒套用到正式庫，套用前要先問 user**）。

## 開通或續期

在 Supabase 的 SQL editor 跑。`active_until` 是**最後一個有效日**（含當天，台灣日期）。

依 email：

```sql
insert into public.subscriptions (user_id, active_until, source)
select id, date '2026-12-31', 'manual'
from auth.users
where email = 'someone@example.com'
on conflict (user_id) do update
  set active_until = excluded.active_until,
      updated_at = now();
```

依 user id：

```sql
insert into public.subscriptions (user_id, active_until, source)
values ('00000000-0000-0000-0000-000000000000', date '2026-12-31', 'manual')
on conflict (user_id) do update
  set active_until = excluded.active_until,
      updated_at = now();
```

跑完先看一下有沒有真的寫到人（email 打錯會 0 列）：

```sql
select u.email, s.active_until
from public.subscriptions s join auth.users u on u.id = s.user_id
where u.email = 'someone@example.com';
```

使用者那邊：開 App 的訂閱頁或遊戲分頁就會重問伺服器，不用重新登入。

## 取消

兩種做法，擇一：

```sql
-- 立刻停：把最後有效日設成昨天（台灣日期）
update public.subscriptions
set active_until = (now() at time zone 'Asia/Taipei')::date - 1,
    updated_at = now()
where user_id = (select id from auth.users where email = 'someone@example.com');
```

或什麼都不做，讓它自己過期（`active_until` 過了就不再賺鑽石）。

**鑽石保留 3 個月：** 最後有效日之後 3 個月內餘額還在、但不能再賺；超過就在下次查餘額或賺鑽石時寫一筆 `expire` 把餘額歸零。如果那人過了 3 個月才又訂閱，管理者改 `active_until` 的當下，資料庫會先把舊餘額歸零（trigger），新的一期從 0 開始。3 個月內再訂閱，餘額照留。

## 查帳

```sql
select day, delta, reason, ref, created_at
from public.diamond_ledger
where user_id = (select id from auth.users where email = 'someone@example.com')
order by id;
```

帳本只增不改（UPDATE 會被擋）。真的記錯了，補一筆反向的紀錄，不要改舊列。

## 注意

- 沒有開通的帳號，App 照常能用，只是賺不到鑽石、兌換站的實物分頁停在「訂閱解鎖」。
- 運動分鐘數是 App 回報的（伺服器沒有原始鞋墊資料），所以最壞情況是有人假報、當月拿滿 300 鑽石（約 NT$30）。這是已付 149 的人，損失有上限。
- debug 版與開發者模式的「測試用：假裝已訂閱」只改畫面，伺服器不認，不會發鑽石。
