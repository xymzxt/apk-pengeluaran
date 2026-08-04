/// Provider autentikasi owner (v1.0.0).
///
/// Sumber kebenaran = sesi Supabase Auth (`SupabaseService`), yang
/// bertahan sampai pengguna logout (SPEC: "Tetap login hingga
/// pengguna logout"). Provider ini juga memicu sinkronisasi awal
/// setelah login dan menyimpan nama profil.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import 'data_providers.dart' show dataVersionProvider;

/// Status login owner saat ini.
class AuthState {
  final bool isLoggedIn;
  final String email;
  final String name;

  const AuthState({
    this.isLoggedIn = false,
    this.email = '',
    this.name = '',
  });

  AuthState copyWith({bool? isLoggedIn, String? email, String? name}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        email: email ?? this.email,
        name: name ?? this.name,
      );
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref)..refreshFromSession();
});

/// Notifier global untuk memicu refresh data (dipakai data_providers).
final authControllerProvider = authProvider.notifier;

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  /// Sinkronkan state dengan sesi Supabase yang tersimpan (dipanggil
  /// dari splash saat aplikasi dibuka).
  void refreshFromSession() {
    final supa = SupabaseService.instance;
    if (supa.isLoggedIn) {
      final user = supa.currentUser!;
      state = AuthState(
        isLoggedIn: true,
        email: user.email ?? '',
        name: (user.userMetadata?['nama'] as String?) ??
            (user.email ?? '').split('@').first,
      );
    } else {
      state = const AuthState();
    }
  }

  /// Login email + password; sukses -> sinkron awal + catat nama.
  Future<OnlineAuthResult> login(String email, String password) async {
    final result = await SupabaseService.instance.signIn(email, password);
    if (result.ok) {
      refreshFromSession();
      // Sinkron awal agar data dari HP lain langsung turun.
      await SyncService.instance.syncNow();
      _ref.read(dataVersionProvider.notifier).bump();
    }
    return result;
  }

  /// Reset password dengan kode dari Gmail lalu ganti password baru.
  /// Sukses -> otomatis login (Supabase menyimpan sesi recovery).
  Future<OnlineAuthResult> resetPassword(
      String email, String code, String newPassword) async {
    final result = await SupabaseService.instance
        .resetPasswordWithCode(email, code, newPassword);
    if (result.ok) {
      refreshFromSession();
      await SyncService.instance.syncNow();
      _ref.read(dataVersionProvider.notifier).bump();
    }
    return result;
  }

  /// Kirim kode reset ke Gmail.
  Future<OnlineAuthResult> sendResetCode(String email) =>
      SupabaseService.instance.sendResetCode(email);

  /// Ubah password dari halaman Pengaturan.
  Future<OnlineAuthResult> changePassword(
          String oldPassword, String newPassword) =>
      SupabaseService.instance.changePassword(oldPassword, newPassword);

  /// Perbarui nama profil (metadata auth + tabel expense_users).
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(name: trimmed);
    final supa = SupabaseService.instance;
    if (supa.isLoggedIn) {
      try {
        await supa.client.auth
            .updateUser(UserAttributes(data: {'nama': trimmed}));
      } catch (_) {
        // Metadata gagal tersimpan bukan masalah fatal; tabel
        // expense_users tetap di-upsert saat sinkron berikutnya.
      }
    }
  }

  /// Logout — sesi dicabut (SPEC: sesi bertahan hingga logout).
  Future<void> logout() async {
    await SupabaseService.instance.signOut();
    state = const AuthState();
  }
}
