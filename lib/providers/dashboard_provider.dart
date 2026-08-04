/// Provider dashboard (v1.0.0) — statistik ringkas halaman Beranda:
/// total hari ini / minggu ini / bulan ini / tahun ini, grafik per
/// bulan, pengeluaran terakhir, pengeluaran terbesar, jumlah
/// transaksi (sesuai SPEC-PENGELUARAN.md).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/expense_repository.dart';
import '../models/expense_model.dart';
import '../utils/period.dart';
import 'data_providers.dart';

/// Bundel data dashboard.
class DashboardData {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final double thisYear;
  final int transactionCount; // bulan ini
  final List<double> monthlyTotals; // 12 titik tahun ini (grafik)
  final List<ExpenseModel> latest; // 5 terakhir
  final ExpenseModel? biggest; // terbesar bulan ini

  const DashboardData({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.transactionCount,
    required this.monthlyTotals,
    required this.latest,
    required this.biggest,
  });

  bool get isEmpty =>
      transactionCount == 0 && thisYear == 0 && latest.isEmpty;
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  ref.watch(dataVersionProvider);
  final repo = ExpenseRepository.instance;
  final now = DateTime.now();

  final daily = rangeFor(ReportPeriod.daily, now);
  final weekly = rangeFor(ReportPeriod.weekly, now);
  final monthly = rangeFor(ReportPeriod.monthly, now);
  final yearly = rangeFor(ReportPeriod.yearly, now);

  // Dijalankan berurutan agar hemat koneksi DB (sqflite single).
  final today = await repo.totalForRange(daily);
  final week = await repo.totalForRange(weekly);
  final month = await repo.totalForRange(monthly);
  final year = await repo.totalForRange(yearly);
  final count = await repo.countForRange(monthly);
  final monthlyTotals = await repo.monthlyTotals(now.year);
  final latest = await repo.latest(5);
  final biggest = await repo.biggestInRange(monthly);

  return DashboardData(
    today: today,
    thisWeek: week,
    thisMonth: month,
    thisYear: year,
    transactionCount: count,
    monthlyTotals: monthlyTotals,
    latest: latest,
    biggest: biggest,
  );
});
