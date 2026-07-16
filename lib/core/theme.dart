import 'package:flutter/material.dart';

/// Single source of truth for app theming.
const Color kSeedColor = Color(0xFF7C4DFF);

ThemeData buildTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: kSeedColor,
      brightness: brightness,
    );
