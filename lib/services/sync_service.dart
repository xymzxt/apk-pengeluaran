/// Layanan sinkronisasi dua arah (offline-first) — v1.0.0.
///
/// Strategi sama persis dengan aplikasi kasir:
/// - **Push**: semua baris lokal `is_synced = 0` di-upsert ke Supabase
///   (kategori dulu, lalu pengeluaran yang menunjuk ke kategori tsb).
/// - **Pull**: semua baris server `updated_at >` capaian terakhir
///   ditarik dan diterapkan bila lebih baru (Last Updated Wins);
///   soft delete ikut tersalin.
/// - **Foto nota**: ikut didorong ke Storage SEWAKTU push; file lokal
///   tetap jadi sumber tampilan utama (offline aman). Foto yang datang
///   dari HP lain akan diunduh ke file lokal saat sinkron.
/// - Profil owner (tabel `expense_users`) turut di-upsert saat push.
///
/// Hasil sinkron dilaporkan "X terkirim, Y ditarik" persis seperti
/// gaya notifikasi sinkron di aplikasi kasir.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/expense_repository.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import 'image_service.dart';
import 'supabase_service.dart';

/// Ringkasan hasil sinkronisasi untuk notifikasi.
class SyncSummary {
  final int pushed;
  final int pulled;
  final String? skippedReason;

  const SyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.skippedReason,
  });

  bool get skipped => skippedReason != null;

  String describe() {
    if (skippedReason != null) return skippedReason!;
    return 'Sinkronisasi selesai: $pushed terkirim, $pulled ditarik';
  }
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _running = false;

  /// Sinkron penuh: push lalu pull. Aman dipanggil berulang.
  Future<SyncSummary> syncNow() async {
    final supa = SupabaseService.instance;
    if (!supa.isReady) {
      return const SyncSummary(
          skippedReason: 'Supabase belum dikonfigurasi');
    }
    // Pastikan sesi cloud (robot) ada; bila gagal, berarti offline.
    if (!await supa.ensureCloudSignIn()) {
      return const SyncSummary(
          skippedReason: 'Belum terhubung ke cloud — periksa internet');
    }
    if (_running) {
      return const SyncSummary(skippedReason: 'Sinkronisasi sedang berjalan');
    }
    _running = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final uid = supa.currentUser!.id;

      var pushed = 0;
      pushed += await _pushProfiles(db, uid);
      pushed += await _pushCategories(db, uid);
      pushed += await _pushExpenses(db, uid);

      // Capaian waktu pull dibaca SEKALI untuk semua tabel — kalau
      // dibaca per-tabel, capaian yang baru ditulis tabel pertama
      // langsung "menelan" data tabel berikutnya (bug fix v1.0.0).
      final last = await _lastPull(AppConstants.prefLastPull);
      var pulled = 0;
      pulled += await _pullCategories(db, uid, last);
      pulled += await _pullExpenses(db, uid, last);
      // v1.3.0 (permintaan pemilik): cerminkan juga daftar nama
      // anggota dari aplikasi kasir (tabel store_members) — tambah,
      // ubah, atau hapus nama cukup dilakukan di aplikasi kasir.
      pulled += await _pullMembers(db);
      await _setLastPull(AppConstants.prefLastPull, DateTime.now());

      return SyncSummary(pushed: pushed, pulled: pulled);
    } catch (_) {
      return const SyncSummary(
          skippedReason: 'Sinkronisasi gagal — coba lagi nanti');
    } finally {
      _running = false;
    }
  }

  // -----------------------------------------------------------
  // PUSH
  // -----------------------------------------------------------

  Future<int> _pushProfiles(Database db, String uid) async {
    final supa = SupabaseService.instance;
    try {
      await supa.client.from(AppConstants.tableUsers).upsert({
        'id': uid,
        'nama': supa.currentUser?.userMetadata?['nama'] ??
            supa.currentEmail.split('@').first,
        'email': supa.currentEmail,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return 1;
    } catch (_) {
      return 0;
    }
  }

  /// Tarik daftar anggota dari tabel `store_members` milik aplikasi
  /// kasir lalu CERMIN ke `app_users` lokal (v1.3.0, permintaan
  /// pemilik: "kenapa tidak sinkron?" — kini daftar nama mengikuti
  /// Manajemen Pengguna di aplikasi kasir).
  ///
  /// Satu arah saja (pull): sandi owner LOKAL aplikasi ini tidak
  /// pernah ditimpa, dan menambah/menghapus anggota tetap dilakukan
  /// dari aplikasi kasir seperti biasa.
  Future<int> _pullMembers(Database db) async {
    final supa = SupabaseService.instance;
    try {
      final List<dynamic> rows = await supa.client
          .from('store_members')
          .select('id, name, role, is_active, deleted_at');
      if (rows.isEmpty) return 0;

      var count = 0;
      final cloudIds = <String>{};
      final repo = ExpenseRepository.instance;
      for (final raw in rows) {
        final row = Map<String, Object?>.from(raw as Map);
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        cloudIds.add(id);
        final rawRole = row['role']?.toString() ?? '';
        final role =
            (rawRole == 'owner' || rawRole == 'admin') ? 'owner' : 'keluarga';
        final deleted =
            row['deleted_at'] != null || row['is_active'] == false;
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        await repo.upsertMemberFromCloud(
            id: id, name: name, role: role, deleted: deleted);
        count++;
      }
      // Cermin penuh: nama yang dihapus di aplikasi kasir ikut
      // hilang di sini — KECUALI owner lokal (pintu utama aplikasi
      // ini tidak pernah dikunci sepihak).
      count += await repo.deleteMembersMissingFrom(cloudIds);
      return count;
    } catch (e) {
      debugPrint('Tarik anggota (store_members) gagal: $e');
      return 0;
    }
  }

  /// Segarkan HANYA daftar nama (dipakai layar login, v1.3.0) agar
  /// nama baru dari aplikasi kasir langsung muncul tanpa harus
  /// masuk aplikasi lebih dulu.
  Future<void> pullMembersNow() async {
    final supa = SupabaseService.instance;
    if (!supa.isReady) return;
    if (!await supa.ensureCloudSignIn()) return;
    final db = await DatabaseHelper.instance.database;
    await _pullMembers(db);
  }

  Future<int> _pushCategories(Database db, String uid) async {
    final rows = await db
        .query('categories', where: 'is_synced = 0');
    if (rows.isEmpty) return 0;
    var sent = 0;
    for (final row in rows) {
      final cat = CategoryModel.fromDb(row).copyWith(userId: uid);
      try {
        await SupabaseService.instance.client
            .from(AppConstants.tableCategories)
            .upsert(cat.toServer());
        await db.update('categories',
            {'is_synced': 1, 'user_id': uid},
            where: 'id = ?', whereArgs: [cat.id]);
        sent++;
      } catch (_) {
        // baris gagal -> coba lagi sinkron berikutnya
      }
    }
    return sent;
  }

  Future<int> _pushExpenses(Database db, String uid) async {
    final rows =
        await db.query('expenses', where: 'is_synced = 0');
    if (rows.isEmpty) return 0;
    var sent = 0;
    for (final row in rows) {
      var exp = ExpenseModel.fromDb(row).copyWith(userId: uid);
      try {
        // Foto nota menyertai push (bila ada file lokal baru/berubah).
        exp = await _pushPhoto(exp);
        await SupabaseService.instance.client
            .from(AppConstants.tableExpenses)
            .upsert(exp.toServer());
        await db.update('expenses',
            {'is_synced': 1, 'user_id': uid, 'photo_remote': exp.photoRemote},
            where: 'id = ?', whereArgs: [exp.id]);
        sent++;
      } catch (_) {
        // baris gagal -> coba lagi sinkron berikutnya
      }
    }
    return sent;
  }

  /// Mengunggah foto nota ke Storage bila ada perubahan lokal.
  Future<ExpenseModel> _pushPhoto(ExpenseModel exp) async {
    // Tidak ada foto lokal & tidak ada remote -> tidak ada kerjaan.
    if (exp.photoLocal == null) {
      // Foto dihapus lokal namun remote masih ada -> hapus di server.
      if (exp.photoRemote != null) {
        await _removeRemotePhoto(exp.photoRemote!);
        return exp.copyWith(clearPhotoRemote: true);
      }
      return exp;
    }
    try {
      final file = File(exp.photoLocal!);
      if (!await file.exists()) return exp;
      final bytes = await file.readAsBytes();
      await SupabaseService.instance.client.storage
          .from(AppConstants.storageBucket)
          .uploadBinary(
            exp.storageObject,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return exp.copyWith(photoRemote: exp.storageObject);
    } catch (_) {
      // Gagal unggah -> tetap sync datanya, foto dicoba lagi nanti
      // (photoRemote dibiarkan sesuai kondisi terakhir).
      return exp;
    }
  }

  Future<void> _removeRemotePhoto(String object) async {
    try {
      await SupabaseService.instance.client.storage
          .from(AppConstants.storageBucket)
          .remove([object]);
    } catch (_) {
      // Abaikan — penghapusan foto bukan urusan fatal.
    }
  }

  // -----------------------------------------------------------
  // PULL
  // -----------------------------------------------------------

  Future<String?> _lastPull(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _setLastPull(String key, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value.toIso8601String());
  }

  Future<int> _pullCategories(Database db, String uid, String? last) async {
    final client = SupabaseService.instance.client;
    try {
      var query = client
          .from(AppConstants.tableCategories)
          .select()
          .eq('user_id', uid);
      if (last != null) query = query.gt('updated_at', last);
      final rows = await query;
      var applied = 0;
      for (final raw in rows) {
        final remote = CategoryModel.fromServer(raw);
        applied += await _applyCategoryLUW(db, remote);
      }
      return applied;
    } catch (_) {
      return 0;
    }
  }

  /// Terapkan kategori remote bila LEBIH BARU dari lokal (LUW);
  /// bila lokal lebih baru, biarkan — nanti push yang menyamakan.
  Future<int> _applyCategoryLUW(
      Database db, CategoryModel remote) async {
    final existing = await db.query('categories',
        where: 'id = ?', whereArgs: [remote.id], limit: 1);
    if (existing.isNotEmpty) {
      final local = CategoryModel.fromDb(existing.first);
      if (!remote.updatedAt.isAfter(local.updatedAt)) return 0;
    }
    await db.insert(
        'categories',
        remote
            .copyWith(isSynced: true)
            .toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 1;
  }

  Future<int> _pullExpenses(Database db, String uid, String? last) async {
    final client = SupabaseService.instance.client;
    try {
      var query = client
          .from(AppConstants.tableExpenses)
          .select()
          .eq('user_id', uid);
      if (last != null) query = query.gt('updated_at', last);
      final rows = await query;
      var applied = 0;
      for (final raw in rows) {
        final remote = ExpenseModel.fromServer(raw);
        applied += await _applyExpenseLUW(db, remote);
      }
      return applied;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _applyExpenseLUW(Database db, ExpenseModel remote) async {
    final existing = await db.query('expenses',
        where: 'id = ?', whereArgs: [remote.id], limit: 1);
    ExpenseModel merged = remote;
    if (existing.isNotEmpty) {
      final local = ExpenseModel.fromDb(existing.first);
      if (!remote.updatedAt.isAfter(local.updatedAt)) return 0;
      // Pertahankan foto lokal yang dimiliki perangkat ini bila
      // remote tidak membawa foto (menghindari hilang saat beda HP).
      merged = remote.copyWith(
        photoLocal:
            remote.photoRemote == null ? local.photoLocal : local.photoLocal,
      );
    }
    // Unduh foto remote ke file lokal bila belum ada (agar ikut
    // tampil di HP ini walau offline).
    if (merged.photoRemote != null &&
        (merged.photoLocal == null ||
            !await File(merged.photoLocal!).exists())) {
      final localPath =
          await ImageService().downloadPhoto(merged.photoRemote!, merged.id);
      if (localPath != null) {
        merged = merged.copyWith(photoLocal: localPath);
      }
    }
    await db.insert(
        'expenses',
        merged
            .copyWith(isSynced: true)
            .toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 1;
  }
}
