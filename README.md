# Pengeluaran Toko Rejeki — Aplikasi Pencatat Pengeluaran Toko

Aplikasi Android berbasis **Flutter** untuk mencatat seluruh
pengeluaran Toko Rejeki — offline-first (SQLite), sinkronisasi dua
arah ke **Supabase**, Material 3 hijau-putih ala Apple, font Poppins.
Satu rasa dengan aplikasi kasir Toko Rejeki, bedanya aplikasi ini
khusus untuk **uang keluar**.

## Fitur

- 🔐 **Login gaya aplikasi kasir**: pilih NAMA anggota — owner (Nanda)
  pakai **sandi khusus** (show/hide sandi, bisa diganti di Pengaturan),
  keluarga (Kasir, Donny, Sonny, Yono) **tap nama saja**; tetap masuk
  sampai Logout/Ganti Pengguna. Sinkron cloud otomatis lewat akun
  robot perangkat di belakang layar (tanpa menyuruh pengguna apa pun)
- 👥 **Daftar nama mengikuti aplikasi kasir** (`store_members`):
  tambah/ubah/hapus anggota cukup dari **Manajemen Pengguna di aplikasi
  kasir** — layar login aplikasi ini menyesuaikan otomatis setiap
  sinkron; sandi owner aplikasi ini tetap terpisah dan aman
- 📊 **Dashboard**: total hari ini / minggu ini / bulan ini / tahun
  ini, grafik per bulan, pengeluaran terakhir, terbesar bulan ini,
  jumlah transaksi
- ➕ **Tambah/Edit Pengeluaran**: nama, nominal (format Rupiah
  otomatis), kategori, tanggal, jam, metode pembayaran (Tunai,
  Transfer, QRIS, Debit, Kredit, E-Wallet), catatan, **foto nota**
  (kamera/galeri, preview zoom, ganti, hapus)
- 🗂️ **Kategori** bebas tambah/ubah/hapus (nama + warna + ikon);
  bawaan: Belanja Barang, Stok
- 🧾 **Riwayat**: pencarian real-time (nama/kategori/catatan), filter
  kategori, metode, tanggal, urut terbaru/terlama, infinite scroll
- 📄 **Laporan** harian/mingguan/bulanan/tahunan: total, jumlah
  transaksi, rata-rata, kategori terbanyak, terbesar, rincian per
  kategori + **Export PDF / Excel / Share (TXT)**
- 📈 **Laporan Akhir**: **Pemasukan** (ditarik otomatis dari aplikasi
  kasir lewat Supabase) vs **Pengeluaran** = **Laba Bersih** per hari /
  bulan / tahun, lengkap dengan diagram perbandingan + tabel rincian.
  Pemasukan dicache lokal agar tetap terbaca offline. Perlu menjalankan
  **SQL-LAPORAN-AKHIR.sql sekali** di dashboard Supabase (SQL Editor →
  Run) agar pemasukan hidup
- 🗓️ **Kalender bersahabat**: pilih tanggal bebas melompat antara
  5 tahun ke belakang s.d. 6 tahun ke depan (di form pengeluaran &
  label periode laporan cukup diketuk) — sama seperti aplikasi kasir
- 🔄 **Update dari dalam aplikasi** (sama seperti aplikasi kasir):
  saat dibuka, aplikasi mengecek GitHub Releases `xymzxt/apk-pengeluaran`;
  bila ada versi baru muncul layar **"Update Sekarang"** — APK terunduh
  & terpasang menimpa versi lama tanpa uninstall dan data tetap aman
- 🖼️ **Foto nota** tersimpan di Supabase Storage (privat per pemilik)
  dan tetap terlihat offline dari file lokal
- ✈️ **Offline-first**: semua fitur jalan tanpa internet; sinkron
  otomatis saat online (Last Updated Wins + soft delete) —
  notifikasi "X terkirim, Y ditarik"
- 🌙 **Dark & Light Mode**, jam realtime + chip Online/Offline di
  setiap halaman, loading skeleton, snackbar notifikasi, dialog
  konfirmasi hapus
- 💾 **Backup & Restore database**, Ubah Password, Tentang Aplikasi
- 🛡️ **RLS Supabase** — data tiap akun hanya bisa diakses pemiliknya

## Arsitektur

- Offline-first: SQLite (sqflite) adalah sumber kebenaran; Supabase
  = salinan cloud antar-perangkat
- State management: Riverpod
- Repository pattern: `lib/database/expense_repository.dart`
- Sinkronisasi: `lib/services/sync_service.dart` (push lalu pull,
  foto nota ikut terdorong/tarik)

## Struktur Folder

    lib/
      core/        (config env, konstanta, tema)
      database/    (helper SQLite, repository)
      models/      (CategoryModel, ExpenseModel)
      services/    (supabase, sinkron, export, foto, backup, file saver)
      providers/   (auth, tema, konektivitas, data, dashboard, laporan)
      screens/     (splash, login, beranda, riwayat, detail, form,
                    kategori, laporan, pengaturan)
      widgets/     (jam realtime, chip online, kartu statistik, dll.)
      utils/       (format, validator, periode, ikon, transisi)

## Setup Database (sekali)

1. Buka Supabase Dashboard project yang sama dengan aplikasi kasir.
2. **SQL Editor** → paste seluruh isi
   `supabase/migrations/20260804000010_pengeluaran.sql` → **Run**
   (membuat 3 tabel: `expense_users`, `expense_categories`,
   `expenses` + RLS + bucket `nota-pengeluaran`).
3. Buka aplikasi → pilih nama. Owner masuk dengan sandi bawaan
   **nanda123** (segera ganti di Pengaturan → Ganti Sandi Owner).

## Build APK (GitHub Actions)

Repo ini dibuild otomatis oleh `.github/workflows/flutter-build.yml`
tiap push ke `main`:

- Artifact: **`Pengeluaran-APK`**; Release: `PengeluaranTokoRejeki.apk`
- Secrets yang diperlukan (sama nilainya dengan repo aplikasi kasir):
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_DEVICE_EMAIL`, `SUPABASE_DEVICE_PASSWORD`
  (akun robot perangkat untuk sinkron otomatis — login gaya kasir)

## Lingkungan Pengembangan

```bash
cp .env.example .env   # isi SUPABASE_URL & SUPABASE_ANON_KEY
flutter pub get
flutter run            # Android 8 (API 26) s/d Android 16
```
