/// Chip indikator Online/Offline — dipasang di samping jam realtime
/// di setiap halaman (gaya sama dengan aplikasi kasir) — v1.0.0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/connectivity_provider.dart';

class OnlineStatusChip extends ConsumerWidget {
  const OnlineStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineStatusProvider).valueOrNull ?? true;
    final color = online ? AppColors.success : AppColors.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            online ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
