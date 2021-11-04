import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        mouseCursor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled) ? SystemMouseCursors.basic : null,
        ),
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
      contentPadding: const EdgeInsets.all(10),
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
    chipTheme: ThemeData().chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.zero,
        ),
  );
}
