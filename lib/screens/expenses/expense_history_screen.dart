/// Halaman Riwayat Pengeluaran (v1.0.0) — sesuai SPEC:
/// cari (nama/kategori/catatan, real-time), filter kategori, filter
/// tanggal, filter metode pembayaran, urutkan terbaru/terlama,
/// ketuk item -> detail, edit & hapus dengan konfirmasi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../database/expense_repository.dart';
import '../../models/expense_model.dart';
import '../../providers/data_providers.dart';
import '../../services/image_service.dart';
import '../../utils/formatters.dart';
import '../../utils/page_transitions.dart';
import '../../utils/period.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/realtime_clock.dart';
import '../../widgets/search_field.dart';
import '../../widgets/skeleton.dart';
import 'expense_detail_screen.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Infinite scroll ringan: muat +30 saat mendekati dasar.
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(historyFilterProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 7)), end: now),
      firstDate: DateTime(2021),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) {
      // Rentang [start, end+1hari): end eksklusif seperti DateRange.
      ref.read(historyFilterProvider.notifier).setRange(DateRange(
          DateTime(picked.start.year, picked.start.month, picked.start.day),
          DateTime(picked.end.year, picked.end.month, picked.end.day)
              .add(const Duration(days: 1))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(historyFilterProvider);
    final list = ref.watch(historyListProvider);
    final categories =
        ref.watch(categoryListProvider).valueOrNull ?? [];
    final catMap = ref.watch(categoryMapProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Kepala ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Riwayat Pengeluaran',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const RealtimeClock(),
                  const SizedBox(height: 12),
                  SearchField(
                    hintText: 'Cari nama, kategori, atau catatan...',
                    onChanged: (v) => ref
                        .read(historyFilterProvider.notifier)
                        .setSearch(v),
                  ),
                  const SizedBox(height: 10),
                  // --- Baris filter: kategori, metode, tanggal, urut ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          icon: Icons.category_outlined,
                          label: filter.categoryId == null
                              ? 'Kategori'
                              : catMap[filter.categoryId]?.name ?? 'Kategori',
                          active: filter.categoryId != null,
                          onTap: () => _showCategoryPicker(categories),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          icon: Icons.payments_outlined,
                          label: filter.method == null
                              ? 'Metode'
                              : AppConstants.paymentLabel(filter.method!),
                          active: filter.method != null,
                          onTap: _showMethodPicker,
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          icon: Icons.calendar_month_rounded,
                          label: filter.range == null
                              ? 'Tanggal'
                              : filter.range!.describe(),
                          active: filter.range != null,
                          onTap: _pickRange,
                          onClear: () => ref
                              .read(historyFilterProvider.notifier)
                              .setRange(null),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          icon: filter.newestFirst
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          label: filter.newestFirst ? 'Terbaru' : 'Terlama',
                          active: false,
                          onTap: () => ref
                              .read(historyFilterProvider.notifier)
                              .toggleSort(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Daftar ---
            Expanded(
              child: list.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SkeletonList(itemCount: 6),
                ),
                error: (e, _) => const EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Gagal memuat riwayat',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Tidak ada pengeluaran',
                      message:
                          'Coba ubah filter/pencarian, atau tambah pengeluaran baru lewat tombol +.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref
                        .read(dataVersionProvider.notifier)
                        .bump(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount:
                          items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          // Penanda bawah / tombol muat lagi.
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                '${items.length} data ditampilkan',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor),
                              ),
                            ),
                          );
                        }
                        final ExpenseModel e = items[index];
                        return ExpenseTile(
                          expense: e,
                          category: catMap[e.categoryId],
                          onTap: () => Navigator.of(context).push(
                            fadeRoute(
                                ExpenseDetailScreen(expenseId: e.id)),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: active
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : AppColors.cardBorder(
                      Theme.of(context).brightness == Brightness.dark),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.hintColor),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active && onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded,
                      size: 14, color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryPicker(List categories) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Filter Kategori',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('Semua Kategori'),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final c in categories)
                ListTile(
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: () {
                      final hex = (c.colorHex as String).replaceAll('#', '');
                      final v = int.tryParse(hex, radix: 16);
                      return v == null
                          ? Colors.green
                          : Color(0xFF000000 | v);
                    }(),
                  ),
                  title: Text(c.name as String),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(c.id as String),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      ref
          .read(historyFilterProvider.notifier)
          .setCategory(selected.isEmpty ? null : selected);
    }
  }

  Future<void> _showMethodPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Filter Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('Semua Metode'),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final m in AppConstants.paymentMethods)
                ListTile(
                  leading:
                      const Icon(Icons.payments_outlined),
                  title: Text(m['label']!),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(m['code']),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      ref
          .read(historyFilterProvider.notifier)
          .setMethod(selected.isEmpty ? null : selected);
    }
  }
}

/// Dipakai halaman detail untuk aksi hapus cepat (agar logika hapus
/// terpusat & konsisten dengan konfirmasi).
Future<bool> deleteExpenseWithConfirm(
    BuildContext context, WidgetRef ref, ExpenseModel expense) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Hapus Pengeluaran?',
    message: '"${expense.name}" '
        '(${Formatters.currency(expense.nominal)}) akan dihapus. '
        'Data bisa tersalin kembali bila perangkat lain belum sinkron.',
    confirmText: 'Hapus',
  );
  if (!ok) return false;
  await ExpenseRepository.instance.deleteExpense(expense.id);
  // Hapus file foto lokal agar hemat penyimpanan.
  await ImageService().deleteIfExists(expense.photoLocal);
  ref.read(dataVersionProvider.notifier).bump();
  if (context.mounted) {
    showAppSnackBar(context, 'Pengeluaran berhasil dihapus.');
  }
  return true;
}
