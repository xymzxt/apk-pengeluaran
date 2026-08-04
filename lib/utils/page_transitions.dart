/// Transisi halaman yang halus (animasi fade) — SPEC: animasi halus.
library;

import 'package:flutter/material.dart';

/// Membuat route dengan transisi fade (durasi sama seperti kasir:
/// 220 md masuk / 180 md keluar agar terasa responsif).
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
