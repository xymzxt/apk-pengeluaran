/// Layanan penyimpanan file hasil export (v1.0.0, sama seperti kasir).
///
/// Export memakai dialog "Simpan file" bawaan Android (SAF) sehingga
/// hasilnya tersimpan di folder unduhan — seperti men-download file.
/// Bila dialog batal/gagal, otomatis kembali ke share sheet (ini juga
/// yang dipakai tombol "Share" laporan).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hasil upaya penyimpanan file.
enum SaveOutcome {
  /// Tersimpan lewat dialog sistem (folder yang dipilih pengguna).
  saved,

  /// Pengguna membatalkan dialog.
  cancelled,

  /// Dialog tidak tersedia; file dibagikan lewat share sheet.
  sharedViaSheet,
}

class FileSaver {
  FileSaver._();

  /// Simpan [bytes] sebagai [fileName].
  static Future<SaveOutcome> saveOrShare(
    String fileName,
    List<int> bytes,
  ) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan $fileName',
        fileName: fileName,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      );
      if (path == null || path.isEmpty) return SaveOutcome.cancelled;
      return SaveOutcome.saved;
    } catch (_) {
      // Perangkat tidak mendukung dialog simpan -> share sheet.
      final dir = await getTemporaryDirectory();
      final tempPath = p.join(dir.path, fileName);
      await File(tempPath).writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(tempPath)], subject: fileName);
      return SaveOutcome.sharedViaSheet;
    }
  }
}
