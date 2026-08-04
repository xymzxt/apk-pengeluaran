/// Model pengguna LOKAL untuk login gaya kasir (v1.0.1, permintaan
/// pemilik).
///
/// Berbeda dengan akun cloud (Supabase Auth robot): tabel ini hanya
/// hidup di SQLite perangkat — dipakai untuk pintu masuk aplikasi
/// (owner pakai sandi khusus, keluarga tap nama) dan untuk
/// mencatat SIAPA yang mengetik pengeluaran.
library;

class AppUserModel {
  final String id;
  final String name;

  /// 'owner' (satu akun, pakai sandi) atau 'keluarga' (tap nama saja).
  final String role;

  /// Hash SHA-256 sandi (hanya owner).
  final String? passwordHash;

  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUserModel({
    required this.id,
    required this.name,
    required this.role,
    this.passwordHash,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOwner => role == 'owner';
  bool get needsPassword => isOwner && (passwordHash?.isNotEmpty ?? false);

  AppUserModel copyWith({
    String? name,
    String? role,
    String? passwordHash,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      AppUserModel(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        passwordHash: passwordHash ?? this.passwordHash,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'role': role,
        'password_hash': passwordHash,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AppUserModel.fromDb(Map<String, dynamic> map) => AppUserModel(
        id: map['id'] as String,
        name: map['name'] as String,
        role: map['role'] as String,
        passwordHash: map['password_hash'] as String?,
        isDeleted: (map['is_deleted'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
