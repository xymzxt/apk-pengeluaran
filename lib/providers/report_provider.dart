/// Provider laporan (v1.0.0) — periode harian/mingguan/bulanan/
/// tahunan + statistik sesuai SPEC: total, jumlah transaksi,
/// kategori terbanyak, pengeluaran terbesar, rata-rata.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/expense_repository.dart';
import '../models/expense_model.dart';
import '../utils/period.dart';
import 'data_providers.dart';

/// Potongan kategori dalam laporan.
class CategorySlice {
  final String name;
  final String colorHex;
  final String iconKey;
  final double total;
  final int count;

  const CategorySlice({
    required this.name,
    required this.colorHex,
    required this.iconKey,
    required this.total,
    required this.count,
  });
}

/// Bundel data laporan untuk satu periode.
class ReportData {
  final ReportPeriod period;
  final DateRange range;
  final double total;
  final int count;
  final ExpenseModel? biggest;
  final List<CategorySlice> perCategory;
  final List<ExpenseModel> items;

  /// Lookup id kategori -> nama (diisi dari tabel categories saat
  /// provider membangun data; dipakai tabel rincian & export).
  final Map<String, String> categoryNames;

  const ReportData({
    required this.period,
    required this.range,
    required this.total,
    required this.count,
    required this.biggest,
    required this.perCategory,
    required this.items,
    this.categoryNames = const {},
  });

  /// Rata-rata pengeluaran per transaksi (SPEC).
  double get average => count == 0 ? 0 : total / count;

  /// Kategori dengan total terbesar (SPEC: kategori terbanyak).
  String? get topCategoryName =>
      perCategory.isEmpty ? null : perCategory.first.name;

  /// Nama kategori untuk id ([null]/tak dikenal -> 'Tanpa Kategori').
  String categoryNameOf(String? id) =>
      id == null ? 'Tanpa Kategori' : (categoryNames[id] ?? 'Tanpa Kategori');
}

/// State pemilih periode laporan.
class ReportSelection {
  final ReportPeriod period;
  final DateTime anchor;

  const ReportSelection(this.period, this.anchor);

  ReportSelection copyWith({ReportPeriod? period, DateTime? anchor}) =>
      ReportSelection(period ?? this.period, anchor ?? this.anchor);
}

final reportSelectionProvider =
    StateNotifierProvider<ReportSelectionController, ReportSelection>((ref) {
  return ReportSelectionController();
});

class ReportSelectionController extends StateNotifier<ReportSelection> {
  ReportSelectionController()
      : super(ReportSelection(ReportPeriod.daily, DateTime.now()));

  void setPeriod(ReportPeriod period) =>
      state = state.copyWith(period: period);

  /// Lompat ke tanggal tertentu (v1.2.0 — label periode di layar
  /// laporan bisa diketuk untuk membuka kalender, seperti aplikasi
  /// kasir; kalender 5 tahun ke belakang s.d. 6 tahun ke depan).
  void jumpTo(DateTime date) => state = state.copyWith(anchor: date);

  /// Geser periode ke depan/belakang (panah < > di layar laporan).
  void shift(int step) {
    final a = state.anchor;
    final next = switch (state.period) {
      ReportPeriod.daily => DateTime(a.year, a.month, a.day + step),
      ReportPeriod.weekly => DateTime(a.year, a.month, a.day + 7 * step),
      ReportPeriod.monthly => DateTime(a.year, a.month + step),
      ReportPeriod.yearly => DateTime(a.year + step),
    };
    state = state.copyWith(anchor: next);
  }
}

final reportDataProvider = FutureProvider<ReportData>((ref) async {
  ref.watch(dataVersionProvider);
  final selection = ref.watch(reportSelectionProvider);
  final repo = ExpenseRepository.instance;
  final range = rangeFor(selection.period, selection.anchor);

  final total = await repo.totalForRange(range);
  final count = await repo.countForRange(range);
  final biggest = await repo.biggestInRange(range);
  final perCatRaw = await repo.totalPerCategory(range);
  final items = await repo.queryExpenses(range: range);
  final categories = await repo.getCategories();

  final perCategory = [
    for (final row in perCatRaw)
      CategorySlice(
        name: row['cat_name'] as String,
        colorHex: row['cat_color'] as String,
        iconKey: row['cat_icon'] as String,
        total: ((row['total'] as num?) ?? 0).toDouble(),
        count: ((row['cnt'] as num?) ?? 0).toInt(),
      ),
  ];

  return ReportData(
    period: selection.period,
    range: range,
    total: total,
    count: count,
    biggest: biggest,
    perCategory: perCategory,
    items: items,
    categoryNames: {for (final c in categories) c.id: c.name},
  );
});
