import 'package:flutter/material.dart';

ThemeData theme(MaterialColor swatch, Brightness brightness) {
  final colorScheme = ColorScheme.fromSwatch(primarySwatch: swatch, brightness: brightness);

  return ThemeData(
    brightness: brightness,
    primarySwatch: swatch,
    primaryTextTheme: TextTheme(
      headline6: TextStyle(color: colorScheme.onSurface),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all(colorScheme.onSurface),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(border: InputBorder.none),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      elevation: 2.0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
    ),
  );
}
