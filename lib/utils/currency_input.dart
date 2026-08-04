/// Input formatter uang Rupiah: ketik 12500 -> tampil "12.500" (v1.0.0,
/// sama persis dengan milik aplikasi kasir — format Rupiah otomatis
/// sesuai SPEC-PENGELUARAN.md).
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'id_ID');

  /// 12500 -> "12.500"
  static String format(num value) => _formatter.format(value);

  /// "12.500" -> 12500
  static double parse(String text) {
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.parse(digits);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = _formatter.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
