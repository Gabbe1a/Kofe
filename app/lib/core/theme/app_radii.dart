import 'package:flutter/material.dart';

abstract final class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF191919).withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Aura Source 1 radii: compact cards, large sheets, circular controls.
abstract final class AppRadii {
  static const sm = 9.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const add = 999.0;
  static const pill = 999.0;
}
