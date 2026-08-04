/// Model Kategori Pengeluaran (v1.0.0).
///
/// Disimpan offline-first di SQLite DAN disinkronkan ke tabel
/// `expense_categories` di Supabase. Kolom snake_case mengikuti
/// nama kolom di server supaya dua arahnya konsisten.
library;

class CategoryModel {
  final String id;

  /// Pemilik data (uid Supabase Auth) — kosong di mode offline penuh.
  final String userId;
  final String name;

  /// Warna hex '#RRGGBB' dan kunci ikon string (lihat IconMap).
  final String colorHex;
  final String iconKey;

  /// Soft delete & penanda sinkronisasi (sama seperti aplikasi kasir).
  final bool isDeleted;
  final bool isSynced;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    this.userId = '',
    required this.name,
    required this.colorHex,
    required this.iconKey,
    this.isDeleted = false,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryModel copyWith({
    String? name,
    String? colorHex,
    String? iconKey,
    bool? isDeleted,
    bool? isSynced,
    String? userId,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconKey: iconKey ?? this.iconKey,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Untuk SQLite & Supabase (nama kolom disamakan dua-duanya).
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': colorHex,
        'icon': iconKey,
        'is_deleted': isDeleted ? 1 : 0,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Dari SQLite (bool berbentuk int 0/1).
  factory CategoryModel.fromDb(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as String,
        userId: (map['user_id'] as String?) ?? '',
        name: map['name'] as String,
        colorHex: (map['color'] as String?) ?? '#16A34A',
        iconKey: (map['icon'] as String?) ?? 'lainnya',
        isDeleted: (map['is_deleted'] as int?) == 1,
        isSynced: (map['is_synced'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  /// Dari Supabase (bool asli).
  factory CategoryModel.fromServer(Map<String, dynamic> map) =>
      CategoryModel(
        id: map['id'] as String,
        userId: (map['user_id'] as String?) ?? '',
        name: map['name'] as String,
        colorHex: (map['color'] as String?) ?? '#16A34A',
        iconKey: (map['icon'] as String?) ?? 'lainnya',
        isDeleted: map['is_deleted'] == true,
        isSynced: true,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  /// Map untuk push ke Supabase (tanpa kolom lokal `is_synced`,
  /// bool untuk `is_deleted`).
  Map<String, dynamic> toServer() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': colorHex,
        'icon': iconKey,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
