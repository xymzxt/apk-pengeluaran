/// Repository data — CRUD kategori & pengeluaran di SQLite lokal
/// (Repository Pattern sesuai SPEC-PENGELUARAN.md) — v1.0.0.
///
/// Semua tulis di sini memakai SOFT DELETE dan `is_synced = 0` agar
/// SyncService tahu baris mana yang perlu didorong ke Supabase —
/// sama persis seperti pola aplikasi kasir.
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/app_user_model.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../utils/period.dart';

class ExpenseRepository {
  ExpenseRepository._();
  static final ExpenseRepository instance = ExpenseRepository._();

  static const Uuid _uuid = Uuid();

  String _now() => DateTime.now().toIso8601String();

  // ==========================================================
  // PENGGUNA LOKAL (login gaya kasir, v1.0.1)
  // ==========================================================

  /// Semua pengguna aktif (owner dulu, lalu keluarga sesuai urutan
  /// seed — rapi seperti daftar nama di aplikasi kasir).
  Future<List<AppUserModel>> getAppUsers() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('app_users',
        where: 'is_deleted = 0',
        orderBy: "CASE role WHEN 'owner' THEN 0 ELSE 1 END, created_at");
    return rows.map(AppUserModel.fromDb).toList();
  }

  /// Satu pengguna by id.
  Future<AppUserModel?> getAppUser(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('app_users',
        where: 'id = ? AND is_deleted = 0', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUserModel.fromDb(rows.first);
  }

  /// Ubah nama tampilan pengguna.
  Future<void> updateAppUserName(String id, String name) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'app_users',
      {'name': name.trim(), 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Ubah sandi owner (hanya menyimpan HASH-nya).
  Future<void> updateAppUserPassword(String id, String passwordHash) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'app_users',
      {'password_hash': passwordHash, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // KATEGORI
  // ==========================================================

  /// Semua kategori aktif (urut nama).
  Future<List<CategoryModel>> getCategories() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('categories',
        where: 'is_deleted = 0', orderBy: 'name COLLATE NOCASE');
    return rows.map(CategoryModel.fromDb).toList();
  }

  /// Tambah kategori baru.
  Future<CategoryModel> addCategory({
    required String name,
    required String colorHex,
    required String iconKey,
    String userId = '',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final cat = CategoryModel(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      colorHex: colorHex,
      iconKey: iconKey,
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('categories', cat.toMap());
    return cat;
  }

  /// Ubah kategori.
  Future<void> updateCategory(CategoryModel updated) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'categories',
      updated
          .copyWith(isSynced: false, updatedAt: DateTime.now())
          .toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
  }

  /// Hapus kategori (soft delete). Pengeluaran yang memakai kategori
  /// ini dilepas (category_id = null) agar riwayat tetap ada.
  Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = _now();
    await db.transaction((txn) async {
      await txn.update('categories',
          {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
          where: 'id = ?', whereArgs: [id]);
      await txn.update('expenses',
          {'category_id': null, 'is_synced': 0, 'updated_at': now},
          where: 'category_id = ?', whereArgs: [id]);
    });
  }

  // ==========================================================
  // PENGELUARAN
  // ==========================================================

  /// Query fleksibel untuk riwayat (pencarian real-time, filter,
  /// urutan) dengan paging ringan.
  Future<List<ExpenseModel>> queryExpenses({
    String search = '',
    String? categoryId,
    String? method,
    DateRange? range,
    bool newestFirst = true,
    int? limit,
    int offset = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final where = StringBuffer('is_deleted = 0');
    final args = <Object?>[];

    if (search.trim().isNotEmpty) {
      // Pencarian: nama, catatan, ATAU nama kategori (SPEC).
      where.write(' AND (e.name LIKE ? OR e.note LIKE ?)');
      final like = '%${search.trim()}%';
      args.addAll([like, like]);
    }
    if (categoryId != null) {
      where.write(' AND e.category_id = ?');
      args.add(categoryId);
    }
    if (method != null) {
      where.write(' AND e.method = ?');
      args.add(method);
    }
    if (range != null) {
      where.write(' AND e.date >= ? AND e.date < ?');
      args.add(_isoDate(range.start));
      args.add(_isoDate(range.end));
    }

    final order = newestFirst ? 'DESC' : 'ASC';
    final rows = await db.rawQuery('''
      SELECT e.* FROM expenses e
      WHERE ${where.toString()}
      ORDER BY e.date $order, e.time $order, e.created_at $order
      ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}
    ''', args);
    return rows.map(ExpenseModel.fromDb).toList();
  }

  /// Pencarian real-time juga mencari LEWAT kategori (SPEC: cari
  /// berdasarkan nama, kategori, catatan) — dipakai riwayat.
  Future<List<ExpenseModel>> searchExpenses(String search,
      {int? limit, int offset = 0, bool newestFirst = true}) async {
    final db = await DatabaseHelper.instance.database;
    final like = '%${search.trim()}%';
    final order = newestFirst ? 'DESC' : 'ASC';
    final rows = await db.rawQuery('''
      SELECT e.* FROM expenses e
      LEFT JOIN categories c ON c.id = e.category_id
      WHERE e.is_deleted = 0 AND (
        e.name LIKE ? OR e.note LIKE ? OR c.name LIKE ?
      )
      ORDER BY e.date $order, e.time $order
      ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}
    ''', [like, like, like]);
    return rows.map(ExpenseModel.fromDb).toList();
  }

  /// Satu pengeluaran by id.
  Future<ExpenseModel?> getExpense(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('expenses',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ExpenseModel.fromDb(rows.first);
  }

  /// Tambah pengeluaran baru.
  Future<ExpenseModel> addExpense({
    required String name,
    required double nominal,
    String? categoryId,
    required String method,
    required String date, // 'yyyy-MM-dd'
    required String time, // 'HH:mm'
    String note = '',
    String? photoLocal,
    String userId = '',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final exp = ExpenseModel(
      id: _uuid.v4(),
      userId: userId,
      categoryId: categoryId,
      name: name.trim(),
      nominal: nominal,
      method: method,
      date: date,
      time: time,
      note: note.trim(),
      photoLocal: photoLocal,
      isSynced: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('expenses', exp.toDb());
    return exp;
  }

  /// Ubah pengeluaran.
  Future<void> updateExpense(ExpenseModel updated) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'expenses',
      updated
          .copyWith(isSynced: false, updatedAt: DateTime.now())
          .toDb(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
  }

  /// Hapus pengeluaran (soft delete; foto lokal dihapus pemanggil).
  Future<void> deleteExpense(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'expenses',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // STATISTIK (dashboard & laporan)
  // ==========================================================

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Total nominal pengeluaran pada rentang [range] (aktif saja).
  Future<double> totalForRange(DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(nominal), 0) AS total, COUNT(*) AS cnt
      FROM expenses
      WHERE is_deleted = 0 AND date >= ? AND date < ?
    ''', [_isoDate(range.start), _isoDate(range.end)]);
    return ((rows.first['total'] as num?) ?? 0).toDouble();
  }

  /// Jumlah transaksi pada rentang [range].
  Future<int> countForRange(DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM expenses
      WHERE is_deleted = 0 AND date >= ? AND date < ?
    ''', [_isoDate(range.start), _isoDate(range.end)]);
    return ((rows.first['cnt'] as num?) ?? 0).toInt();
  }

  /// Total per kategori pada rentang [range] (urut terbesar).
  Future<List<Map<String, Object?>>> totalPerCategory(
      DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT e.category_id,
             COALESCE(c.name, 'Tanpa Kategori') AS cat_name,
             COALESCE(c.color, '#64748B') AS cat_color,
             COALESCE(c.icon, 'lainnya') AS cat_icon,
             SUM(e.nominal) AS total, COUNT(*) AS cnt
      FROM expenses e
      LEFT JOIN categories c ON c.id = e.category_id
      WHERE e.is_deleted = 0 AND e.date >= ? AND e.date < ?
      GROUP BY e.category_id
      ORDER BY total DESC
    ''', [_isoDate(range.start), _isoDate(range.end)]);
  }

  /// Total per metode pembayaran pada rentang [range] (urut terbesar).
  Future<List<Map<String, Object?>>> totalPerMethod(
      DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT method, SUM(nominal) AS total, COUNT(*) AS cnt
      FROM expenses
      WHERE is_deleted = 0 AND date >= ? AND date < ?
      GROUP BY method ORDER BY total DESC
    ''', [_isoDate(range.start), _isoDate(range.end)]);
  }

  /// Pengeluaran terbesar pada rentang [range].
  Future<ExpenseModel?> biggestInRange(DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT * FROM expenses
      WHERE is_deleted = 0 AND date >= ? AND date < ?
      ORDER BY nominal DESC LIMIT 1
    ''', [_isoDate(range.start), _isoDate(range.end)]);
    if (rows.isEmpty) return null;
    return ExpenseModel.fromDb(rows.first);
  }

  /// [count] pengeluaran terakhir (terbaru duluan).
  Future<List<ExpenseModel>> latest(int count) async {
    return queryExpenses(limit: count, newestFirst: true);
  }

  /// Total per bulan untuk satu tahun (12 titik) — grafik dashboard.
  Future<List<double>> monthlyTotals(int year) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT substr(date, 6, 2) AS mm, SUM(nominal) AS total
      FROM expenses
      WHERE is_deleted = 0 AND substr(date, 1, 4) = ?
      GROUP BY mm
    ''', [year.toString().padLeft(4, '0')]);
    final result = List<double>.filled(12, 0);
    for (final row in rows) {
      final month = int.tryParse(row['mm'] as String? ?? '') ?? 0;
      if (month >= 1 && month <= 12) {
        result[month - 1] = ((row['total'] as num?) ?? 0).toDouble();
      }
    }
    return result;
  }

  /// Total per hari dalam rentang [range] — grafik batang laporan.
  /// Mengembalikan map 'yyyy-MM-dd' -> total.
  Future<Map<String, double>> dailyTotals(DateRange range) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT date, SUM(nominal) AS total FROM expenses
      WHERE is_deleted = 0 AND date >= ? AND date < ?
      GROUP BY date ORDER BY date
    ''', [_isoDate(range.start), _isoDate(range.end)]);
    return {
      for (final row in rows)
        row['date'] as String: ((row['total'] as num?) ?? 0).toDouble(),
    };
  }

  // ------------------------------------------------------------------
  // PEMASUKAN harian dari aplikasi kasir — Laporan Akhir
  // (v1.1.0, permintaan pemilik)
  // ------------------------------------------------------------------

  /// Simpan/refresh cache pemasukan harian (hasil fungsi Supabase
  /// get_daily_income pada tabel penjualan aplikasi kasir).
  Future<void> upsertIncomeDays(List<Map<String, Object?>> rows) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final row in rows) {
      final day = row['day']?.toString() ?? '';
      if (day.isEmpty) continue;
      batch.insert(
        'income_daily',
        {
          'day': day,
          'total': ((row['total'] as num?) ?? 0).toDouble(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Peta 'yyyy-MM-dd' -> total pemasukan untuk rentang INKLUSIF
  /// [fromIso]..[toIso] (ikut batas hari terakhir).
  Future<Map<String, double>> incomeDailyMap(
      String fromIso, String toIso) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT day, total FROM income_daily
      WHERE day >= ? AND day <= ? ORDER BY day
    ''', [fromIso, toIso]);
    return {
      for (final row in rows)
        row['day'] as String: ((row['total'] as num?) ?? 0).toDouble(),
    };
  }
}
