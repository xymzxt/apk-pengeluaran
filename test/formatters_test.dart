import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pengeluaran/utils/currency_input.dart';
import 'package:pengeluaran/utils/formatters.dart';
import 'package:pengeluaran/utils/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('CurrencyInputFormatter', () {
    test('format angka ke ribuan Indonesia', () {
      expect(CurrencyInputFormatter.format(12500), '12.500');
      expect(CurrencyInputFormatter.format(1000000), '1.000.000');
      expect(CurrencyInputFormatter.format(0), '0');
    });

    test('parse teks ribuan ke angka', () {
      expect(CurrencyInputFormatter.parse('12.500'), 12500);
      expect(CurrencyInputFormatter.parse('Rp 1.000.000'), 1000000);
      expect(CurrencyInputFormatter.parse(''), 0);
      expect(CurrencyInputFormatter.parse('abc'), 0);
    });
  });

  group('Formatters', () {
    test('currency', () {
      expect(Formatters.currency(12500), 'Rp 12.500');
    });

    test('compact', () {
      expect(Formatters.compact(1500), '1,5 rb');
      expect(Formatters.compact(2500000), '2,5 jt');
      expect(Formatters.compact(1250000000), '1,3 M');
      expect(Formatters.compact(500), '500');
    });
  });

  group('Validators', () {
    test('required menolak kosong', () {
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('isi'), isNull);
    });

    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('bukan-email'),
          isNotNull);
      expect(Validators.email('nama@gmail.com'), isNull);
    });

    test('password minimal 6 karakter', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('nominal tidak boleh nol (SPEC)', () {
      expect(Validators.nominal(''), isNotNull);
      expect(Validators.nominal('0'), isNotNull);
      expect(Validators.nominal('12.500'), isNull);
    });
  });
}
