import 'package:flutter/material.dart';

ThemeData theme(MaterialColor swatch, Brightness brightness) {
  final colorScheme = ColorScheme.fromSwatch(primarySwatch: swatch, brightness: brightness);

  return ThemeData(
    brightness: brightness,
    primarySwatch: swatch,
    primaryTextTheme: TextTheme(
      headline6: TextStyle(color: colorScheme.onSurface),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      elevation: 2.0,
    ),
  );
}
