/// Splash screen — menampilkan logo lalu memutuskan rute:
/// sudah login (sesi tersimpan) -> Beranda; belum -> Login.
/// (SPEC: "Tetap login hingga pengguna logout") — v1.0.0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../main_navigation.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // Beri waktu logo terlihat + sesi pulih.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    ref.read(authProvider.notifier).refreshFromSession();
    final loggedIn = ref.read(authProvider).isLoggedIn;

    if (loggedIn) {
      // Sinkron pasif saat buka aplikasi (best-effort, tidak
      // menghalangi masuk bila gagal/offline).
      // Catatan: sinkron manual tetap tersedia di Beranda/Pengaturan.
      // ignore: discarded_futures
      SyncService.instance.syncNow();
      Navigator.of(context)
          .pushReplacement(fadeRoute(const MainNavigation()));
    } else {
      Navigator.of(context)
          .pushReplacement(fadeRoute(const LoginScreen()));
    }
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
              'Pengeluaran',
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
