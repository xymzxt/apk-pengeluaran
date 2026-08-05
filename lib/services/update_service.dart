/// Layanan pembaruan aplikasi dari dalam aplikasi (v1.2.0,
/// permintaan pemilik — disamakan dengan aplikasi kasir):
/// mengecek GitHub Releases untuk versi terbaru, mengunduh APK-nya,
/// lalu menyerahkan pemasangan ke sistem Android.
///
/// Sumber kebenaran versi: Release bertanda "Latest" di repo
/// `xymzxt/apk-pengeluaran`, diterbitkan otomatis oleh GitHub Actions
/// setiap kali build berhasil — sehingga pemilik TIDAK PERLU lagi
/// mengunduh APK manual dari tab Actions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';

/// Informasi versi terbaru yang tersedia di GitHub Releases.
class UpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    this.notes = '',
  });
}

class UpdateService {
  /// Repo GitHub tempat Actions menerbitkan Release APK (publik).
  static const String repo = 'xymzxt/apk-pengeluaran';

  /// Batas waktu pengecekan agar splash tidak menunggu lama.
  static const Duration _timeout = Duration(seconds: 6);

  /// Membandingkan versi format "x.y.z".
  /// Mengembalikan `true` jika [remote] lebih baru dari [local].
  static bool isNewerVersion(String remote, String local) {
    List<int> parts(String v) =>
        v.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final r = parts(remote);
    final l = parts(local);
    final maxLength = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < maxLength; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Mengecek apakah ada versi lebih baru di GitHub Releases.
  ///
  /// Mengembalikan `null` bila: offline, error, timeout, atau aplikasi
  /// sudah versi terbaru — sehingga aplikasi TIDAK PERNAH terkunci
  /// hanya karena tidak ada internet (offline-first tetap dijaga).
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) return null;

      final client = HttpClient()..connectionTimeout = _timeout;
      try {
        final request = await client.getUrl(Uri.parse(
            'https://api.github.com/repos/$repo/releases/latest'));
        request.headers
            .set(HttpHeaders.userAgentHeader, 'Pengeluaran-Updater');
        final response = await request.close().timeout(_timeout);
        if (response.statusCode != 200) return null;

        final body =
            await utf8.decoder.bind(response).join().timeout(_timeout);
        final data = jsonDecode(body);
        if (data is! Map<String, dynamic>) return null;

        final tag =
            (data['tag_name'] ?? '').toString().replaceFirst('v', '');
        String? apkUrl;
        final assets = data['assets'];
        if (assets is List) {
          for (final asset in assets) {
            final map = asset as Map;
            final name = map['name']?.toString() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = map['browser_download_url']?.toString();
              break;
            }
          }
        }
        if (apkUrl == null || tag.isEmpty) return null;
        if (!isNewerVersion(tag, AppConstants.appVersion)) return null;

        return UpdateInfo(
          version: tag,
          apkUrl: apkUrl,
          notes: (data['body'] ?? '').toString(),
        );
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      // Gagal cek update tidak pernah menggagalkan aplikasi.
      debugPrint('Cek update dilewati: $e');
      return null;
    }
  }

  /// Membersihkan sisa file APK update lama di cache HP (dipanggil di
  /// splash; sama seperti aplikasi kasir — "mentahan" unduhan tidak
  // boleh memenuhi memori).
  Future<void> clearDownloadedApk() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pengeluaran-update.apk');
      if (await file.exists()) {
        await file.delete();
        debugPrint('Sisa APK update di cache dibersihkan.');
      }
    } catch (_) {
      // Bonus — kegagalan tidak pernah mengganggu.
    }
  }

  /// Mengunduh APK pembaruan ke folder sementara.
  ///
  /// Mengembalikan path file APK, atau `null` jika gagal.
  /// [onProgress] dipanggil dengan nilai 0.0–1.0 bila ukuran diketahui.
  Future<String?> downloadApk(String url,
      {void Function(double progress)? onProgress}) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pengeluaran-update.apk');
      if (await file.exists()) await file.delete();

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers
            .set(HttpHeaders.userAgentHeader, 'Pengeluaran-Updater');
        final response = await request.close();
        if (response.statusCode != 200) return null;

        final total = response.contentLength; // -1 bila tidak diketahui
        final sink = file.openWrite();
        var received = 0;
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress
                ?.call((received / total).clamp(0.0, 1.0).toDouble());
          }
        }
        await sink.flush();
        await sink.close();

        if (await file.length() == 0) return null;
        onProgress?.call(1);
        return file.path;
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('Gagal mengunduh APK update: $e');
      return null;
    }
  }
}
