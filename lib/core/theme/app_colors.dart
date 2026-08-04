/// Palet warna aplikasi — dominan HIJAU & putih (SPEC-PENGELUARAN.md),
/// dengan gaya gradasi & kartu "kaca" ala Apple seperti aplikasi kasir
/// (v1.0.0, permintaan pemilik: sistem UI sama persis, beda warna).
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Aksen hijau modern ---
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryLight = Color(0xFF22C55E);
  static const Color primaryDark = Color(0xFF15803D);

  // --- Latar light mode (tetap dipakai sebagai isian input) ---
  static const Color scaffoldLight = Color(0xFFF6FBF7);
  static const Color inputFillLight = Color(0xFFF0F7F1);

  // --- Latar gradasi ala Apple ---
  /// Gelap: hijau hutan pekat -> zamrud gelap -> hijau lumut dalam.
  static const List<Color> backgroundDark = [
    Color(0xFF04150B),
    Color(0xFF0B2E1A),
    Color(0xFF11331F),
  ];

  /// Terang: putih -> mint lembut -> hijau pucat.
  static const List<Color> backgroundLight = [
    Color(0xFFFFFFFF),
    Color(0xFFE9F9EF),
    Color(0xFFCFF3DC),
  ];

  /// Gradasi latar utama aplikasi (dilukis di belakang semua halaman;
  /// scaffold dibuat transparan).
  static LinearGradient backgroundGradient(bool dark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark ? backgroundDark : backgroundLight,
      );

  // --- Warna "kaca" untuk kartu & panel ---
  static Color cardFill(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.075)
      : Colors.white.withValues(alpha: 0.78);

  /// Bingkai kartu dengan warna berlawanan tema supaya kartu menonjol
  /// di atas gradasi (border + shadow wajib di setiap box — SPEC).
  static Color cardBorder(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.22)
      : const Color(0xFF052E16).withValues(alpha: 0.10);

  static Color cardShadow(bool dark) => dark
      ? Colors.black.withValues(alpha: 0.50)
      : const Color(0xFF166534).withValues(alpha: 0.18);

  /// Warna solid untuk dialog & bottom sheet (tetap buram agar terbaca).
  static const Color sheetDark = Color(0xFF12271A);
  static const Color sheetLight = Colors.white;

  // --- Warna status ---
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // --- Teks ---
  static const Color textPrimary = Color(0xFF0B1F12);
  static const Color textSecondary = Color(0xFF5C6E62);

  // --- Teks khusus mode gelap (selalu TERANG, bukan abu redup) ---
  static const Color textPrimaryDark = Color(0xFFF0FDF4);
  static const Color textSecondaryDark = Color(0xFFC2D6C9);

  // --- Palet colorful untuk pilihan warna kategori ("neo apple
  // colorful") — dipakai pada layar kelola kategori ---
  static const List<Color> categoryPalette = [
    Color(0xFF16A34A), // hijau
    Color(0xFF0EA5E9), // biru langit
    Color(0xFF8B5CF6), // ungu
    Color(0xFFEC4899), // pink
    Color(0xFFEF4444), // merah
    Color(0xFFF97316), // oranye
    Color(0xFFF59E0B), // kuning
    Color(0xFF14B8A6), // tosca
    Color(0xFF6366F1), // nila
    Color(0xFF84CC16), // limau
    Color(0xFF64748B), // abu batu
    Color(0xFF92400E), // cokelat
  ];
}
