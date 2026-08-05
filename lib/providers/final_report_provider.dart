/// Provider Laporan Akhir (v1.1.0, permintaan pemilik).
///
/// Menggabungkan data DUA aplikasi Toko Rejeki:
/// - PEMASUKAN  : total penjualan harian dari aplikasi KASIR, ditarik
///   dari Supabase lewat fungsi get_daily_income() (dipasang sekali
///   lewat SQL-LAPORAN-AKHIR.sql) lalu dicache di SQLite
///   (tabel income_daily) supaya tetap kebaca saat offline.
/// - PENGELUARAN: data SQLite lokal (selalu tersedia).
///
///   LABA BERSIH = PEMASUKAN - PENGELUARAN   (per hari/bulan/tahun)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../database/expense_repository.dart';
import '../services/supabase_service.dart';
import '../utils/period.dart';

/// Alasan banner info kecil di layar Laporan Akhir.
enum FinalBanner {
  none, // pemasukan segar dari cloud
  offline, // tak terhubung cloud -> memakai data terakhir tersimpan
  needsSql, // fungsi get_daily_income belum dipasang di Supabase
}

class FinalReportState {
  final ReportPeriod period; // dipakai: Harian / Bulanan / Tahunan

  /// Tanggal acuan laporan (v1.2.2, permintaan pemilik): bisa digeser
  /// ‹ › atau dipilih dari kalender — sama seperti tab Pengeluaran.
  final DateTime anchor;
  final bool refreshing;
  final FinalBanner banner;
  final Map<String, double> incomeByDay; // 'yyyy-MM-dd' -> total
  final Map<String, double> expenseByDay; // 'yyyy-MM-dd' -> total
  final String? incomeUpdatedAt; // capaian ISO tarik terakhir

  FinalReportState({
    this.period = ReportPeriod.daily,
    DateTime? anchor,
    this.refreshing = false,
    this.banner = FinalBanner.none,
    this.incomeByDay = const {},
    this.expenseByDay = const {},
    this.incomeUpdatedAt,
  }) : anchor = anchor ?? DateTime.now();

  FinalReportState copyWith({
    ReportPeriod? period,
    DateTime? anchor,
    bool? refreshing,
    FinalBanner? banner,
    Map<String, double>? incomeByDay,
    Map<String, double>? expenseByDay,
    String? incomeUpdatedAt,
  }) {
    return FinalReportState(
      period: period ?? this.period,
      anchor: anchor ?? this.anchor,
      refreshing: refreshing ?? this.refreshing,
      banner: banner ?? this.banner,
      incomeByDay: incomeByDay ?? this.incomeByDay,
      expenseByDay: expenseByDay ?? this.expenseByDay,
      incomeUpdatedAt: incomeUpdatedAt ?? this.incomeUpdatedAt,
    );
  }
}

class FinalReportController extends StateNotifier<FinalReportState> {
  FinalReportController() : super(FinalReportState()) {
    // Tampilkan cache lokal seketika, lalu segarkan dari cloud.
    loadLocal();
    pullIncome();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void setPeriod(ReportPeriod p) => state = state.copyWith(period: p);

  /// Geser tanggal acuan ke depan/belakang sesuai periode (panah
  /// ‹ › di layar), seperti tab Pengeluaran & aplikasi kasir.
  void shift(int step) {
    final a = state.anchor;
    final next = switch (state.period) {
      ReportPeriod.daily => DateTime(a.year, a.month, a.day + step),
      ReportPeriod.yearly => DateTime(a.year + step),
      _ => DateTime(a.year, a.month + step),
    };
    state = state.copyWith(anchor: next);
  }

  /// Lompat ke tanggal pilihan dari kalender (5 tahun ke belakang
  /// s.d. 6 tahun ke depan — permintaan pemilik).
  void jumpTo(DateTime date) => state = state.copyWith(anchor: date);

  /// Baca ulang data tersimpan (juga dipanggil dari layar Laporan
  /// setiap kali transaksi pengeluaran berubah).
  Future<void> loadLocal() async {
    final repo = ExpenseRepository.instance;
    final now = DateTime.now();
    final from = DateTime(now.year - 4, 1, 1);
    final income = await repo.incomeDailyMap(_isoDate(from), _isoDate(now));
    final expense = await repo.dailyTotals(
      DateRange(from, now.add(const Duration(days: 1))),
    );
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      incomeByDay: income,
      expenseByDay: expense,
      incomeUpdatedAt: prefs.getString(AppConstants.prefLastIncomePull),
    );
  }

  /// Tarik total pemasukan harian dari tabel penjualan aplikasi kasir.
  Future<void> pullIncome() async {
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      final svc = SupabaseService.instance;
      if (!await svc.ensureCloudSignIn()) {
        state = state.copyWith(banner: FinalBanner.offline);
        return;
      }
      final now = DateTime.now();
      final from = DateTime(now.year - 4, 1, 1);
      final rows = await svc.fetchDailyIncome(_isoDate(from), _isoDate(now));
      await ExpenseRepository.instance.upsertIncomeDays(rows);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.prefLastIncomePull, now.toIso8601String());
      state = state.copyWith(banner: FinalBanner.none);
      await loadLocal();
    } catch (e) {
      // Fungsi SQL belum dipasang -> pandu jalankan SQL-LAPORAN-AKHIR;
      // selain itu (offline dsb.) -> tetap tampilkan data tersimpan.
      final msg = e.toString().toLowerCase();
      state = state.copyWith(
        banner: msg.contains('get_daily_income')
            ? FinalBanner.needsSql
            : FinalBanner.offline,
      );
    } finally {
      state = state.copyWith(refreshing: false);
    }
  }
}

final finalReportProvider =
    StateNotifierProvider<FinalReportController, FinalReportState>(
  (ref) => FinalReportController(),
);
