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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(colorScheme.surface),
        overlayColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.pressed)
              ? colorScheme.primary
              : states.intersection({MaterialState.focused, MaterialState.hovered}).isNotEmpty
                  ? colorScheme.background
                  : colorScheme.surface,
        ),
        elevation: MaterialStateProperty.resolveWith(
          (states) => states.intersection({MaterialState.pressed}).isNotEmpty ? 0 : 2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      isCollapsed: true,
      contentPadding: EdgeInsets.all(10),
      fillColor: colorScheme.background,
      border: InputBorder.none,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 0.0,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      elevation: 1,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
    ),
  );
}
