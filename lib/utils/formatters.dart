/// Helper format tampilan angka & tanggal (v1.0.0).
library;

import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  static final DateFormat _date = DateFormat('dd MMM yyyy', 'id_ID');

  /// 12500 -> "Rp 12.500"
  static String currency(num value) => _rupiah.format(value);

  /// Ringkas angka besar untuk label grafik:
  /// 1500 -> "1,5 rb", 2500000 -> "2,5 jt", 1250000000 -> "1,3 M".
  static String compact(num value) {
    final v = value.toDouble();
    final q = NumberFormat('0.###', 'id_ID');
    if (v.abs() >= 1000000000) return '${q.format(v / 1000000000)} M';
    if (v.abs() >= 1000000) return '${q.format(v / 1000000)} jt';
    if (v.abs() >= 1000) return '${q.format(v / 1000)} rb';
    return q.format(v);
  }

  /// Format tanggal & jam ringkas untuk riwayat/detail.
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Format tanggal saja.
  static String date(DateTime value) => _date.format(value);

  /// 'HH:mm' untuk kolom jam (SPEC: field Jam pada pengeluaran).
  static String timeOfDate(DateTime value) => DateFormat('HH:mm').format(value);

  /// Label bulan-tahun, mis. "Agustus 2026".
  static String monthYear(DateTime value) =>
      DateFormat('MMMM yyyy', 'id_ID').format(value);

  /// Nama bulan singkat, mis. "Agu".
  static String monthShort(DateTime value) =>
      DateFormat('MMM', 'id_ID').format(value);
}
