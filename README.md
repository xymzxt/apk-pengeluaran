<img src="https://capsule-render.vercel.app/api?type=waving&height=210&color=0:4ADE80,100:166534&section=header&text=Pengeluaran%20Toko%20Rejeki&fontColor=ffffff&fontSize=44&fontAlignY=40&desc=Catat%20setiap%20rupiah%20yang%20keluar&descAlignY=62&descSize=18&animation=fadeIn" width="100%" alt="Pengeluaran Toko Rejeki"/>

<div align="center">
  <img src="assets/logo/pengeluaran.png" width="200" alt="Logo Toko Rejeki"/>
</div>

<h1 align="center">🌿 Pengeluaran Toko Rejeki</h1>

<p align="center"><b>Aplikasi pencatat pengeluaran toko — offline-first, sinkron dua arah,<br/>
dan terhubung dengan aplikasi <a href="https://github.com/xymzxt/apk-kasir">KasirKu</a>. 💚</b></p>

<div align="center">

[![Build](https://github.com/xymzxt/apk-pengeluaran/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/xymzxt/apk-pengeluaran/actions)
[![Versi](https://img.shields.io/github/v/release/xymzxt/apk-pengeluaran?label=versi&color=16A34A)](https://github.com/xymzxt/apk-pengeluaran/releases/latest)
![Flutter](https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Android-8%20%E2%86%92%2016-3DDC84?logo=android&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Auth%20%C2%B7%20DB%20%C2%B7%20Storage-3FCF8E?logo=supabase&logoColor=white)
![Offline](https://img.shields.io/badge/SQLite-offline--first-8B5CF6?logo=sqlite&logoColor=white)

</div>

---

## 🧭 Cara Masuk (login gaya toko)

Buka aplikasi → **pilih NAMA**: keluarga **tap nama saja**, pemilik (Owner) pakai
**sandi khusus** (show/hide, bisa diganti di Pengaturan).

> 👥 **Daftar nama mengikuti aplikasi kasir**: tambah/ubah/hapus anggota cukup dari
> **Manajemen Pengguna · KasirKu** — layar login di sini menyesuaikan otomatis
> setiap sinkron. Sandi aplikasi ini tetap terpisah dan aman.

---

## ✨ Fitur Utama

| 💸 Catat & Foto | 📊 Pantau | 📈 Laporan | 🛠️ Operasional |
|---|---|---|---|
| Nominal format **Rupiah otomatis** | **Dashboard**: hari/minggu/bulan/tahun ini | Periode harian→tahunan + grafik | 🔁 Sinkron 2 arah ・ chip **Online/Offline** |
| Kategori bebas (nama + **warna + ikon**) | Pengeluaran **terbesar & terakhir** | **Export PDF · Excel · Share TXT** | 💾 Backup & restore database |
| Foto nota: kamera/galeri, **zoom, ganti, hapus** | Pencarian real-time + filter + urut | 📈 **Laporan Akhir**: Pemasukan (kasir) − Pengeluaran = **Laba Bersih** + diagram | 🔄 **Update dari dalam aplikasi** |
| Metode Tunai/Transfer/QRIS/Debit/Kredit/E-Wallet | Detail lengkap tiap catatan | 🗓️ Kalender ketuk tanggal: **5 thn lalu – 6 thn depan** | 🌙 Dark & Light · skeleton · notifikasi |
| Tanggal & jam bebas dipilih | — | — | 🖼️ Foto nota tetap kebaca **offline** |

---

## 🧱 Teknologi

| Lapis | Pilihan |
|---|---|
| UI | Flutter · Material 3 · **Poppins** · hijau-putih ala Apple (border + shadow di tiap kartu) |
| State | Riverpod |
| Lokal | SQLite (`sqflite`) — source of truth, 100% fitur jalan tanpa internet |
| Cloud | Supabase (Auth robot perangkat · PostgreSQL + **RLS** · Storage foto nota) — satu project dengan aplikasi kasir |
| Grafik & Berkas | fl_chart · pdf · excel · open_filex · image_picker |

<details><summary>📁 <b>Struktur folder</b></summary>

```
lib/
├── main.dart / app.dart        # titik masuk & tema
├── core/                       # warna, konstanta, env (.env build-time)
├── database/                   # SQLite: app_users, kategori, expenses, income_daily
├── models/                     # expense, kategori, pengguna
├── providers/                  # Riverpod: auth, data, dashboard, laporan, laporan akhir
├── services/                   # sinkronisasi, export, foto, backup, update, file saver
├── screens/                    # splash, login, dashboard, tambah pengeluaran, riwayat,
│                               # kategori, laporan, laporan akhir, pengaturan, update
├── widgets/                    # jam realtime, logo, konfirmasi, stat card, skeleton, ...
└── utils/                      # formatter, validator, periode, rupiah, hash, ikon
```
</details>

---

## 🚀 Build APK Otomatis (tanpa komputer)

1. Upload proyek ini ke GitHub (branch **`main`**).
2. Tab **Actions** → workflow *Flutter Build* jalan sendiri → unduh artifact
   **`Pengeluaran-APK`**, atau file **`PengeluaranTokoRejeki.apk`** di **Releases**.
3. Pasang → selesai. Update berikutnya cukup tekan **"Update Sekarang"** di aplikasi. 🎉

<details><summary>🔑 <b>Secrets GitHub (Actions)</b> yang diperlukan</summary>

| Secret | Fungsi |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Sambungan ke project Supabase |
| `SUPABASE_DEVICE_EMAIL` / `SUPABASE_DEVICE_PASSWORD` | Akun robot perangkat untuk sinkron di belakang layar |
| `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_PASSWORD` | Kunci tanda tangan release (sama dengan aplikasi kasir agar update menimpa tanpa uninstall) |

APK release otomatis diberi izin: `INTERNET` · `ACCESS_NETWORK_STATE` ·
`CAMERA` · `REQUEST_INSTALL_PACKAGES`.
</details>

<details><summary>🗄️ <b>SQL yang dijalankan sekali di Supabase</b></summary>

| File | Isi |
|---|---|
| `SQL-PENGELUARAN.sql` *(= `supabase/migrations/20260804000010_pengeluaran.sql`)* | Tabel `expense_users` · `expense_categories` · `expenses` + RLS + bucket foto nota |
| `SQL-LAPORAN-AKHIR.sql` *(= `supabase/migrations/20260805000000_laporan_akhir.sql`)* | Fungsi `get_daily_income()` — total penjualan per hari dari aplikasi kasir untuk Laporan Akhir |

Keduanya aman dijalankan berulang dan hanya membaca/menambah, tidak mengubah data.
</details>

---

<p align="center">
Dibuat dengan 💚 untuk Toko Rejeki — <i>Belanja Hemat, Rejeki Nikmat</i>.
</p>

<img src="https://capsule-render.vercel.app/api?type=waving&height=120&color=0:166534,100:4ADE80&section=footer" width="100%" alt=""/>
