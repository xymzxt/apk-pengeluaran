/// Provider data utama: kategori & pengeluaran (offline-first).
///
/// Pola sama seperti aplikasi kasir: seluruh layar membaca dari
/// SQLite lewat repository dan "ter-refresh" setiap [dataVersionProvider]
/// bertambah (setelah CRUD / sinkron) — v1.0.0.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/expense_repository.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../utils/period.dart';

/// Penanda versi data — dinaikkan saat ada perubahan agar semua
/// provider turunan me-refresh dari database lokal.
final dataVersionProvider =
    StateNotifierProvider<DataVersionController, int>((ref) {
  return DataVersionController();
});

class DataVersionController extends StateNotifier<int> {
  DataVersionController() : super(0);
  void bump() => state++;
}

// -----------------------------------------------------------
// KATEGORI
// -----------------------------------------------------------

/// Semua kategori aktif (urut nama).
final categoryListProvider = FutureProvider<List<CategoryModel>>((ref) async {
  ref.watch(dataVersionProvider);
  return ExpenseRepository.instance.getCategories();
});

/// Map id -> kategori (lookup cepat untuk tampilan).
final categoryMapProvider = Provider<Map<String, CategoryModel>>((ref) {
  final list = ref.watch(categoryListProvider).valueOrNull ?? const [];
  return {for (final c in list) c.id: c};
});

// -----------------------------------------------------------
// PENGELUARAN — RIWAYAT (filter & pencarian)
// -----------------------------------------------------------

/// State filter riwayat.
class HistoryFilter {
  final String search;
  final String? categoryId;
  final String? method;
  final DateRange? range;
  final bool newestFirst;
  final int visibleCount;

  const HistoryFilter({
    this.search = '',
    this.categoryId,
    this.method,
    this.range,
    this.newestFirst = true,
    this.visibleCount = 30,
  });

  HistoryFilter copyWith({
    String? search,
    String? categoryId,
    bool clearCategory = false,
    String? method,
    bool clearMethod = false,
    DateRange? range,
    bool clearRange = false,
    bool? newestFirst,
    int? visibleCount,
  }) =>
      HistoryFilter(
        search: search ?? this.search,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        method: clearMethod ? null : (method ?? this.method),
        range: clearRange ? null : (range ?? this.range),
        newestFirst: newestFirst ?? this.newestFirst,
        visibleCount: visibleCount ?? this.visibleCount,
      );
}

final historyFilterProvider =
    StateNotifierProvider<HistoryFilterController, HistoryFilter>((ref) {
  return HistoryFilterController();
});

class HistoryFilterController extends StateNotifier<HistoryFilter> {
  HistoryFilterController() : super(const HistoryFilter());

  void setSearch(String value) =>
      state = state.copyWith(search: value, visibleCount: 30);

  void setCategory(String? id) => state = id == null
      ? state.copyWith(clearCategory: true, visibleCount: 30)
      : state.copyWith(categoryId: id, visibleCount: 30);

  void setMethod(String? code) => state = code == null
      ? state.copyWith(clearMethod: true, visibleCount: 30)
      : state.copyWith(method: code, visibleCount: 30);

  void setRange(DateRange? range) => state = range == null
      ? state.copyWith(clearRange: true, visibleCount: 30)
      : state.copyWith(range: range, visibleCount: 30);

  void toggleSort() => state = state.copyWith(newestFirst: !state.newestFirst);

  void loadMore() =>
      state = state.copyWith(visibleCount: state.visibleCount + 30);
}

/// Hasil riwayat sesuai filter aktif (pencarian real-time meliputi
/// nama, catatan, DAN nama kategori sesuai SPEC).
final historyListProvider =
    FutureProvider<List<ExpenseModel>>((ref) async {
  ref.watch(dataVersionProvider);
  final filter = ref.watch(historyFilterProvider);
  final repo = ExpenseRepository.instance;

  if (filter.search.trim().isNotEmpty &&
      filter.categoryId == null &&
      filter.method == null &&
      filter.range == null) {
    return repo.searchExpenses(filter.search,
        limit: filter.visibleCount, newestFirst: filter.newestFirst);
  }
  return repo.queryExpenses(
    search: filter.search,
    categoryId: filter.categoryId,
    method: filter.method,
    range: filter.range,
    newestFirst: filter.newestFirst,
    limit: filter.visibleCount,
  );
});
