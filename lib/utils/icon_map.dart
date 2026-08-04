/// Peta ikon & warna kategori (v1.0.0).
///
/// Ikon disimpan sebagai STRING di database (kolom `icon`) agar aman
/// disinkronkan ke Supabase; di sini dipetakan kembali ke IconData.
/// Palet warna ("neo apple colorful") tersedia di AppColors.
library;

import 'package:flutter/material.dart';

/// Entri ikon: kunci string -> ikon Material rounded.
class IconMap {
  IconMap._();

  static const Map<String, IconData> icons = {
    'belanja': Icons.shopping_bag_outlined,
    'stok': Icons.inventory_2_outlined,
    'makan': Icons.restaurant_outlined,
    'minum': Icons.local_cafe_outlined,
    'listrik': Icons.electric_bolt_outlined,
    'air': Icons.water_drop_outlined,
    'internet': Icons.wifi_rounded,
    'transport': Icons.directions_car_outlined,
    'bensin': Icons.local_gas_station_outlined,
    'gaji': Icons.payments_outlined,
    'sewa': Icons.home_work_outlined,
    'kesehatan': Icons.medical_services_outlined,
    'pendidikan': Icons.school_outlined,
    'pulsa': Icons.smartphone_outlined,
    'peralatan': Icons.build_outlined,
    'kemasan': Icons.takeout_dining_outlined,
    'pajak': Icons.receipt_long_outlined,
    'donasi': Icons.volunteer_activism_outlined,
    'hiburan': Icons.movie_outlined,
    'lainnya': Icons.more_horiz_rounded,
  };

  /// Ikon untuk kunci [key]; fallback ikon "lainnya" bila tak dikenal.
  static IconData of(String? key) => icons[key] ?? Icons.more_horiz_rounded;

  /// Daftar kunci ikon untuk grid pemilih ikon di dialog kategori.
  static List<String> get keys => icons.keys.toList();

  /// Mengubah string warna '#RRGGBB' menjadi [Color].
  static Color colorFromHex(String? hex, {Color fallback = Colors.green}) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }

  /// Mengubah [Color] menjadi '#RRGGBB' untuk disimpan di database.
  static String hexFromColor(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
