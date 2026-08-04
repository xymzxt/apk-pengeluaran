/// Widget jam realtime — tampil di bagian atas setiap halaman dan
/// diperbarui tiap detik, PERSIS seperti aplikasi kasir (termasuk
/// format tanggal adaptif untuk layar sempit, pelajaran dari v1.5.9
/// kasir di HP mungil).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'online_status_chip.dart';

class RealtimeClock extends ConsumerStatefulWidget {
  /// Jika `true`, jam dibungkus Card (dipakai di halaman utama).
  final bool showContainer;

  /// Jika `true`, tampilkan chip Online/Offline di samping jam.
  final bool showOnlineStatus;

  const RealtimeClock({
    super.key,
    this.showContainer = true,
    this.showOnlineStatus = true,
  });

  @override
  ConsumerState<RealtimeClock> createState() => _RealtimeClockState();
}

class _RealtimeClockState extends ConsumerState<RealtimeClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = DateFormat('HH:mm:ss').format(_now);
    // Adaptif lebar layar (pelajaran dari kasir): layar sempit ->
    // format tanggal dipendekkan supaya tidak meluber/terpotong.
    final lebarLayar = MediaQuery.sizeOf(context).width;
    final dateText = lebarLayar < 380
        ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_now)
        : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);

    final content = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.schedule_rounded,
              color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                dateText,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (widget.showOnlineStatus) ...[
          const SizedBox(width: 10),
          const OnlineStatusChip(),
        ],
      ],
    );

    if (!widget.showContainer) return content;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: content,
      ),
    );
  }
}
