import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

ColorScheme customColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
ColorScheme customDarkColorScheme =
    ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark);

class CustomTheme {
  final ThemeData light;
  final ThemeData dark;

  CustomTheme({required this.light, required this.dark});
}

CustomTheme getTheme({
  required BuildContext context,
  required ColorScheme? lightDynamic,
  required ColorScheme? darkDynamic,
}) {
  ColorScheme colorScheme =
      lightDynamic != null ? lightDynamic.harmonized() : customColorScheme;
  ColorScheme darkColorScheme =
      darkDynamic != null ? darkDynamic.harmonized() : customDarkColorScheme;

  final lightTheme = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
  );

  final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: darkColorScheme,
  );

  return CustomTheme(light: lightTheme, dark: darkTheme);
}
