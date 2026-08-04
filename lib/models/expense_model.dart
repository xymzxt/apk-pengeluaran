/// Model Pengeluaran (v1.0.0).
///
/// Offline-first di SQLite, disinkronkan ke tabel `expenses` Supabase.
/// Field mengikuti SPEC-PENGELUARAN.md: nama, nominal, kategori,
/// tanggal, jam, metode pembayaran, catatan, dan foto nota.
library;

class ExpenseModel {
  final String id;

  /// Pemilik data (uid Supabase Auth) — kosong di mode offline penuh.
  final String userId;

  /// FK ke kategori (boleh null = tanpa kategori).
  final String? categoryId;

  final String name;
  final double nominal;
  final String method; // kode metode pembayaran (lihat AppConstants)

  /// Tanggal nota (tanggal & jam dipisah sesuai SPEC: field Tanggal
  /// dan field Jam). Keduanya disimpan ISO: 'yyyy-MM-dd' & 'HH:mm'.
  final String date;
  final String time;

  final String note;

  /// Foto nota: `photoLocal` = path file lokal (offline-first),
  /// `photoRemote` = path objek di Supabase Storage setelah diunggah.
  final String? photoLocal;
  final String? photoRemote;

  final bool isDeleted;
  final bool isSynced;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    this.userId = '',
    this.categoryId,
    required this.name,
    required this.nominal,
    required this.method,
    required this.date,
    required this.time,
    this.note = '',
    this.photoLocal,
    this.photoRemote,
    this.isDeleted = false,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Nomor unik lokal untuk penamaan file nota & folder Storage.
  String get storageObject => '$userId/$id.jpg';

  DateTime get dateTime => DateTime.parse('$date $time');

  ExpenseModel copyWith({
    String? categoryId,
    bool clearCategory = false,
    String? name,
    double? nominal,
    String? method,
    String? date,
    String? time,
    String? note,
    String? photoLocal,
    bool clearPhotoLocal = false,
    String? photoRemote,
    bool clearPhotoRemote = false,
    bool? isDeleted,
    bool? isSynced,
    String? userId,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id,
      userId: userId ?? this.userId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      name: name ?? this.name,
      nominal: nominal ?? this.nominal,
      method: method ?? this.method,
      date: date ?? this.date,
      time: time ?? this.time,
      note: note ?? this.note,
      photoLocal: clearPhotoLocal ? null : (photoLocal ?? this.photoLocal),
      photoRemote:
          clearPhotoRemote ? null : (photoRemote ?? this.photoRemote),
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'user_id': userId,
        'category_id': categoryId,
        'name': name,
        'nominal': nominal,
        'method': method,
        'date': date,
        'time': time,
        'note': note,
        'photo_local': photoLocal,
        'photo_remote': photoRemote,
        'is_deleted': isDeleted ? 1 : 0,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ExpenseModel.fromDb(Map<String, dynamic> map) => ExpenseModel(
        id: map['id'] as String,
        userId: (map['user_id'] as String?) ?? '',
        categoryId: map['category_id'] as String?,
        name: map['name'] as String,
        nominal: (map['nominal'] as num).toDouble(),
        method: map['method'] as String,
        date: map['date'] as String,
        time: map['time'] as String,
        note: (map['note'] as String?) ?? '',
        photoLocal: map['photo_local'] as String?,
        photoRemote: map['photo_remote'] as String?,
        isDeleted: (map['is_deleted'] as int?) == 1,
        isSynced: (map['is_synced'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  factory ExpenseModel.fromServer(Map<String, dynamic> map) => ExpenseModel(
        id: map['id'] as String,
        userId: (map['user_id'] as String?) ?? '',
        categoryId: map['category_id'] as String?,
        name: map['name'] as String,
        nominal: (map['nominal'] as num).toDouble(),
        method: map['method'] as String,
        date: map['date'] as String,
        time: map['time'] as String,
        note: (map['note'] as String?) ?? '',
        photoRemote: map['photo_remote'] as String?,
        isDeleted: map['is_deleted'] == true,
        isSynced: true,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  /// Map untuk push ke Supabase (kolom lokal `photo_local` & `is_synced`
  /// tidak dikirim; `is_deleted` berupa bool).
  Map<String, dynamic> toServer() => {
        'id': id,
        'user_id': userId,
        'category_id': categoryId,
        'name': name,
        'nominal': nominal,
        'method': method,
        'date': date,
        'time': time,
        'note': note,
        'photo_remote': photoRemote,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
