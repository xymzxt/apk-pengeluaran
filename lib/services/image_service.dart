/// Layanan foto nota — pilih dari kamera/galeri, simpan ke
/// penyimpanan aplikasi, dan unduh dari Supabase Storage (v1.0.0).
///
/// Offline-first: foto SELALU disimpan sebagai file lokal dulu;
/// unggah ke Storage ditangani oleh SyncService saat sinkron.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import 'supabase_service.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Pilih foto dari GALERI, simpan lokal, kembalikan path-nya.
  Future<String?> pickFromGallery(String expenseId) =>
      _pick(ImageSource.gallery, expenseId);

  /// Pilih foto dari KAMERA, simpan lokal, kembalikan path-nya.
  Future<String?> pickFromCamera(String expenseId) =>
      _pick(ImageSource.camera, expenseId);

  Future<String?> _pick(ImageSource source, String expenseId) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return null;
      final target = await _localPath(expenseId);
      await File(picked.path).copy(target);
      return target;
    } catch (_) {
      return null;
    }
  }

  /// Path lokal nota: dokumen aplikasi, folder `nota`, nama file
  /// berupa id pengeluaran + `.jpg`.
  Future<String> _localPath(String expenseId) async {
    final dir = await getApplicationDocumentsDirectory();
    final notaDir = Directory(p.join(dir.path, 'nota'));
    if (!await notaDir.exists()) await notaDir.create(recursive: true);
    return p.join(notaDir.path, '$expenseId.jpg');
  }

  /// Mengunduh foto dari Storage ke file lokal (dipakai sync PULL
  /// supaya nota dari HP lain tetap terlihat walau offline).
  Future<String?> downloadPhoto(String object, String expenseId) async {
    final supa = SupabaseService.instance;
    if (!supa.isReady) return null;
    try {
      final Uint8List bytes = await supa.client.storage
          .from(AppConstants.storageBucket)
          .download(object);
      final target = await _localPath(expenseId);
      await File(target).writeAsBytes(bytes, flush: true);
      return target;
    } catch (_) {
      return null;
    }
  }

  /// Menghapus file lokal dengan aman (foto diganti/dihapus, atau
  /// data pengeluaran dihapus permanen lewat restore/reset).
  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Abaikan.
    }
  }
}
