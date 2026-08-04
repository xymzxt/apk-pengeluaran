/// Root widget aplikasi: tema gelap/terang dan halaman awal.
/// (v1.0.0 — gaya antarmuka sama persis dengan aplikasi kasir,
/// permintaan pemilik; palet diubah hijau-putih sesuai SPEC.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';

class PengeluaranApp extends ConsumerWidget {
  const PengeluaranApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Gaya Apple: lukis gradasi latar di belakang SELURUH halaman —
      // scaffold dibuat transparan pada tema, sehingga gelap = gradasi
      // hijau hutan pekat dan terang = putih mint frosted.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration:
              BoxDecoration(gradient: AppColors.backgroundGradient(isDark)),
          child: child,
        );
      },
      // Bahasa Indonesia untuk seluruh dialog Material bawaan.
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Halaman awal selalu SplashScreen; ia yang memutuskan rute
      // selanjutnya berdasarkan status login owner.
      home: const SplashScreen(),
    );
  }
}
