/// Tema Material 3 aplikasi (Light & Dark) — hijau & putih.
///
/// Struktur sama persis dengan tema aplikasi kasir (v1.0.0, permintaan
/// pemilik: UI konsisten): font Poppins, kartu radius 20 "kaca",
/// AppBar transparan, warna solid khusus dialog & bottom sheet.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Radius standar kartu & input.
  static const double cardRadius = 20;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      surface: Colors.white,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
    );
    return _base(scheme, false);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
    );
    return _base(scheme, true);
  }

  static ThemeData _base(ColorScheme scheme, bool isDark) {
    final base = ThemeData(brightness: scheme.brightness);
    // Seluruh gaya teks memakai warna onSurface tema — di mode gelap
    // otomatis jadi putih terang.
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      // Scaffold transparan: gradasi latar dilukis MaterialApp.
      scaffoldBackgroundColor: Colors.transparent,

      // --- AppBar melayang di atas gradasi ---
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),

      // --- Kartu "kaca": border + shadow di setiap box (SPEC) ---
      cardTheme: CardThemeData(
        color: AppColors.cardFill(isDark),
        elevation: 6,
        shadowColor: AppColors.cardShadow(isDark),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: AppColors.cardBorder(isDark)),
        ),
      ),

      // --- Isian teks ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : AppColors.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.cardBorder(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.cardBorder(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // --- Tombol ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),

      // --- SnackBar mengambang (notifikasi sukses/gagal — SPEC) ---
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // --- Dialog konfirmasi solid (wajib sebelum hapus — SPEC) ---
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: isDark ? AppColors.sheetDark : AppColors.sheetLight,
      ),

      // --- Bottom sheet solid agar terbaca ---
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.sheetDark : AppColors.sheetLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // --- Navigasi bawah transparan; pil "kaca" dibentuk di
      // screens/main_navigation.dart ---
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.20),
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : scheme.outlineVariant,
      ),
    );
  }
}
