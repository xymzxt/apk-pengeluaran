/// Halaman Laporan Akhir (v1.1.0, permintaan pemilik):
///
///   PEMASUKAN (otomatis dari aplikasi kasir) - PENGELUARAN
///   ---------------------------------------------------
///   = LABA BERSIH, per HARI / BULAN / TAHUN + DIGRAM perbandingan.
///
/// Pemasukan ditarik otomatis dari tabel penjualan aplikasi kasir
/// (fungsi SQL get_daily_income, dipasang sekali lewat
/// SQL-LAPORAN-AKHIR.sql) dan dicache lokal agar terbaca offline.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../../providers/final_report_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/period.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/realtime_clock.dart';

class FinalReportScreen extends ConsumerWidget {
  const FinalReportScreen({super.key});

  /// Satu kolom pada diagram/tabel rincian — [key] dipakai sebagai
  /// prefix penjumlahan (harian 'yyyy-MM-dd', bulanan 'yyyy-MM',
  /// tahunan 'yyyy').
  static _Bucket _b(String key, String label) => _Bucket(key, label);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Kolom-kolom yang ditampilkan sesuai periode terpilih.
  /// Harian dibatasi 5 hari (v1.2.1, permintaan pemilik) agar label
  /// tanggal di bawah diagram tidak berdempetan.
  static List<_Bucket> _bucketsFor(ReportPeriod p) {
    final now = DateTime.now();
    if (p == ReportPeriod.daily) {
      return [
        for (var i = 4; i >= 0; i--)
          _b(_iso(now.subtract(Duration(days: i))),
              '${now.subtract(Duration(days: i)).day}/${now.subtract(Duration(days: i)).month}'),
      ];
    }
    if (p == ReportPeriod.monthly) {
      const bln = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return [
        for (var m = 1; m <= 12; m++)
          _b('${now.year}-${m.toString().padLeft(2, '0')}', bln[m - 1]),
      ];
    }
    // Tahunan: 5 tahun terakhir (tahun ini paling kanan).
    return [
      for (var y = now.year - 4; y <= now.year; y++) _b('$y', '$y'),
    ];
  }

  /// Jumlahkan peta harian berdasarkan prefix kunci kolom.
  static double _sum(Map<String, double> map, String key) {
    var t = 0.0;
    map.forEach((k, v) {
      if (k.startsWith(key)) t += v;
    });
    return t;
  }

  /// Kunci "periode terpilih" untuk kartu ringkasan.
  static String _selectedKey(ReportPeriod p) {
    final now = DateTime.now();
    if (p == ReportPeriod.daily) return _iso(now);
    if (p == ReportPeriod.yearly) return '${now.year}';
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String _selectedLabel(ReportPeriod p) => switch (p) {
        ReportPeriod.daily => 'Hari Ini',
        ReportPeriod.yearly => 'Tahun Ini',
        _ => 'Bulan Ini',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(finalReportProvider);
    final notifier = ref.read(finalReportProvider.notifier);

    // Bila pengeluaran berubah di HP ini, hitung ulang laporan.
    ref.listen<int>(
        dataVersionProvider, (_, __) => notifier.loadLocal());

    final buckets = _bucketsFor(state.period);
    final selKey = _selectedKey(state.period);
    final income = _sum(state.incomeByDay, selKey);
    final expense = _sum(state.expenseByDay, selKey);
    final laba = income - expense;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: notifier.pullIncome,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            // --- Judul + tombol segarkan ---
            Row(
              children: [
                Expanded(
                  child: Text('Laporan Akhir',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Segarkan pemasukan dari aplikasi kasir',
                  onPressed:
                      state.refreshing ? null : notifier.pullIncome,
                  icon: state.refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const RealtimeClock(),
            const SizedBox(height: 2),
            Text(
              'Laba Bersih = Pemasukan − Pengeluaran',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, fontSize: 11),
            ),
            const SizedBox(height: 10),

            // --- Pemilih periode ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in [
                    ReportPeriod.daily,
                    ReportPeriod.monthly,
                    ReportPeriod.yearly
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: state.period == p,
                        onSelected: (_) => notifier.setPeriod(p),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // --- Banner info (bila perlu tindakan / offline) ---
            if (state.banner != FinalBanner.none)
              _banner(theme, state),
            const SizedBox(height: 8),

            // --- Kartu ringkasan periode terpilih ---
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ringkasan ${_selectedLabel(state.period)}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedLabel(state.period),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _metricRow(theme,
                        title: 'Pemasukan',
                        subtitle: 'Penjualan dari aplikasi kasir',
                        value: income,
                        icon: Icons.south_west_rounded,
                        color: AppColors.primary),
                    const SizedBox(height: 6),
                    _metricRow(theme,
                        title: 'Pengeluaran',
                        subtitle: 'Catatan di aplikasi ini',
                        value: expense,
                        icon: Icons.north_east_rounded,
                        color: AppColors.danger),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    _metricRow(theme,
                        title: 'Laba Bersih',
                        subtitle: laba >= 0
                            ? 'Untung ${state.period.label.toLowerCase()} ini'
                            : 'Rugi ${state.period.label.toLowerCase()} ini',
                        value: laba.abs(),
                        icon: Icons.savings_rounded,
                        color: laba >= 0
                            ? AppColors.info
                            : AppColors.danger,
                        big: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- Diagram perbandingan ---
            _chartCard(theme, state, buckets),
            const SizedBox(height: 12),

            // --- Tabel rincian ---
            _detailCard(theme, state, buckets),
            const SizedBox(height: 10),

            Text(
              'Pemasukan = penjualan aplikasi kasir (void tak dihitung). '
              'Tarik layar untuk memperbarui.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Potongan widget
  // ------------------------------------------------------------------

  Widget _banner(ThemeData theme, FinalReportState state) {
    final needsSql = state.banner == FinalBanner.needsSql;
    final (icon, text) = needsSql
        ? (
            Icons.build_circle_outlined,
            'Pemasukan belum aktif: jalankan file SQL-LAPORAN-AKHIR '
                'sekali di dashboard Supabase (SQL Editor → Run), '
                'lalu tekan ikon segarkan di atas.'
          )
        : (
            Icons.cloud_off_outlined,
            'Belum terhubung ke cloud — angka pemasukan memakai yang '
                'terakhir tersimpan${state.incomeUpdatedAt == null ? '' : ' (${state.incomeUpdatedAt!.length >= 10 ? state.incomeUpdatedAt!.substring(0, 10) : state.incomeUpdatedAt!})'}. '
                'Sudah online? Tekan ikon segarkan di atas.'
          );

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  /// Satu baris angka pada kartu ringkasan.
  Widget _metricRow(ThemeData theme,
      {required String title,
      required String subtitle,
      required double value,
      required IconData icon,
      required Color color,
      bool big = false}) {
    return Row(
      children: [
        Container(
          width: big ? 42 : 38,
          height: big ? 42 : 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: big ? 24 : 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          big ? FontWeight.w800 : FontWeight.w600)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor, fontSize: 11)),
            ],
          ),
        ),
        Text(
          Formatters.currency(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: big ? 19 : 15,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(ThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.hintColor, fontSize: 11)),
      ],
    );
  }

  /// Diagram batang 3 seri: Pemasukan (hijau), Pengeluaran (merah),
  /// Laba Bersih (biru) per kolom waktu.
  Widget _chartCard(
      ThemeData theme, FinalReportState state, List<_Bucket> buckets) {
    final groups = <_BucketValues>[
      for (final b in buckets)
        _BucketValues(_sum(state.incomeByDay, b.key),
            _sum(state.expenseByDay, b.key)),
    ];
    final hasData = groups.any((g) => g.income > 0 || g.expense > 0);
    var maxY = 0.0;
    for (final g in groups) {
      for (final v in [g.income, g.expense, g.laba.abs()]) {
        if (v > maxY) maxY = v;
      }
    }
    maxY = maxY * 1.25;
    final labelStep = (buckets.length / 7).ceil();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagram ${state.period.label}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(theme, AppColors.primary, 'Pemasukan'),
                const SizedBox(width: 14),
                _legendDot(theme, AppColors.danger, 'Pengeluaran'),
                const SizedBox(width: 14),
                _legendDot(theme, AppColors.info, 'Laba Bersih'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: !hasData
                  ? const EmptyState(
                      icon: Icons.insert_chart_outlined_rounded,
                      title: 'Belum ada data',
                      message: 'Belum ada pemasukan/pengeluaran '
                          'pada diagram periode ini.',
                    )
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
                              reservedSize: 24,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= buckets.length) {
                                  return const SizedBox.shrink();
                                }
                                if (buckets.length > 8 &&
                                    i % labelStep != 0 &&
                                    i != buckets.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    buckets[i].label,
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
                              const names = [
                                'Pemasukan',
                                'Pengeluaran',
                                'Laba'
                              ];
                              final i = group.x.toInt();
                              final labaNeg = rodIndex == 2 &&
                                  i >= 0 &&
                                  i < groups.length &&
                                  groups[i].laba < 0;
                              return BarTooltipItem(
                                '${names[rodIndex]}\n'
                                '${labaNeg ? '- ' : ''}${Formatters.currency(rod.toY)}',
                                theme.textTheme.bodySmall!.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < groups.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 2,
                              barRods: [
                                for (final (color, value) in [
                                  (AppColors.primary, groups[i].income),
                                  (AppColors.danger, groups[i].expense),
                                  (AppColors.info, groups[i].laba.abs()),
                                ])
                                  BarChartRodData(
                                    toY: value,
                                    width: groups.length > 10 ? 6 : 15,
                                    borderRadius:
                                        BorderRadius.circular(3),
                                    color: color,
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

  /// Tabel rincian per kolom waktu: Masuk | Keluar | Laba.
  Widget _detailCard(
      ThemeData theme, FinalReportState state, List<_Bucket> buckets) {
    Widget cell(String text,
        {bool bold = false, Color? color, bool first = false}) {
      return Expanded(
        flex: first ? 12 : 10,
        child: Text(
          text,
          textAlign: first ? TextAlign.left : TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              cell('Periode', bold: true, first: true),
              cell('Masuk', bold: true, color: AppColors.primary),
              cell('Keluar', bold: true, color: AppColors.danger),
              cell('Laba', bold: true, color: AppColors.info),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            for (final b in buckets)
              Builder(builder: (context) {
                final inc = _sum(state.incomeByDay, b.key);
                final exp = _sum(state.expenseByDay, b.key);
                final lab = inc - exp;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    cell(b.label, first: true),
                    cell(Formatters.compact(inc)),
                    cell(Formatters.compact(exp)),
                    cell('${lab < 0 ? '-' : ''}${Formatters.compact(lab.abs())}',
                        bold: true,
                        color:
                            lab >= 0 ? AppColors.info : AppColors.danger),
                  ]),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _Bucket {
  final String key;
  final String label;
  const _Bucket(this.key, this.label);
}

class _BucketValues {
  final double income;
  final double expense;
  const _BucketValues(this.income, this.expense);
  double get laba => income - expense;
}
