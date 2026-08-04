/// Provider status koneksi — indikator Online/Offline di samping jam
/// realtime (gaya sama dengan aplikasi kasir) — v1.0.0.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` jika perangkat memiliki koneksi jaringan apa pun.
final onlineStatusProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});
