/// Database lokal SQLite (offline-first) — v1.0.0.
///
/// Struktur sama dengan aplikasi kasir: SEMUA fitur berjalan penuh
/// tanpa internet; Supabase hanya menjadi salinan/penyatu antar-HP
/// lewat sinkronisasi dua arah (Last Updated Wins + soft delete).
///
/// Tabel lokal:
/// - `categories` — kategori pengeluaran (nama, warna, ikon).
/// - `expenses`   — catatan pengeluaran + foto nota (path lokal/remote).
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../utils/hash.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  /// Migrasi antar versi (v1.0.1 tambah tabel app_users).
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAppUsers(db);
    }
  }

  Future<void> _create(Database db, int version) async {
    await _createAppUsers(db);
    await _createCoreTables(db);
  }

  /// Tabel pengguna LOKAL untuk login gaya kasir (v1.0.1, permintaan
  /// pemilik): owner pakai sandi khusus (hash), keluarga tanpa sandi.
  Future<void> _createAppUsers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_users (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        role          TEXT NOT NULL DEFAULT 'keluarga',
        password_hash TEXT,
        is_deleted    INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    // Seed anggota bawaan (id tetap agar tidak dobel saat migrasi).
    final now = DateTime.now().toIso8601String();
    for (final u in AppConstants.defaultUsers) {
      await db.insert(
        'app_users',
        {
          'id': u['id'],
          'name': u['name'],
          'role': u['role'],
          // Hanya owner yang punya sandi (hash dari sandi bawaan).
          'password_hash': u['role'] == 'owner'
              ? AppHash.of(AppConstants.defaultOwnerPassword)
              : null,
          'is_deleted': 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createCoreTables(Database db) async {
    // --- Kategori pengeluaran ---
    await db.execute('''
      CREATE TABLE categories (
        id         TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL DEFAULT '',
        name       TEXT NOT NULL,
        color      TEXT NOT NULL DEFAULT '#16A34A',
        icon       TEXT NOT NULL DEFAULT 'lainnya',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_synced  INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // --- Pengeluaran ---
    await db.execute('''
      CREATE TABLE expenses (
        id           TEXT PRIMARY KEY,
        user_id      TEXT NOT NULL DEFAULT '',
        category_id  TEXT,
        name         TEXT NOT NULL,
        nominal      REAL NOT NULL DEFAULT 0,
        method       TEXT NOT NULL DEFAULT 'tunai',
        date         TEXT NOT NULL,
        time         TEXT NOT NULL,
        note         TEXT NOT NULL DEFAULT '',
        photo_local  TEXT,
        photo_remote TEXT,
        is_deleted   INTEGER NOT NULL DEFAULT 0,
        is_synced    INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_expenses_date ON expenses(date, time)');
    await db.execute(
        'CREATE INDEX idx_expenses_sync ON expenses(is_synced)');
    await db.execute(
        'CREATE INDEX idx_categories_sync ON categories(is_synced)');

    // --- Kategori bawaan sesuai SPEC (id tetap agar tidak dobel
    // saat seeding di banyak perangkat; server menang/diakui lewat
    // mekanisme push upsert biasa) ---
    final now = DateTime.now().toIso8601String();
    for (final c in AppConstants.defaultCategories) {
      await db.insert('categories', {
        'id': 'seed-${c['icon']}',
        'user_id': '',
        'name': c['nama'],
        'color': c['warna'],
        'icon': c['icon'],
        'is_deleted': 0,
        'is_synced': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Menutup koneksi (dipakai sebelum restore database).
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
