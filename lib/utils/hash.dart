/// Hash SHA-256 untuk sandi owner lokal (v1.0.1, login gaya kasir,
/// permintaan pemilik) — sandi tidak pernah disimpan polos.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

class AppHash {
  AppHash._();

  /// Hash teks -> hex SHA-256.
  static String of(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  /// Verifikasi teks terhadap hash tersimpan.
  static bool verify(String text, String hash) => of(text) == hash;
}
