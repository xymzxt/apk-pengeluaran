/// Halaman Beranda / Dashboard (v1.0.0) — sesuai SPEC:
/// total hari ini, minggu ini, bulan ini, tahun ini; grafik
/// pengeluaran per bulan; pengeluaran terakhir; pengeluaran
/// terbesar; jumlah transaksi. Plus jam realtime + chip online
/// (gaya aplikasi kasir) dan tarik-untuk-sinkron.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/sync_service.dart';
import '../../utils/formatters.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/realtime_clock.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../expenses/expense_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _syncing = false;

  /// Sinkron manual (tarik-ke-bawah atau tombol) + notifikasi hasil
  /// persis gaya aplikasi kasir: "X terkirim, Y ditarik".
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await SyncService.instance.syncNow();
    ref.read(dataVersionProvider.notifier).bump();
    if (mounted) {
      setState(() => _syncing = false);
      showAppSnackBar(context, result.describe(),
          isError: result.skipped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final data = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _sync,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              // --- Salam + aksi cepat ---
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${auth.name.isEmpty ? 'Owner' : auth.name}!',
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Pantau pengeluaran tokomu di sini',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sinkronisasi sekarang',
                    onPressed: _syncing ? null : _sync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const RealtimeClock(),
              const SizedBox(height: 16),

              data.when(
                loading: () => const Column(
                  children: [
                    SkeletonStatGrid(),
                    SizedBox(height: 16),
                    SkeletonBox(height: 200, radius: 20),
                    SizedBox(height: 16),
                    SkeletonList(itemCount: 3),
                  ],
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Gagal memuat dasbor',
                  message: 'Tarik ke bawah untuk mencoba lagi.',
                ),
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Kartu statistik utama (SPEC) ---
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        StatCard(
                          title: 'Hari Ini',
                          value: Formatters.currency(d.today),
                          icon: Icons.today_rounded,
                          color: AppColors.primary,
                        ),
                        StatCard(
                          title: 'Minggu Ini',
                          value: Formatters.currency(d.thisWeek),
                          icon: Icons.date_range_rounded,
                          color: AppColors.info,
                        ),
                        StatCard(
                          title: 'Bulan Ini',
                          value: Formatters.currency(d.thisMonth),
                          icon: Icons.calendar_month_rounded,
                          color: const Color(0xFF8B5CF6),
                          subtitle: '${d.transactionCount} transaksi',
                        ),
                        StatCard(
                          title: 'Tahun Ini',
                          value: Formatters.currency(d.thisYear),
                          icon: Icons.workspace_premium_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- Grafik per bulan (SPEC) ---
                    _MonthlyChart(totals: d.monthlyTotals),
                    const SizedBox(height: 16),

                    // --- Pengeluaran terbesar bulan ini (SPEC) ---
                    if (d.biggest != null)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.trending_up_rounded,
                                    color: AppColors.danger),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Pengeluaran Terbesar Bulan Ini',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme.hintColor)),
                                    Text(
                                      '${d.biggest!.name} — ${Formatters.currency(d.biggest!.nominal)}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // --- Pengeluaran terakhir (SPEC) ---
                    Row(
                      children: [
                        Text('Pengeluaran Terakhir',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (d.latest.isEmpty)
                      const EmptyState(
                        icon: Icons.savings_outlined,
                        title: 'Belum ada pengeluaran',
                        message:
                            'Tekan tombol + di bawah untuk mencatat pengeluaran pertamamu.',
                      )
                    else ...[
                      for (final ExpenseModel e in d.latest)
                        ExpenseTile(
                          expense: e,
                          category: ref
                              .watch(categoryMapProvider)[e.categoryId],
                          onTap: () => Navigator.of(context).push(
                              fadeRoute(ExpenseDetailScreen(
                                  expenseId: e.id))),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grafik batang pengeluaran per bulan (tahun berjalan) — SPEC.
class _MonthlyChart extends StatelessWidget {
  final List<double> totals;

  const _MonthlyChart({required this.totals});

  static const _labels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = totals.fold<double>(
            0, (a, b) => b > a ? b : a) *
        1.2;
    final hasData = totals.any((v) => v > 0);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grafik Pengeluaran per Bulan (${DateTime.now().year})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: !hasData
                  ? Center(
                      child: Text('Belum ada data tahun ini',
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
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i > 11) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _labels[i],
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
                        // Tooltip dibatasi agar tidak keluar kartu
                        // (pelajaran dari aplikasi kasir).
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${_labels[group.x.toInt()]}\n'
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
                          for (var i = 0; i < 12; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: totals[i],
                                  width: 10,
                                  borderRadius: BorderRadius.circular(4),
                                  color: theme.colorScheme.primary,
                                  backDrawRodData:
                                      BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxY == 0 ? 100 : maxY,
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.05),
                                  ),
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
