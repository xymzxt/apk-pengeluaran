/// Titik masuk aplikasi Pengeluaran Nanda Store.
///
/// Urutan inisialisasi (sama persis dengan aplikasi kasir):
/// 1. Muat file `.env` (opsional — tanpa file ini aplikasi offline penuh).
/// 2. Siapkan data locale Indonesia (jam realtime & format tanggal).
/// 3. Inisialisasi Supabase (otomatis dilewati jika belum dikonfigurasi).
/// 4. Jalankan aplikasi di dalam [ProviderScope] (Riverpod).
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // File .env dibuat otomatis oleh GitHub Actions saat build, atau
  // disalin manual dari .env.example saat development.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Tanpa .env aplikasi tetap berjalan (mode offline penuh).
  }

  // Locale Indonesia untuk DateFormat (waktu realtime, laporan, dll.).
  await initializeDateFormatting('id_ID');

  // Supabase: no-op jika konfigurasi belum diisi.
  await SupabaseService.instance.init();

  runApp(const ProviderScope(child: PengeluaranApp()));
}
