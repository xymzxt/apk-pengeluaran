/// Splash screen — menampilkan logo lalu memutuskan rute:
/// sudah login (sesi tersimpan) -> Beranda; belum -> Login.
/// (SPEC: "Tetap login hingga pengguna logout") — v1.0.0.
///
/// v1.2.0 (permintaan pemilik): gerbang UPDATE dari dalam aplikasi,
/// sama persis seperti aplikasi kasir — bila GitHub Releases punya
/// versi lebih baru, pengguna melewati layar "Update Sekarang"
/// terlebih dahulu. Offline? Aplikasi terbuka normal.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../services/update_service.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../main_navigation.dart';
import '../update/force_update_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Hasil cek pembaruan (v1.2.0) — dijalankan paralel dengan
  /// penundaan logo agar splash tidak bertambah lama.
  late final Future<UpdateInfo?> _updateCheck;

  @override
  void initState() {
    super.initState();

    // Buang sisa APK update lama dari cache (jalan diam-diam).
    unawaited(UpdateService().clearDownloadedApk());

    // Cek versi terbaru di GitHub Releases sejak awal.
    _updateCheck = UpdateService().checkForUpdate();

    _decide();
  }

  /// Gerbang update: bila ada versi lebih baru, selalu lewat layar
  /// update dulu; selain itu masuk normal (beranda/login).
  Future<Widget> _targetWidget() async {
    try {
      final info = await _updateCheck;
      if (info != null) return ForceUpdateScreen(info: info);
    } catch (_) {
      // Tidak pernah menghalangi pembukaan aplikasi.
    }

    // v1.2.2: WAJIB di-await — sebelumnya tidak ditunggu sehingga
    // sesi lama sempat terbaca "kosong" dan pengguna diminta login
    // ulang tiap buka aplikasi (permintaan pemilik).
    await ref.read(authProvider.notifier).refreshFromSession();
    if (ref.read(authProvider).isLoggedIn) return const MainNavigation();
    return const LoginScreen();
  }

  Future<void> _decide() async {
    // Beri waktu logo terlihat + sesi pulih.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final page = await _targetWidget();
    if (!mounted) return;

    if (page is MainNavigation) {
      // Sinkron pasif saat buka aplikasi (best-effort, tidak
      // menghalangi masuk bila gagal/offline).
      // ignore: discarded_futures
      SyncService.instance.syncNow();
    }
    Navigator.of(context).pushReplacement(fadeRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 108),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              AppConstants.appTagline,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
