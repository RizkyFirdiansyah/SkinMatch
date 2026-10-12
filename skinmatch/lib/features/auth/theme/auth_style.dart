import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warna khusus fitur auth (sama persis dengan versi pertama).
abstract class AuthColors {
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryEnd = Color(0xFF40916C); // ujung gradasi tombol
  static const Color background = Color(0xFFF8F6F0);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1F2A24);
  static const Color textGrey = Color(0xFF6B7770);
  static const Color border = Color(0xFFE3E6E1);
  static const Color danger = Color(0xFFD32F2F);

  static const Color tabTrack = Color(0xFFE9ECE6);
  static const Color blobTop = Color(0xFFBFE3CE);
  static const Color blobBottom = Color(0xFFD8EFE0);

  static const Color strengthMedium = Color(0xFFF2A33A);
  static const Color strengthGood = Color(0xFF74B98F);
}

/// Tema khusus fitur auth (font Plus Jakarta Sans di semua tulisan).
/// Dipasang lewat widget Theme di AuthBackground.
abstract class AuthTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AuthColors.primary,
      primary: AuthColors.primary,
    ),
    scaffoldBackgroundColor: AuthColors.background,
    textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: AuthColors.textDark,
      displayColor: AuthColors.textDark,
    ),
  );
}