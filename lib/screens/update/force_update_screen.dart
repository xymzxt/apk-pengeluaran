/// Layar pembaruan (v1.2.0, permintaan pemilik — sama persis dengan
/// aplikasi kasir): jika GitHub Releases memiliki versi lebih baru,
/// layar ini tampil saat aplikasi dibuka; pengguna cukup menekan
/// "Update Sekarang" — APK diunduh & terpasang MENIMPA versi lama
/// (kunci tanda tangan sama) sehingga seluruh data tetap aman.
library;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/app_constants.dart';
import '../../services/update_service.dart';
import '../../widgets/app_logo.dart';

class ForceUpdateScreen extends StatefulWidget {
  final UpdateInfo info;

  const ForceUpdateScreen({super.key, required this.info});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  /// Unduh APK lalu buka pemasang Android.
  Future<void> _update() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    final path = await UpdateService().downloadApk(
      widget.info.apkUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _downloading = false;
        _error = 'Unduhan gagal. Periksa internet lalu coba lagi.';
      });
      return;
    }

    // Pada pemasangan pertama kali, Android dapat meminta izin
    // "instal aplikasi dari sumber ini" (cukup disetujui sekali).
    final result = await OpenFilex.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      setState(() {
        _downloading = false;
        _error = 'Pemasang tidak terbuka (${result.message}). '
            'Tap "Update Sekarang" untuk mencoba lagi.';
      });
      return;
    }
    // Bila pengguna kembali tanpa memasang, layar ini tetap tampil
    // dan tombol bisa ditekan ulang.
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Tombol kembali dinonaktifkan: update bersifat wajib, sama
      // seperti aplikasi kasir (permintaan pemilik).
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 76)),
                  const SizedBox(height: 24),
                  Icon(
                    Icons.system_update_alt_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Versi ${widget.info.version} Tersedia',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${AppConstants.appName} perlu diperbarui sebelum bisa '
                    'dipakai. Tenang — update terpasang menimpa versi lama '
                    'dan seluruh data tetap aman.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 20),
                  if (widget.info.notes.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.info.notes,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_downloading) ...[
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _progress > 0
                          ? 'Mengunduh ${(_progress * 100).toStringAsFixed(0)}%...'
                          : 'Menghubungi server...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _update,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Update Sekarang'),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
