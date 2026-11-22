import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFF155EEF);
const Color kIncome = Color(0xFF12B76A);
const Color kExpense = Color(0xFFF04438);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: b).copyWith(primary: kPrimary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FC),
    cardTheme: CardTheme(
      color: dark ? const Color(0xFF131C2E) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF101828)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF131C2E) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF131C2E) : Colors.white,
      indicatorColor: kPrimary.withOpacity(0.12),
    ),
  );
}

/// Soft card shadow used by the dashboard cards.
List<BoxShadow> softShadow(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const []
    : [BoxShadow(color: const Color(0xFF155EEF).withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))];
