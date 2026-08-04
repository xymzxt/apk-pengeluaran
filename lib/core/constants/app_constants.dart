/// Konstanta global aplikasi Pengeluaran Nanda Store (v1.0.0).
library;

class AppConstants {
  AppConstants._();

  // --- Identitas aplikasi ---
  static const String appName = 'Pengeluaran Nanda Store';
  static const String appTagline = 'Catat setiap rupiah yang keluar';
  static const String appVersion = '1.0.0';

  // --- Kunci SharedPreferences ---
  static const String prefThemeMode = 'theme_mode';
  static const String prefLastPush = 'exp_last_push';
  static const String prefLastPull = 'exp_last_pull';

  // --- Database lokal ---
  static const String dbName = 'pengeluaran.db';
  static const int dbVersion = 1;

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
