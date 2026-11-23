import 'package:flutter/material.dart';

/// EchoWP-Farben: Gelb und Schwarz.
const Color echoYellow = Color(0xFFFFD400);
const Color echoBlack = Color(0xFF0A0A0A);

/// Hell: schwarze Kopfleiste mit gelber Schrift, schwarze Akzente (nie Gelb auf Weiß).
ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: echoYellow, brightness: Brightness.light).copyWith(
    primary: echoBlack,
    onPrimary: echoYellow,
    secondary: echoYellow,
    onSecondary: echoBlack,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(backgroundColor: echoBlack, foregroundColor: echoYellow),
    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(backgroundColor: echoYellow, foregroundColor: echoBlack),
    navigationBarTheme: const NavigationBarThemeData(indicatorColor: echoYellow),
  );
}

/// Dunkel: Gelb auf Schwarz.
ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: echoYellow, brightness: Brightness.dark).copyWith(
    primary: echoYellow,
    onPrimary: echoBlack,
    secondary: echoYellow,
    onSecondary: echoBlack,
    surface: const Color(0xFF141414),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: echoBlack,
    appBarTheme: const AppBarTheme(backgroundColor: echoBlack, foregroundColor: echoYellow),
    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(backgroundColor: echoYellow, foregroundColor: echoBlack),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: echoYellow,
      backgroundColor: Color(0xFF141414),
    ),
  );
}
