/// Layar Login khusus OWNER (SPEC-PENGELUARAN.md):
/// Email + Password, tombol SHOW PASSWORD (ikon mata), tautan
/// "Lupa password" -> kirim kode ke Gmail -> ganti password baru.
/// Tetap login sampai pengguna logout. — v1.0.0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../utils/page_transitions.dart';
import '../../utils/validators.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/confirm_dialog.dart';
import '../main_navigation.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(context, result.message, isError: !result.ok);
    if (result.ok) {
      Navigator.of(context)
          .pushReplacement(fadeRoute(const MainNavigation()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
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
                    'Login khusus pemilik toko',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Gmail',
                              hintText: 'nama@gmail.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: Validators.email,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              // Tombol SHOW PASSWORD (SPEC).
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                tooltip: _obscure
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: Validators.password,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _showForgotDialog,
                              child: const Text('Lupa password?'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            onPressed: _busy ? null : _login,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.login_rounded),
                            label: Text(_busy ? 'Memeriksa...' : 'Masuk'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
      ),
    );
  }

  // -----------------------------------------------------------
  // LUPA PASSWORD — dialog 2 langkah:
  // 1) isi email -> kirim kode ke Gmail
  // 2) isi kode + password baru -> selesai, otomatis login
  // -----------------------------------------------------------
  Future<void> _showForgotDialog() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    final codeController = TextEditingController();
    final passController = TextEditingController();
    bool codeSent = false;
    bool busy = false;
    bool obscureNew = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendCode() async {
              final email = emailController.text.trim();
              if (Validators.email(email) != null) {
                showAppSnackBar(context, 'Isi email Gmail yang benar dulu ya.',
                    isError: true);
                return;
              }
              setDialogState(() => busy = true);
              final result =
                  await ref.read(authProvider.notifier).sendResetCode(email);
              if (!context.mounted) return;
              setDialogState(() {
                busy = false;
                codeSent = result.ok;
              });
              showAppSnackBar(context, result.message, isError: !result.ok);
            }

            Future<void> confirm() async {
              final email = emailController.text.trim();
              final code = codeController.text.trim();
              final pass = passController.text;
              if (code.length < 6) {
                showAppSnackBar(context, 'Isi kode 6–8 digit dari Gmail.',
                    isError: true);
                return;
              }
              if (pass.length < 6) {
                showAppSnackBar(context, 'Password baru minimal 6 karakter.',
                    isError: true);
                return;
              }
              setDialogState(() => busy = true);
              final result = await ref
                  .read(authProvider.notifier)
                  .resetPassword(email, code, pass);
              if (!context.mounted) return;
              setDialogState(() => busy = false);
              showAppSnackBar(context, result.message, isError: !result.ok);
              if (result.ok) {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  Navigator.of(this.context)
                      .pushReplacement(fadeRoute(const MainNavigation()));
                }
              }
            }

            return AlertDialog(
              title: const Text('Reset Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Kode reset akan dikirim ke Gmail owner. '
                      'Isi email, kirim kode, lalu masukkan kode & '
                      'password baru.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Gmail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Kode dari Gmail (6–8 digit)',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: passController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Password baru',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setDialogState(
                                () => obscureNew = !obscureNew),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                if (!codeSent)
                  FilledButton(
                    onPressed: busy ? null : sendCode,
                    child: Text(busy ? 'Mengirim...' : 'Kirim Kode'),
                  )
                else
                  FilledButton(
                    onPressed: busy ? null : confirm,
                    child: Text(busy ? 'Memproses...' : 'Ganti Password'),
                  ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    codeController.dispose();
    passController.dispose();
  }
}
