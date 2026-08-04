/// Halaman Detail Pengeluaran (v1.0.0) — sesuai SPEC: tampilkan
/// nama, nominal, kategori, tanggal, jam, metode pembayaran, catatan,
/// dan foto nota (ketuk untuk zoom penuh). Ada aksi Edit & Hapus
/// (hapus wajib konfirmasi).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../database/expense_repository.dart';
import '../../models/expense_model.dart';
import '../../providers/data_providers.dart';
import '../../utils/formatters.dart';
import '../../utils/icon_map.dart';
import '../../widgets/realtime_clock.dart';
import '../../widgets/skeleton.dart';
import 'expense_form_screen.dart';
import 'expense_history_screen.dart' show deleteExpenseWithConfirm;

/// Provider satu pengeluaran by id (refresh ikut dataVersion).
final expenseDetailProvider =
    FutureProvider.family<ExpenseModel?, String>((ref, id) async {
  ref.watch(dataVersionProvider);
  return ExpenseRepository.instance.getExpense(id);
});

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final catMap = ref.watch(categoryMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengeluaran'),
        actions: [
          expenseAsync.maybeWhen(
            data: (e) => e == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    ExpenseFormScreen(existing: e)),
                          );
                          if (!context.mounted) return;
                          ref
                              .read(dataVersionProvider.notifier)
                              .bump();
                        },
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: Icon(Icons.delete_outline_rounded,
                            color: theme.colorScheme.error),
                        onPressed: () async {
                          final deleted =
                              await deleteExpenseWithConfirm(
                                  context, ref, e);
                          if (deleted && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: expenseAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: SkeletonList(itemCount: 4),
        ),
        error: (e, _) => const Center(child: Text('Gagal memuat data.')),
        data: (expense) {
          if (expense == null) {
            return const Center(child: Text('Data tidak ditemukan.'));
          }
          final category = catMap[expense.categoryId];
          final catColor =
              IconMap.colorFromHex(category?.colorHex, fallback: Colors.grey);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const RealtimeClock(),
              const SizedBox(height: 16),

              // --- Nominal besar ---
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(IconMap.of(category?.iconKey),
                                color: catColor, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              expense.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.currency(expense.nominal),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Rincian ---
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _detailRow(theme, Icons.category_outlined, 'Kategori',
                          category?.name ?? 'Tanpa Kategori'),
                      const Divider(height: 20),
                      _detailRow(
                          theme,
                          Icons.calendar_month_rounded,
                          'Tanggal',
                          Formatters.date(
                              DateTime.parse(expense.date))),
                      const Divider(height: 20),
                      _detailRow(theme, Icons.schedule_rounded, 'Jam',
                          expense.time),
                      const Divider(height: 20),
                      _detailRow(
                          theme,
                          Icons.payments_outlined,
                          'Metode Pembayaran',
                          AppConstants.paymentLabel(expense.method)),
                      if (expense.note.isNotEmpty) ...[
                        const Divider(height: 20),
                        _detailRow(theme, Icons.sticky_note_2_outlined,
                            'Catatan', expense.note),
                      ],
                    ],
                  ),
                ),
              ),

              // --- Foto nota ---
              if (expense.photoLocal != null ||
                  expense.photoRemote != null) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto Nota',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _ReceiptPhoto(expense: expense),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Foto nota: tampil dari file lokal; bila tidak ada (datang dari HP
/// lain dan belum terunduh) -> unduh berdasar path remote.
class _ReceiptPhoto extends ConsumerStatefulWidget {
  final ExpenseModel expense;

  const _ReceiptPhoto({required this.expense});

  @override
  ConsumerState<_ReceiptPhoto> createState() => _ReceiptPhotoState();
}

class _ReceiptPhotoState extends ConsumerState<_ReceiptPhoto> {
  String? _localPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final e = widget.expense;
    if (e.photoLocal != null && await File(e.photoLocal!).exists()) {
      if (mounted) {
        setState(() {
          _localPath = e.photoLocal;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = false);
  }

  void _openZoom() {
    if (_localPath == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 6,
                child: Image.file(File(_localPath!)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const SkeletonBox(height: 180, radius: 16);
    }
    if (_localPath == null) {
      // Foto ada di cloud namun belum sempat terunduh.
      return Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.cardBorder(
                  theme.brightness == Brightness.dark)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined,
                  color: theme.hintColor),
              const SizedBox(height: 6),
              Text('Foto tersimpan di cloud.\nSinkronkan untuk mengunduh.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openZoom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.file(
              File(_localPath!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Ketuk untuk zoom',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
