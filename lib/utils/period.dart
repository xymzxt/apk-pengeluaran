/// Rentang tanggal untuk filter riwayat & laporan (SPEC: laporan
/// harian, mingguan, bulanan, tahunan) — v1.0.0, sama seperti kasir.
library;

enum ReportPeriod { daily, weekly, monthly, yearly }

extension ReportPeriodX on ReportPeriod {
  String get label => switch (this) {
        ReportPeriod.daily => 'Harian',
        ReportPeriod.weekly => 'Mingguan',
        ReportPeriod.monthly => 'Bulanan',
        ReportPeriod.yearly => 'Tahunan',
      };
}

/// Rentang [start, end) — start inklusif, end eksklusif.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  /// Label singkat periode, mis. "2/8/2026" atau "27/7/2026 – 2/8/2026".
  String describe() {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.subtract(const Duration(days: 1)).day &&
        end.difference(start).inDays == 1) {
      return fmt(start);
    }
    final endShow = end.subtract(const Duration(days: 1));
    return '${fmt(start)} – ${fmt(endShow)}';
  }
}

/// Batas kalender pemilih tanggal (v1.2.0, permintaan pemilik —
/// "seperti aplikasi kasir"): 5 tahun ke belakang s.d. 6 tahun ke
/// depan; keduanya dinamis mengikuti tahun berjalan.
DateTime reportCalendarStart() => DateTime(DateTime.now().year - 5);

DateTime reportCalendarEnd() =>
    DateTime(DateTime.now().year + 6, 12, 31);

/// Menghitung rentang tanggal untuk [period] berdasarkan [anchor].
DateRange rangeFor(ReportPeriod period, DateTime anchor) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (period) {
    case ReportPeriod.daily:
      return DateRange(day, day.add(const Duration(days: 1)));
    case ReportPeriod.weekly:
      // Minggu dimulai Senin.
      final monday =
          day.subtract(Duration(days: day.weekday - DateTime.monday));
      return DateRange(monday, monday.add(const Duration(days: 7)));
    case ReportPeriod.monthly:
      final first = DateTime(anchor.year, anchor.month);
      return DateRange(first, DateTime(anchor.year, anchor.month + 1));
    case ReportPeriod.yearly:
      return DateRange(DateTime(anchor.year), DateTime(anchor.year + 1));
  }
}
