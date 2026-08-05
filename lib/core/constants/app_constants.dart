/// Konstanta global aplikasi Pengeluaran Toko Rejeki (v1.0.0).
library;

class AppConstants {
  AppConstants._();

  // --- Identitas aplikasi ---
  static const String appName = 'Pengeluaran Toko Rejeki';
  static const String appTagline = 'Catat setiap rupiah yang keluar';
  // v1.0.1 (permintaan pemilik): login diubah ke gaya aplikasi kasir
  // — pilih NAMA (owner pakai sandi khusus, keluarga tap nama saja);
  // sinkron cloud ditangani akun robot perangkat di belakang layar.
  static const String appVersion = '1.2.1';

  // --- Kunci SharedPreferences ---
  static const String prefThemeMode = 'theme_mode';
  static const String prefLastPush = 'exp_last_push';
  static const String prefLastPull = 'exp_last_pull';
  // v1.0.1: sesi login lokal (id pengguna yang sedang masuk).
  static const String prefSessionUser = 'session_user';
  // v1.1.0: capaian terakhir tarik pemasukan harian (Laporan Akhir).
  static const String prefLastIncomePull = 'exp_last_income_pull';

  // --- Database lokal ---
  static const String dbName = 'pengeluaran.db';
  // v1: skema awal; v2 (rilis 1.0.1): tabel app_users untuk login
  // gaya kasir (permintaan pemilik); v3 (rilis 1.1.0): tabel
  // income_daily — cache pemasukan harian dari aplikasi kasir
  // (permintaan pemilik, untuk Laporan Akhir).
  static const int dbVersion = 3;

  // --- Pengguna bawaan (v1.0.1, permintaan pemilik) ---
  // Sama dengan anggota aplikasi kasir: owner pakai sandi khusus,
  // keluarga tinggal tap nama. Sandi owner bisa diganti di Pengaturan.
  static const List<Map<String, String>> defaultUsers = [
    {'id': 'local-owner', 'name': 'Nanda', 'role': 'owner'},
    {'id': 'local-kasir', 'name': 'Kasir', 'role': 'keluarga'},
    {'id': 'local-donny', 'name': 'Donny', 'role': 'keluarga'},
    {'id': 'local-sonny', 'name': 'Sonny', 'role': 'keluarga'},
    {'id': 'local-yono', 'name': 'Yono', 'role': 'keluarga'},
  ];

  /// Sandi owner bawaan (owner disarankan mengganti di Pengaturan).
  static const String defaultOwnerPassword = 'nanda123';

  // --- Nama tabel Supabase ---
  // Catatan: prefix "expense_" karena tabel `users`/`categories` polos
  // sudah dipakai aplikasi kasir pada project Supabase yang sama
  // (dipakai bersama agar tidak perlu project & SMTP baru).
  static const String tableUsers = 'expense_users';
  static const String tableCategories = 'expense_categories';
  static const String tableExpenses = 'expenses';

  /// Bucket Storage untuk foto nota (publik, path: {uid}/{expenseId}.jpg).
  static const String storageBucket = 'nota-pengeluaran';

  /// Ruang kosong bawah agar konten tidak tertutup pil navigasi kaca
  /// (gaya sama dengan aplikasi kasir: pil 68 + margin 12 + napas 16).
  static const double floatingNavClearance = 96;

  // --- Metode pembayaran sesuai SPEC-PENGELUARAN.md ---
  static const List<Map<String, String>> paymentMethods = [
    {'code': 'tunai', 'label': 'Tunai'},
    {'code': 'transfer', 'label': 'Transfer'},
    {'code': 'qris', 'label': 'QRIS'},
    {'code': 'debit', 'label': 'Debit'},
    {'code': 'kredit', 'label': 'Kredit'},
    {'code': 'ewallet', 'label': 'E-Wallet'},
  ];

  /// Label metode pembayaran dari kodenya (fallback: kode apa adanya).
  static String paymentLabel(String code) {
    for (final m in paymentMethods) {
      if (m['code'] == code) return m['label']!;
    }
    return code;
  }

  // --- Kategori bawaan sesuai SPEC (dapat diubah/dihapus pengguna) ---
  static const List<Map<String, String>> defaultCategories = [
    {'nama': 'Belanja Barang', 'warna': '#16A34A', 'icon': 'belanja'},
    {'nama': 'Stok', 'warna': '#F59E0B', 'icon': 'stok'},
  ];
}
