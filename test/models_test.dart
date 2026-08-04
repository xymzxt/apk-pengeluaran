import 'package:flutter_test/flutter_test.dart';
import 'package:pengeluaran/models/category_model.dart';
import 'package:pengeluaran/models/expense_model.dart';

void main() {
  group('CategoryModel', () {
    test('db -> model -> server roundtrip menjaga kolom', () {
      final now = DateTime(2026, 8, 4, 10, 30);
      final cat = CategoryModel(
        id: 'c1',
        userId: 'u1',
        name: 'Belanja Barang',
        colorHex: '#16A34A',
        iconKey: 'belanja',
        isSynced: true,
        createdAt: now,
        updatedAt: now,
      );
      final fromDb = CategoryModel.fromDb(cat.toMap());
      expect(fromDb.name, 'Belanja Barang');
      expect(fromDb.isSynced, isTrue);

      final server = cat.toServer();
      expect(server['is_deleted'], isA<bool>());
      expect(server.containsKey('is_synced'), isFalse);
    });
  });

  group('ExpenseModel', () {
    final now = DateTime(2026, 8, 4, 21, 15);
    final exp = ExpenseModel(
      id: 'e1',
      userId: 'u1',
      categoryId: 'c1',
      name: 'Beli es batu',
      nominal: 13500,
      method: 'tunai',
      date: '2026-08-04',
      time: '21:15',
      note: 'untuk warung',
      isSynced: true,
      createdAt: now,
      updatedAt: now,
    );

    test('db roundtrip', () {
      final fromDb = ExpenseModel.fromDb(exp.toDb());
      expect(fromDb.nominal, 13500);
      expect(fromDb.date, '2026-08-04');
      expect(fromDb.time, '21:15');
      expect(fromDb.isSynced, isTrue);
    });

    test('roundtrip server', () {
      final serverMap = exp.toServer();
      expect(serverMap.containsKey('photo_local'), isFalse);
      expect(serverMap['is_deleted'], isA<bool>());
      final fromServer = ExpenseModel.fromServer(serverMap);
      expect(fromServer.name, 'Beli es batu');
      expect(fromServer.nominal, 13500);
      expect(fromServer.isSynced, isTrue);
    });

    test('dateTime menggabung tanggal & jam', () {
      expect(exp.dateTime, DateTime(2026, 8, 4, 21, 15));
    });

    test('storageObject = uid/id.jpg', () {
      expect(exp.storageObject, 'u1/e1.jpg');
    });

    test('copyWith clearCategory & clearPhotoLocal', () {
      final cleared = exp.copyWith(clearCategory: true);
      expect(cleared.categoryId, isNull);
      final noPhoto = exp
          .copyWith(photoLocal: '/tmp/a.jpg')
          .copyWith(clearPhotoLocal: true);
      expect(noPhoto.photoLocal, isNull);
    });
  });
}
