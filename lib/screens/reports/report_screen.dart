/// Halaman Laporan (v1.0.0) — sesuai SPEC:
/// periode Harian/Mingguan/Bulanan/Tahunan (dengan panah geser),
/// ringkasan: total, jumlah transaksi, kategori terbanyak,
/// pengeluaran terbesar, rata-rata; rincian per kategori; grafik
/// batang periode; tombol Export PDF, Export Excel, Share.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/export_service.dart';
import '../../services/file_saver.dart';
import '../../utils/formatters.dart';
import '../../utils/icon_map.dart';
import '../../utils/page_transitions.dart';
import '../../utils/period.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/realtime_clock.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../expenses/expense_detail_screen.dart';
import 'final_report_screen.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _exporting = false;

  Future<void> _export(
      Future<SaveOutcome> Function(ReportData, String) action) async {
    final data = ref.read(reportDataProvider).valueOrNull;
    if (data == null || _exporting) return;
    if (data.count == 0) {
      showAppSnackBar(context, 'Tidak ada data pada periode ini.',
          isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final owner = ref.read(authProvider).name;
      final outcome = await action(
          data, owner.isEmpty ? 'Owner' : owner);
      if (!mounted) return;
      switch (outcome) {
        case SaveOutcome.saved:
          showAppSnackBar(context, 'File laporan berhasil disimpan.');
        case SaveOutcome.sharedViaSheet:
          break; // share sheet sudah tampil
        case SaveOutcome.cancelled:
          break; // pengguna batal — diam saja
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Export gagal, coba lagi.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = ref.watch(reportSelectionProvider);
    final dataAsync = ref.watch(reportDataProvider);

    // v1.1.0 (permintaan pemilik): tab kedua "Laporan Akhir" —
    // pemasukan (dari aplikasi kasir) - pengeluaran = laba bersih.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: TabBar(
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Pengeluaran'),
                  Tab(text: 'Laporan Akhir'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _pengeluaranTab(theme, selection, dataAsync),
                  const FinalReportScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab pertama: laporan pengeluaran (konten asli halaman ini).
  Widget _pengeluaranTab(ThemeData theme, ReportSelection selection,
      AsyncValue<ReportData> dataAsync) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
            Text('Laporan Pengeluaran',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const RealtimeClock(),
            const SizedBox(height: 12),

            // --- Pemilih periode ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in ReportPeriod.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: selection.period == p,
                        onSelected: (_) => ref
                            .read(reportSelectionProvider.notifier)
                            .setPeriod(p),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // --- Geser periode < label > ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => ref
                      .read(reportSelectionProvider.notifier)
                      .shift(-1),
                ),
                Expanded(
                  child: Text(
                    rangeFor(selection.period, selection.anchor)
                        .describe(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => ref
                      .read(reportSelectionProvider.notifier)
                      .shift(1),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Konten laporan ---
            dataAsync.when(
              loading: () => const Column(children: [
                SkeletonStatGrid(),
                SizedBox(height: 16),
                SkeletonBox(height: 160, radius: 20),
              ]),
              error: (e, _) => const EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Gagal memuat laporan'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Ringkasan (SPEC) ---
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      StatCard(
                        title: 'Total Pengeluaran',
                        value: Formatters.currency(data.total),
                        icon: Icons.payments_rounded,
                        color: AppColors.primary,
                        subtitle: '${data.count} transaksi',
                      ),
                      StatCard(
                        title: 'Rata-rata / Transaksi',
                        value: Formatters.currency(data.average),
                        icon: Icons.functions_rounded,
                        color: AppColors.info,
                      ),
                      StatCard(
                        title: 'Kategori Terbanyak',
                        value: data.topCategoryName ?? '-',
                        icon: Icons.category_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                      StatCard(
                        title: 'Pengeluaran Terbesar',
                        value: data.biggest == null
                            ? '-'
                            : Formatters.currency(data.biggest!.nominal),
                        icon: Icons.trending_up_rounded,
                        color: AppColors.danger,
                        subtitle: data.biggest?.name,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Tombol Export (SPEC) ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _export(ExportService().exportPdf),
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              size: 18),
                          label: const Text('PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting
                              ? null
                              : () =>
                                  _export(ExportService().exportExcel),
                          icon: const Icon(Icons.table_chart_rounded,
                              size: 18),
                          label: const Text('Excel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _export(ExportService().exportTxt),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Grafik batang periode ---
                  _PeriodChart(data: data),
                  const SizedBox(height: 16),

                  // --- Rincian per kategori ---
                  Text('Per Kategori',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (data.perCategory.isEmpty)
                    const EmptyState(
                      icon: Icons.category_outlined,
                      title: 'Belum ada data',
                      message: 'Tidak ada pengeluaran pada periode ini.',
                    )
                  else
                    for (final c in data.perCategory)
                      _CategoryRow(slice: c, total: data.total),

                  // --- Rincian transaksi ---
                  if (data.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Rincian Transaksi (${data.items.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final e in data.items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text(e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${e.date} ${e.time} • ${data.categoryNameOf(e.categoryId)}'),
                          trailing: Text(
                            Formatters.currency(e.nominal),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary),
                          ),
                          onTap: () => Navigator.of(context).push(fadeRoute(
                              ExpenseDetailScreen(expenseId: e.id))),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }
}

/// Baris kategori + progress bar porsi dari total.
class _CategoryRow extends StatelessWidget {
  final CategorySlice slice;
  final double total;

  const _CategoryRow({required this.slice, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = IconMap.colorFromHex(slice.colorHex);
    final ratio = total <= 0 ? 0.0 : slice.total / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(IconMap.of(slice.iconKey), color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(slice.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(Formatters.currency(slice.total),
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${slice.count} transaksi • ${(ratio * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grafik batang periode: harian=per jam (dikelompokkan kasar
/// per tanggal), mingguan=per hari Sen-Min, bulanan=per hari,
/// tahunan=per bulan. Sederhana tapi informatif.
class _PeriodChart extends StatelessWidget {
  final ReportData data;

  const _PeriodChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bangun titik data sesuai periode.
    final points = <String, double>{};
    final labels = <String>[];
    if (data.period == ReportPeriod.yearly) {
      const bln = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      labels.addAll(bln);
      for (var m = 1; m <= 12; m++) {
        points[m.toString()] = 0;
      }
      for (final e in data.items) {
        final m = int.parse(e.date.split('-')[1]);
        points[m.toString()] =
            (points[m.toString()] ?? 0) + e.nominal;
      }
    } else if (data.period == ReportPeriod.monthly) {
      final days = DateTime(data.range.start.year,
              data.range.start.month + 1, 0)
          .day;
      for (var d = 1; d <= days; d++) {
        points[d.toString()] = 0;
        labels.add(d.toString());
      }
      for (final e in data.items) {
        final d = int.parse(e.date.split('-')[2]);
        points[d.toString()] =
            (points[d.toString()] ?? 0) + e.nominal;
      }
    } else {
      // Harian & mingguan: per tanggal 'd/M'.
      final days = data.period == ReportPeriod.daily ? 1 : 7;
      for (var i = 0; i < days; i++) {
        final dt =
            data.range.start.add(Duration(days: i));
        final key = '${dt.day}/${dt.month}';
        points[key] = 0;
        labels.add(key);
      }
      for (final e in data.items) {
        final dt = DateTime.parse(e.date);
        final key = '${dt.day}/${dt.month}';
        if (points.containsKey(key)) {
          points[key] = (points[key] ?? 0) + e.nominal;
        }
      }
    }

    final values = [
      for (final k in points.keys) points[k]!,
    ];
    final maxY = values.fold<double>(0, (a, b) => b > a ? b : a) * 1.2;
    final hasData = values.any((v) => v > 0);
    final labelStep =
        (labels.length / 8).ceil(); // label jangan berdesakan

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grafik ${data.period.label}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: !hasData
                  ? Center(
                      child: Text('Belum ada data periode ini',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor)))
                  : BarChart(
                      BarChartData(
                        maxY: maxY == 0 ? 100 : maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                if (labels.length > 8 &&
                                    i % labelStep != 0 &&
                                    i != labels.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    labels[i],
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            fontSize: 9,
                                            color: theme.hintColor),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${labels[group.x.toInt()]}\n'
                                '${Formatters.currency(rod.toY)}',
                                theme.textTheme.bodySmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < values.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: values[i],
                                  width: values.length > 16 ? 6 : 12,
                                  borderRadius: BorderRadius.circular(4),
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
