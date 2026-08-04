/// Provider tema Dark / Light (SPEC: Dark Mode dan Light Mode) —
/// v1.0.0, sama persis dengan aplikasi kasir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  final controller = ThemeModeController();
  controller.load();
  return controller;
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);

  /// Memuat preferensi tema yang tersimpan.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConstants.prefThemeMode);
      state = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Abaikan kegagalan membaca preferensi; tetap pakai tema sistem.
    }
  }

  /// Toggle cepat dark <-> light.
  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  /// Mengganti tema lalu menyimpan preferensinya.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.prefThemeMode,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {
      // Preferensi gagal tersimpan bukan masalah fatal.
    }
  }
}
