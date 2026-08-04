/// Navigasi utama — pil "kaca" melayang (gaya sama persis dengan
/// aplikasi kasir) dengan tombol "+" besar di tengah untuk Tambah
/// Pengeluaran. Tab: Beranda | Riwayat | (+) | Laporan | Pengaturan.
/// — v1.0.0.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expense_form_screen.dart';
import 'expenses/expense_history_screen.dart';
import 'reports/report_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  /// Index tab awal (dipakai detail page untuk "kembali ke Riwayat").
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _index = widget.initialIndex;

  static const _pages = [
    DashboardScreen(),
    ExpenseHistoryScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardFill(isDark),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.cardBorder(isDark)),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow(isDark),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Beranda', theme),
              _navItem(1, Icons.receipt_long_rounded, 'Riwayat', theme),
              _addButton(theme),
              _navItem(2, Icons.insert_chart_outlined_rounded, 'Laporan',
                  theme),
              _navItem(3, Icons.settings_rounded, 'Pengaturan', theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, ThemeData theme) {
    final selected = _index == index;
    final color =
        selected ? theme.colorScheme.primary : theme.hintColor;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol "+" besar — membuka form Tambah Pengeluaran.
  Widget _addButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: theme.colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.45),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const ExpenseFormScreen(),
              ),
            );
            if (saved == true && mounted) setState(() {});
          },
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
