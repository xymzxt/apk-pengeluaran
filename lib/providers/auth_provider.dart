/// Provider autentikasi (v1.0.1 — login GAYA KASIR, permintaan pemilik).
///
/// Ada DUA lapis "login" yang berbeda (sama persis seperti aplikasi kasir):
///
/// 1. **Login aplikasi (yang terlihat pengguna)** — pilih NAMA dari
///    daftar anggota lokal: owner (Nanda) wajib sandi khusus, keluarga
///    tinggal tap nama. Sesi tersimpan di SharedPreferences: tetap
///    masuk sampai pengguna Logout.
///
/// 2. **Login cloud (tak terlihat)** — akun robot perangkat Supabase
///    Auth yang login OTOMATIS dari kredensial yang ditanam saat
///    build, murni untuk kebutuhan sinkronisasi antar-HP. Pengguna
///    tidak perlu tahu/isi apa pun.
///
/// Jadi: aplikasi tetap "offline-first + sinkron dua arah", tapi
/// pintu masuknya ramah keluarga seperti aplikasi kasir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/config/env_config.dart';
import '../database/expense_repository.dart';
import '../models/app_user_model.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../utils/hash.dart';
import 'data_providers.dart' show dataVersionProvider;

/// Status login aplikasi saat ini.
class AuthState {
  final bool isLoggedIn;

  /// Nama anggota yang sedang masuk ('' bila belum).
  final String name;

  /// 'owner' atau 'keluarga'.
  final String role;

  /// Id pengguna lokal (dipakai untuk ganti password owner).
  final String userId;

  /// Email akun cloud (robot) — info saja untuk tampilan.
  final String cloudEmail;

  const AuthState({
    this.isLoggedIn = false,
    this.name = '',
    this.role = '',
    this.userId = '',
    this.cloudEmail = '',
  });

  bool get isOwner => role == 'owner';

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
    String? role,
    String? userId,
    String? cloudEmail,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        name: name ?? this.name,
        role: role ?? this.role,
        userId: userId ?? this.userId,
        cloudEmail: cloudEmail ?? this.cloudEmail,
      );
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref)..refreshFromSession();
});

/// Hasil percobaan login/aksi auth dengan pesan siap tampil.
class AuthResult {
  final bool ok;
  final String message;
  const AuthResult(this.ok, this.message);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  // -----------------------------------------------------------
  // SESI LOKAL (nama yang masuk)
  // -----------------------------------------------------------

  /// Sinkronkan state dengan sesi tersimpan (dipanggil dari splash).
  Future<void> refreshFromSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.prefSessionUser);
      if (userId != null && userId.isNotEmpty) {
        final user = await ExpenseRepository.instance.getAppUser(userId);
        if (user != null) {
          _applyLogin(user);
          return;
        }
      }
    } catch (_) {
      // Preferensi rusak -> anggap belum login.
    }
    state = AuthState(cloudEmail: _cloudEmail());
  }

  void _applyLogin(AppUserModel user) {
    state = AuthState(
      isLoggedIn: true,
      name: user.name,
      role: user.role,
      userId: user.id,
      cloudEmail: _cloudEmail(),
    );
  }

  String _cloudEmail() => SupabaseService.instance.currentEmail;

  // -----------------------------------------------------------
  // LOGIN GAYA KASIR
  // -----------------------------------------------------------

  /// Tap nama KELUARGA -> langsung masuk (tanpa sandi).
  Future<AuthResult> loginAsFamily(AppUserModel user) async {
    if (user.isOwner) {
      return const AuthResult(false, 'Owner wajib pakai sandi.');
    }
    await _persistSession(user);
    _applyLogin(user);
    // Sinkron awal di latar belakang (robot sudah login cloud).
    // ignore: discarded_futures
    _backgroundSync();
    return AuthResult(true, 'Halo, ${user.name}!');
  }

  /// Login OWNER -> wajib sandi khusus yang benar.
  Future<AuthResult> loginAsOwner(AppUserModel user, String password) async {
    final stored = user.passwordHash ?? '';
    if (stored.isEmpty || !AppHash.verify(password, stored)) {
      return const AuthResult(false, 'Sandi salah. Coba lagi ya.');
    }
    await _persistSession(user);
    _applyLogin(user);
    // ignore: discarded_futures
    _backgroundSync();
    return AuthResult(true, 'Selamat datang, ${user.name}!');
  }

  Future<void> _persistSession(AppUserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefSessionUser, user.id);
    } catch (_) {
      // Gagal menyimpan sesi bukan masalah fatal; hanya berarti harus
      // login ulang saat aplikasi dibuka lagi.
    }
  }

  /// Sinkron pasif di latar belakang setelah masuk.
  Future<void> _backgroundSync() async {
    await SyncService.instance.syncNow();
    _ref.read(dataVersionProvider.notifier).bump();
  }

  // -----------------------------------------------------------
  // LOGIN CLOUD ROBOT (dipanggil otomatis dari SupabaseService)
  // -----------------------------------------------------------

  /// Status cloud untuk tampilan: apakah robot sudah terhubung.
  bool get cloudLoggedIn => SupabaseService.instance.isLoggedIn;

  // -----------------------------------------------------------
  // PROFIL & SANDI OWNER
  // -----------------------------------------------------------

  /// Ubah nama tampilan anggota yang sedang masuk.
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !state.isLoggedIn) return;
    await ExpenseRepository.instance
        .updateAppUserName(state.userId, trimmed);
    state = state.copyWith(name: trimmed);
  }

  /// Ganti sandi owner (verifikasi sandi lama dulu).
  Future<AuthResult> changeOwnerPassword(
      String oldPassword, String newPassword) async {
    if (!state.isOwner) {
      return const AuthResult(false, 'Hanya owner yang bisa ganti sandi.');
    }
    final user = await ExpenseRepository.instance.getAppUser(state.userId);
    if (user == null) {
      return const AuthResult(false, 'Pengguna tidak ditemukan.');
    }
    final stored = user.passwordHash ?? '';
    if (stored.isEmpty || !AppHash.verify(oldPassword, stored)) {
      return const AuthResult(false, 'Sandi lama salah.');
    }
    if (newPassword.length < 4) {
      return const AuthResult(false, 'Sandi baru minimal 4 karakter.');
    }
    await ExpenseRepository.instance
        .updateAppUserPassword(state.userId, AppHash.of(newPassword));
    return const AuthResult(true, 'Sandi owner berhasil diganti.');
  }

  // -----------------------------------------------------------
  // LOGOUT — sesi lokal dicabut SPEC: "Tetap login hingga logout".
  // Cloud robot DIBIARKAN masuk (agar HP tetap bisa sinkron saat
  // anggota lain login), sama seperti aplikasi kasir.
  // -----------------------------------------------------------
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefSessionUser);
    } catch (_) {
      // Abaikan.
    }
    state = AuthState(cloudEmail: _cloudEmail());
  }

  /// Info apakah akun robot ditanam di build ini (untuk label UI).
  bool get hasRobotAccount => EnvConfig.hasDeviceAccount;
}
