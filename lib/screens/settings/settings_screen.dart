/// Halaman Pengaturan (v1.0.0) — sesuai SPEC:
/// Profil (nama & email), Ubah Password, Dark Mode, Backup Database,
/// Restore Database, Tentang Aplikasi, Logout. Plus sinkron manual.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/theme_provider.dart';
import '../../services/backup_service.dart';
import '../../services/sync_service.dart';
import '../../utils/page_transitions.dart';
import '../../utils/validators.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/realtime_clock.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _runGuarded(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final message = await action();
    if (mounted) {
      setState(() => _busy = false);
      if (message != null) showAppSnackBar(context, message);
    }
  }

  // -----------------------------------------------------------
  // AKSI
  // -----------------------------------------------------------
  Future<String?> _editName() async {
    final auth = ref.read(authProvider);
    final controller = TextEditingController(text: auth.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama tampilan',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved != true) return null;
    await ref.read(authProvider.notifier).updateName(controller.text);
    controller.dispose();
    return 'Nama berhasil diubah.';
  }

  /// Ganti SANDI OWNER lokal (v1.0.1 — login gaya kasir, permintaan
  /// pemilik). Verifikasi sandi lama terhadap hash tersimpan.
  Future<String?> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Ganti Sandi Owner'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Sandi lama',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(
                            () => obscureOld = !obscureOld),
                      ),
                    ),
                    validator: (v) => Validators.required(v, 'Sandi lama'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Sandi baru (min. 4 karakter)',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(
                            () => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      final empty = Validators.required(v, 'Sandi baru');
                      if (empty != null) return empty;
                      if (v!.length < 4) {
                        return 'Sandi baru minimal 4 karakter';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) {
      oldController.dispose();
      newController.dispose();
      return null;
    }
    final result = await ref
        .read(authProvider.notifier)
        .changeOwnerPassword(oldController.text, newController.text);
    oldController.dispose();
    newController.dispose();
    if (!result.ok) {
      if (mounted) {
        showAppSnackBar(context, result.message, isError: true);
      }
      return null;
    }
    return result.message;
  }

  Future<void> _confirmLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Keluar / Ganti Pengguna?',
      message: 'Kamu akan kembali ke layar pilih nama. '
          'Seluruh data pengeluaran di HP ini tetap aman.',
      confirmText: 'Keluar',
      danger: true,
    );
    if (!ok) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        fadeRoute(const LoginScreen()),
        (route) => false,
      );
    }
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Text('Pengaturan',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const RealtimeClock(),
            const SizedBox(height: 16),

            // --- PROFIL (SPEC) ---
            _sectionTitle(theme, 'Profil'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primary
                          .withValues(alpha: 0.14),
                      child: Icon(Icons.person_rounded,
                          color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.name.isEmpty ? 'Belum masuk' : auth.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            auth.isOwner
                                ? 'Owner toko'
                                : 'Keluarga',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ubah nama',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _busy ? null : () =>
                          _runGuarded(_editName),
                    ),
                  ],
                ),
              ),
            ),

            // --- AKUN ---
            _sectionTitle(theme, 'Akun'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  // Ganti sandi hanya relevan untuk owner (v1.0.1).
                  if (auth.isOwner) ...[
                    _menuTile(
                      icon: Icons.lock_reset_rounded,
                      color: AppColors.info,
                      title: 'Ganti Sandi Owner',
                      subtitle: 'Ubah sandi khusus owner saat masuk',
                      onTap: _busy ? null : () => _runGuarded(_changePassword),
                    ),
                    const Divider(height: 1, indent: 56),
                  ],
                  _menuTile(
                    icon: Icons.sync_rounded,
                    color: AppColors.primary,
                    title: 'Sinkronisasi Sekarang',
                    subtitle: auth.cloudEmail.isEmpty
                        ? 'Cloud belum terhubung'
                        : 'Cloud: ${auth.cloudEmail}',
                    trailing: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : null,
                    onTap: _busy
                        ? null
                        : () => _runGuarded(() async {
                              final result =
                                  await SyncService.instance.syncNow();
                              ref
                                  .read(dataVersionProvider.notifier)
                                  .bump();
                              return result.describe();
                            }),
                  ),
                ],
              ),
            ),

            // --- TAMPILAN (SPEC: Dark Mode) ---
            _sectionTitle(theme, 'Tampilan'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: SwitchListTile(
                secondary: _tileIcon(
                    isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    AppColors.warning),
                title: const Text('Mode Gelap'),
                subtitle: Text(themeMode == ThemeMode.system
                    ? 'Mengikuti sistem'
                    : isDark
                        ? 'Aktif'
                        : 'Nonaktif'),
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),

            // --- DATA (SPEC: Backup & Restore) ---
            _sectionTitle(theme, 'Data'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.backup_rounded,
                    color: AppColors.primary,
                    title: 'Backup Database',
                    subtitle: 'Simpan salinan data ke file .db',
                    onTap: _busy
                        ? null
                        : () => _runGuarded(() async {
                              final path =
                                  await BackupService().backup();
                              return path == null
                                  ? 'Backup gagal dibuat.'
                                  : 'Backup berhasil dibagikan.';
                            }),
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    icon: Icons.restore_rounded,
                    color: AppColors.warning,
                    title: 'Restore Database',
                    subtitle: 'Pulihkan data dari file backup .db',
                    onTap: _busy
                        ? null
                        : () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Restore Database?',
                              message:
                                  'Data di HP ini akan DITIMPA oleh isi '
                                  'file backup. Lanjutkan?',
                              confirmText: 'Pilih File Backup',
                              danger: true,
                            );
                            if (!ok) return;
                            await _runGuarded(() async {
                              try {
                                final success =
                                    await BackupService().restore();
                                if (!success) {
                                  return 'Restore dibatalkan.';
                                }
                                ref
                                    .read(dataVersionProvider.notifier)
                                    .bump();
                                return 'Restore berhasil! Tutup lalu buka '
                                    'kembali aplikasinya.';
                              } on FormatException catch (e) {
                                return e.message;
                              } catch (_) {
                                return 'Restore gagal. Pastikan file backup '
                                    'yang benar (.db).';
                              }
                            });
                          },
                  ),
                ],
              ),
            ),

            // --- TENTANG (SPEC) ---
            _sectionTitle(theme, 'Lainnya'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.info,
                    title: 'Tentang Aplikasi',
                    subtitle:
                        '${AppConstants.appName} v${AppConstants.appVersion}',
                    onTap: _busy ? null : _showAbout,
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    icon: Icons.logout_rounded,
                    color: AppColors.danger,
                    title: 'Logout / Ganti Pengguna',
                    subtitle: 'Kembali ke layar pilih nama',
                    onTap: _busy ? null : _confirmLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 84),
              const SizedBox(height: 14),
              Text(AppConstants.appName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              Text('Versi ${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 10),
              Text(
                '${AppConstants.appTagline}. Semua catatan tersimpan '
                'offline di HP dan otomatis tersinkron ke cloud saat '
                'internet tersedia.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(title,
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700, color: theme.hintColor)),
      );

  Widget _tileIcon(IconData icon, Color color) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      );

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _tileIcon(icon, color),
      title: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.hintColor, fontSize: 11.5)),
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded,
              color: theme.hintColor, size: 20),
      onTap: onTap,
    );
  }
}
