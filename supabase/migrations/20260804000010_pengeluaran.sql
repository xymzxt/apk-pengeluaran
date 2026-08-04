-- =============================================================
-- Migrasi aplikasi PENGELUARAN (proyek Supabase yang sama dengan
-- aplikasi kasir — tabel diberi prefix "expense_" supaya tidak
-- bentrok dengan tabel kasir).
--
-- CARA PAKAI (sekali saja):
--   Supabase Dashboard -> SQL Editor -> paste SELURUH isi file
--   ini -> Run. Setelah itu aplikasi Pengeluaran siap sinkron.
--
-- Isi: 3 tabel (expense_users, expense_categories, expenses)
-- + Row Level Security per-pemilik + bucket Storage untuk foto
-- nota + kebijakan Storage.
-- =============================================================

-- -------------------------------------------------------------
-- 1) TABEL PROFIL OWNER — expense_users
-- -------------------------------------------------------------
create table if not exists public.expense_users (
  id         uuid primary key references auth.users(id) on delete cascade,
  nama       text not null default '',
  email      text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.expense_users enable row level security;

drop policy if exists "expense_users_select_own" on public.expense_users;
create policy "expense_users_select_own" on public.expense_users
  for select using (id = auth.uid());

drop policy if exists "expense_users_insert_own" on public.expense_users;
create policy "expense_users_insert_own" on public.expense_users
  for insert with check (id = auth.uid());

drop policy if exists "expense_users_update_own" on public.expense_users;
create policy "expense_users_update_own" on public.expense_users
  for update using (id = auth.uid());

-- -------------------------------------------------------------
-- 2) TABEL KATEGORI — expense_categories
-- -------------------------------------------------------------
create table if not exists public.expense_categories (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  color      text not null default '#16A34A',
  icon       text not null default 'lainnya',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.expense_categories enable row level security;

drop policy if exists "expense_categories_all_own" on public.expense_categories;
create policy "expense_categories_all_own" on public.expense_categories
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists idx_expense_categories_user_updated
  on public.expense_categories(user_id, updated_at);

-- -------------------------------------------------------------
-- 3) TABEL PENGELUARAN — expenses
-- -------------------------------------------------------------
create table if not exists public.expenses (
  id           uuid primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  category_id  uuid null,
  name         text not null,
  nominal      numeric(15,2) not null default 0,
  method       text not null default 'tunai',
  date         date not null,
  time         text not null default '00:00',
  note         text not null default '',
  photo_remote text null,
  is_deleted   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.expenses enable row level security;

drop policy if exists "expenses_all_own" on public.expenses;
create policy "expenses_all_own" on public.expenses
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists idx_expenses_user_date
  on public.expenses(user_id, date, time);
create index if not exists idx_expenses_user_updated
  on public.expenses(user_id, updated_at);

-- -------------------------------------------------------------
-- 4) updated_at otomatis — memakai fungsi set_updated_at() milik
--    aplikasi kasir bila sudah ada; kalau belum, buat sendiri.
-- -------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_expense_users_updated on public.expense_users;
create trigger trg_expense_users_updated
  before update on public.expense_users
  for each row execute function public.set_updated_at();

drop trigger if exists trg_expense_categories_updated on public.expense_categories;
create trigger trg_expense_categories_updated
  before update on public.expense_categories
  for each row execute function public.set_updated_at();

drop trigger if exists trg_expenses_updated on public.expenses;
create trigger trg_expenses_updated
  before update on public.expenses
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------
-- 5) BUCKET STORAGE untuk foto nota (privat; hanya pemilik folder
--    {user_id}/ yang boleh baca/tulis).
-- -------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('nota-pengeluaran', 'nota-pengeluaran', false)
on conflict (id) do nothing;

drop policy if exists "nota_pengeluaran_select_own" on storage.objects;
create policy "nota_pengeluaran_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'nota-pengeluaran'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "nota_pengeluaran_insert_own" on storage.objects;
create policy "nota_pengeluaran_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'nota-pengeluaran'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "nota_pengeluaran_update_own" on storage.objects;
create policy "nota_pengeluaran_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'nota-pengeluaran'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "nota_pengeluaran_delete_own" on storage.objects;
create policy "nota_pengeluaran_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'nota-pengeluaran'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
