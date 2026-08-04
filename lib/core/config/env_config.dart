/// Membaca konfigurasi environment dari file `.env`.
///
/// Sama seperti aplikasi kasir: URL & Anon Key TIDAK boleh ditulis
/// langsung di source code. Jika `.env` belum diisi/valid, aplikasi
/// otomatis berjalan dalam mode offline penuh (SQLite saja).
///
/// v1.0.0: hanya 2 kunci (tidak ada akun robot) — login memang
/// diperuntukkan khusus OWNER sesuai SPEC-PENGELUARAN.md.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  /// URL project Supabase, contoh: https://xxxx.supabase.co
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']?.trim() ?? '';

  /// Anon key Supabase (aman disimpan di aplikasi karena dilindungi RLS).
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  /// `true` jika konfigurasi Supabase valid sehingga sinkronisasi aktif.
  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 20;

  // --- Akun "robot perangkat" (v1.0.1, permintaan pemilik: login
  // aplikasi bergaya kasir, jadi sinkron cloud ditangani robot di
  // belakang layar — sama persis dengan aplikasi kasir v1.5.8) ---
  // Kredensial robot ditanam saat build dari GitHub Secrets. HP mana
  // pun otomatis login cloud dengan akun ini tanpa disuruh siapa pun.
  static String get deviceEmail =>
      dotenv.env['SUPABASE_DEVICE_EMAIL']?.trim() ?? '';

  static String get devicePassword =>
      dotenv.env['SUPABASE_DEVICE_PASSWORD']?.trim() ?? '';

  /// `true` jika akun robot disediakan saat build.
  static bool get hasDeviceAccount =>
      deviceEmail.contains('@') && devicePassword.length >= 6;
}
