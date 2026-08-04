/// Kumpulan validator form (login & form pengeluaran) — v1.0.0.
library;

import 'currency_input.dart';

class Validators {
  Validators._();

  static final RegExp _emailRegex =
      RegExp(r'^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$');

  /// Field wajib diisi.
  static String? required(String? value, [String field = 'Kolom']) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  /// Validasi alamat email.
  static String? email(String? value) {
    final empty = required(value, 'Email');
    if (empty != null) return empty;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Validasi password (minimal 6 karakter).
  static String? password(String? value) {
    final empty = required(value, 'Password');
    if (empty != null) return empty;
    if (value!.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  /// Validasi nominal uang (SPEC: nominal tidak boleh nol).
  /// Menerima format ribuan hasil [CurrencyInputFormatter], mis. "12.500".
  static String? nominal(String? value) {
    final empty = required(value, 'Nominal');
    if (empty != null) return empty;
    final amount = CurrencyInputFormatter.parse(value!);
    if (amount <= 0) return 'Nominal tidak boleh nol';
    return null;
  }
}
