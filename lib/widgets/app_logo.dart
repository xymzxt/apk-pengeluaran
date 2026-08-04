/// Logo aplikasi dari asset (assets/logo/) — v1.0.0.
///
/// Disiapkan sebagai widget terpisah supaya splash, login, dan
/// kartu Tentang memakai logo yang sama.
library;

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/logo/pengeluaran.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Cadangan bila asset belum ada: ikon dompet hijau.
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Icon(Icons.account_balance_wallet_rounded,
              size: size * 0.55, color: Colors.white),
        ),
      ),
    );
  }
}
