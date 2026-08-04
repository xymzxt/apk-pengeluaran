/// Layanan Backup & Restore database (SPEC: Pengaturan berisi
/// Backup Database & Restore Database) — v1.0.0, cara kerja sama
/// persis dengan aplikasi kasir.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';

class BackupService {
  /// Menyalin database aktif ke file cadangan dan membagikannya.
  /// Mengembalikan path file cadangan, atau `null` jika gagal.
  Future<String?> backup() async {
    try {
      final dbPath = p.join(await getDatabasesPath(), AppConstants.dbName);
      final source = File(dbPath);
      if (!await source.exists()) return null;

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final backupPath =
          p.join(dir.path, 'backup-pengeluaran-$stamp.db');
      await source.copy(backupPath);

      await Share.shareXFiles(
        [XFile(backupPath)],
        subject: 'Backup Database Pengeluaran',
      );
      return backupPath;
    } catch (_) {
      return null;
    }
  }

  /// Mengembalikan database dari file cadangan.
  /// Mengembalikan `true` jika berhasil (aplikasi perlu direstart).
  Future<bool> restore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Pilih file backup (.db)',
      );
      final filePath = result?.files.single.path;
      if (filePath == null) return false;

      // Validasi: 16 byte pertama file SQLite berisi "SQLite format 3".
      final source = File(filePath);
      final header = await source.openRead(0, 16).expand((c) => c).toList();
      final magic = String.fromCharCodes(header.take(15));
      if (magic != 'SQLite format 3') {
        throw const FormatException('File bukan database SQLite yang valid');
      }

      // Tutup koneksi, timpa file, buka ulang.
      await DatabaseHelper.instance.close();
      final dbPath = p.join(await getDatabasesPath(), AppConstants.dbName);
      await source.copy(dbPath);
      await DatabaseHelper.instance.database;
      return true;
    } catch (_) {
      // Pastikan koneksi tersedia kembali walau restore gagal.
      try {
        await DatabaseHelper.instance.database;
      } catch (_) {}
      rethrow;
    }
  }
}
