/// Layanan Supabase — inisialisasi, Auth owner, dan akses client.
///
/// Sama seperti aplikasi kasir, bedanya TANPA akun robot: login di
/// aplikasi ini memang ditujukan khusus OWNER (SPEC-PENGELUARAN.md:
/// "Login menggunakan Email dan Password khusus owner" + "Tetap login
/// hingga pengguna logout"). Sesi Supabase otomatis tersimpan di
/// perangkat sehingga sekali login akan terus masuk.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env_config.dart';

/// Hasil operasi online (login/daftar/reset) dengan pesan siap tampil.
class OnlineAuthResult {
  final bool ok;
  final String message;
  const OnlineAuthResult(this.ok, this.message);
}

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  bool _ready = false;

  /// `true` jika Supabase terkonfigurasi dan sudah di-init.
  bool get isReady => _ready;

  /// Client Supabase (pastikan [isReady] sebelum memakai).
  SupabaseClient get client => Supabase.instance.client;

  // -----------------------------------------------------------
  // Inisialisasi
  // -----------------------------------------------------------

  /// Inisialisasi Supabase bila `.env` terisi valid; no-op bila
  /// belum (aplikasi tetap jalan offline penuh).
  Future<void> init() async {
    if (!EnvConfig.isSupabaseConfigured) return;
    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
      );
      _ready = true;
      // Login cloud robot otomatis (v1.0.1, permintaan pemilik):
      // sinkron antar-HP berjalan di belakang layar tanpa menyuruh
      // pengguna mengisi email cloud — persis aplikasi kasir v1.5.8.
      await _autoDeviceSignIn();
    } catch (_) {
      _ready = false;
    }
  }

  /// Login cloud dengan akun "robot perangkat" (ditanam dari secrets).
  /// Di-skip bila: robot tidak ditanam, atau sesi cloud sudah ada.
  Future<void> _autoDeviceSignIn() async {
    if (!_ready || !EnvConfig.hasDeviceAccount) return;
    if (currentUser != null) return;
    try {
      await client.auth.signInWithPassword(
        email: EnvConfig.deviceEmail,
        password: EnvConfig.devicePassword,
      );
    } catch (_) {
      // Gagal login robot (offline dsb) -> sinkron dicoba lagi saat
      // syncNow dipanggil berikutnya (lewat ensureCloudSignIn).
    }
  }

  /// Dipanggil SyncService sebelum push/pull: memastikan sesi cloud
  /// robot ada; bila belum, dicoba login sekali lagi.
  Future<bool> ensureCloudSignIn() async {
    if (!_ready) return false;
    if (currentUser != null) return true;
    await _autoDeviceSignIn();
    return currentUser != null;
  }

  // -----------------------------------------------------------
  // Status login
  // -----------------------------------------------------------

  /// User yang sedang login (null bila belum / setelah logout).
  User? get currentUser => _ready ? client.auth.currentUser : null;

  bool get isLoggedIn => currentUser != null;

  /// Email user yang sedang login.
  String get currentEmail => currentUser?.email ?? '';

  // -----------------------------------------------------------
  // Login dengan Email + Password (khusus owner)
  // -----------------------------------------------------------
  Future<OnlineAuthResult> signIn(String email, String password) async {
    if (!_ready) {
      return const OnlineAuthResult(
          false, 'Supabase belum dikonfigurasi pada build ini.');
    }
    try {
      final res = await client.auth
          .signInWithPassword(email: email.trim(), password: password);
      if (res.user == null) {
        return const OnlineAuthResult(false, 'Login gagal, coba lagi.');
      }
      return const OnlineAuthResult(true, 'Login berhasil. Selamat datang!');
    } on AuthException catch (e) {
      return OnlineAuthResult(false, _mapAuthError(e));
    } catch (_) {
      return const OnlineAuthResult(
          false, 'Tidak bisa terhubung. Periksa internet lalu coba lagi.');
    }
  }

  // -----------------------------------------------------------
  // Reset password lewat kode email (SPEC: Reset Password khusus
  // owner; template email Supabase berisi {{ .Token }} — sama seperti
  // aplikasi kasir).
  // -----------------------------------------------------------

  /// Mengirim email berisi KODE reset ke Gmail owner.
  Future<OnlineAuthResult> sendResetCode(String email) async {
    if (!_ready) {
      return const OnlineAuthResult(
          false, 'Supabase belum dikonfigurasi pada build ini.');
    }
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return const OnlineAuthResult(
          true, 'Kode reset dikirim ke Gmail. Cek kotak masuk/spam ya.');
    } on AuthException catch (e) {
      return OnlineAuthResult(false, _mapAuthError(e));
    } catch (_) {
      return const OnlineAuthResult(
          false, 'Tidak bisa terhubung. Periksa internet lalu coba lagi.');
    }
  }

  /// Memverifikasi kode lalu mengganti password baru dalam satu langkah.
  Future<OnlineAuthResult> resetPasswordWithCode(
    String email,
    String code,
    String newPassword,
  ) async {
    if (!_ready) {
      return const OnlineAuthResult(
          false, 'Supabase belum dikonfigurasi pada build ini.');
    }
    try {
      await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      );
      await client.auth
          .updateUser(UserAttributes(password: newPassword));
      return const OnlineAuthResult(
          true, 'Password berhasil diganti. Kamu otomatis masuk.');
    } on AuthException catch (e) {
      return OnlineAuthResult(false, _mapAuthError(e));
    } catch (_) {
      return const OnlineAuthResult(
          false, 'Tidak bisa terhubung. Periksa internet lalu coba lagi.');
    }
  }

  // -----------------------------------------------------------
  // Ubah password (di halaman Pengaturan) — perlu password lama.
  // -----------------------------------------------------------
  Future<OnlineAuthResult> changePassword(
      String oldPassword, String newPassword) async {
    if (!_ready || currentUser == null) {
      return const OnlineAuthResult(false, 'Kamu belum login.');
    }
    try {
      // Verifikasi password lama dulu dengan mencoba login ulang.
      await client.auth.signInWithPassword(
        email: currentEmail,
        password: oldPassword,
      );
      await client.auth
          .updateUser(UserAttributes(password: newPassword));
      return const OnlineAuthResult(true, 'Password berhasil diubah.');
    } on AuthException catch (e) {
      return OnlineAuthResult(false, _mapAuthError(e));
    } catch (_) {
      return const OnlineAuthResult(
          false, 'Tidak bisa terhubung. Periksa internet lalu coba lagi.');
    }
  }

  // -----------------------------------------------------------
  // Logout (SPEC: sesi bertahan sampai pengguna logout)
  // -----------------------------------------------------------
  Future<void> signOut() async {
    if (!_ready) return;
    try {
      await client.auth.signOut();
    } catch (_) {
      // Abaikan — anggap sudah keluar.
    }
  }

  /// Terjemahan pesan error Auth menjadi bahasa Indonesia yang ramah.
  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Email atau password salah.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek Gmail untuk konfirmasi.';
    }
    if (msg.contains('rate limit')) {
      return 'Terlalu sering mencoba. Tunggu sebentar lalu ulangi.';
    }
    if (msg.contains('token') || msg.contains('otp')) {
      return 'Kode salah atau sudah kedaluwarsa.';
    }
    return e.message;
  }
}
