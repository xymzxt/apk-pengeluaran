/// Layar Login gaya aplikasi kasir (v1.0.1 — permintaan pemilik).
///
/// Bukan email+password lagi. Yang tampil DAFTAR NAMA anggota:
/// - Keluarga (Kasir, Donny, Sonny, Yono): tap nama -> langsung masuk.
/// - Owner (Nanda): tap nama -> dialog sandi khusus (ada mata show
///   password). Sinkron cloud berjalan otomatis lewat akun robot
///   perangkat — pengguna tidak perlu tahu apa-apa soal itu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../database/expense_repository.dart';
import '../../models/app_user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/confirm_dialog.dart';
import '../main_navigation.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  List<AppUserModel>? _users;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await ExpenseRepository.instance.getAppUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  Future<void> _enter(AppUserModel user, {String? password}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    final result = user.isOwner
        ? await auth.loginAsOwner(user, password ?? '')
        : await auth.loginAsFamily(user);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      Navigator.of(context)
          .pushReplacement(fadeRoute(const MainNavigation()));
    } else {
      showAppSnackBar(context, result.message, isError: true);
    }
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 96),
                const SizedBox(height: 16),
                Text(
                  'Pengeluaran',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Pilih nama untuk masuk',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 24),

                // --- Daftar nama anggota ---
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(
                                child: CircularProgressIndicator()),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < _users!.length; i++) ...[
                                if (i > 0)
                                  const Divider(height: 1, indent: 64),
                                _userTile(_users![i], theme),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keluarga tap nama saja, owner pakai sandi.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.appName} v${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _userTile(AppUserModel user, ThemeData theme) {
    final isOwner = user.isOwner;
    return ListTile(
      enabled: !_busy,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (isOwner ? AppColors.primary : AppColors.info)
              .withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isOwner ? Icons.workspace_premium_rounded : Icons.person_rounded,
          color: isOwner ? AppColors.primary : AppColors.info,
        ),
      ),
      title: Text(
        user.name,
        style: theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isOwner ? 'Owner • pakai sandi' : 'Keluarga • tap untuk masuk',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.hintColor, fontSize: 11.5),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              isOwner ? Icons.lock_outline_rounded : Icons.login_rounded,
              size: 20,
              color: theme.hintColor,
            ),
      onTap: () {
        if (isOwner) {
          _askOwnerPassword(user);
        } else {
          _enter(user);
        }
      },
    );
  }

  // -----------------------------------------------------------
  // Dialog SANDI OWNER (dengan mata show/hide ala aplikasi kasir)
  // -----------------------------------------------------------
  Future<void> _askOwnerPassword(AppUserModel user) async {
    final controller = TextEditingController();
    bool obscure = true;
    bool checking = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (checking) return;
              setDialogState(() => checking = true);
              final auth = ref.read(authProvider.notifier);
              final result =
                  await auth.loginAsOwner(user, controller.text);
              if (!context.mounted) return;
              setDialogState(() => checking = false);
              if (result.ok) {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  Navigator.of(this.context)
                      .pushReplacement(fadeRoute(const MainNavigation()));
                }
              } else {
                showAppSnackBar(context, result.message, isError: true);
              }
            }

            return AlertDialog(
              title: Text('Sandi ${user.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Masukkan sandi khusus owner.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Sandi Owner',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      // Tombol SHOW PASSWORD (SPEC).
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        tooltip: obscure
                            ? 'Tampilkan sandi'
                            : 'Sembunyikan sandi',
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: checking ? null : submit,
                  child: Text(checking ? 'Memeriksa...' : 'Masuk'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }
}
