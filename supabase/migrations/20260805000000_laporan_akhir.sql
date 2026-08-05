-- =====================================================================
-- LAPORAN AKHIR — v1.1.0 (permintaan pemilik)
-- ---------------------------------------------------------------------
-- Dijalankan SEKALI di dashboard Supabase:
--   SQL Editor -> New query -> tempel seluruh isi file ini -> Run.
--
-- Fungsi baru `get_daily_income(p_from, p_to)` membaca TOTAL PENJUALAN
-- per hari dari tabel aplikasi kasir (public.sales). Dipakai oleh
-- aplikasi Pengeluaran Toko Rejeki untuk halaman Laporan Akhir:
--
--   LABA BERSIH = PEMASUKAN (dari aplikasi kasir) - PENGELUARAN
--
-- Kenapa pakai fungsi? Supabase REST tidak bisa GROUP BY tanggal,
-- jadi total harian dihitung di database supaya cepat & hemat data.
--
-- KEAMANAN: fungsi tetap membatasi data pada TOKO MILIK SENDIRI lewat
-- current_store_id() — pola yang sama dengan aplikasi kasir — sehingga
-- toko lain tidak akan bisa melihat angka penjualan toko ini.
-- Transaksi yang sudah dihapus (deleted_at) / di-void tidak dihitung.
-- =====================================================================

create or replace function public.get_daily_income(p_from date, p_to date)
returns table (day date, total numeric)
language sql
stable
security definer
set search_path = public
as $$
  select
    (s.created_at at time zone 'Asia/Jakarta')::date as day,
    sum(s.total)::numeric(14,2)                       as total
  from public.sales s
  where s.store_id = public.current_store_id()
    and s.deleted_at is null
    and s.status = 'completed'
    and (s.created_at at time zone 'Asia/Jakarta')::date
        between p_from and p_to
  group by 1
  order by 1
$$;

-- Akun robot perangkat boleh memanggil fungsi ini.
grant execute on function public.get_daily_income(date, date) to authenticated;
