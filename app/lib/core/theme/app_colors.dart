import 'package:flutter/material.dart';

/// Aura / Source 1 colour primitives for «Кофе Мама».
///
/// These constants retain compatibility with legacy widgets. New or redesigned
/// widgets must read the contextual [KofePalette] to honour dark mode.
abstract final class AppColors {
  static const primary = Color(0xFF191919);
  static const primarySoft = Color(0xFFD7B78B);
  static const ink = Color(0xFF191919);
  static const inkMuted = Color(0xFF777777);
  static const border = Color(0xFFE3E3E3);
  static const searchFill = Color(0xFFEDEDED);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF4F4F4);
  static const accentOrange = Color(0xFFD7B78B);
  static const danger = Color(0xFFC85A55);

  // Legacy names retained while individual screens move to KofePalette.
  static const forest = primary;
  static const forestDeep = primary;
  static const emerald = primary;
  static const sage = Color(0xFFD7B78B);
  static const sageSoft = Color(0xFFF0E5D2);
  static const cream = canvas;
  static const creamWarm = searchFill;
  static const caramel = accentOrange;
  static const caramelDeep = Color(0xFFA78457);
  static const onForest = Color(0xFFFFFFFF);
}

@immutable
class KofePalette extends ThemeExtension<KofePalette> {
  const KofePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.action,
    required this.onAction,
    required this.imageBackdrop,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color action;
  final Color onAction;
  final Color imageBackdrop;

  static const light = KofePalette(
    canvas: Color(0xFFF4F4F4),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDEDED),
    ink: Color(0xFF191919),
    inkMuted: Color(0xFF777777),
    line: Color(0xFFE3E3E3),
    accent: Color(0xFFD7B78B),
    onAccent: Color(0xFF191919),
    action: Color(0xFF191919),
    onAction: Color(0xFFFFFFFF),
    imageBackdrop: Color(0xFFE7DED1),
  );

  static const dark = KofePalette(
    canvas: Color(0xFF191919),
    surface: Color(0xFF262626),
    surfaceMuted: Color(0xFF303030),
    ink: Color(0xFFF4F4F4),
    inkMuted: Color(0xFFA8A8A8),
    line: Color(0xFF414141),
    accent: Color(0xFFD7B78B),
    onAccent: Color(0xFF191919),
    action: Color(0xFFF4F4F4),
    onAction: Color(0xFF191919),
    imageBackdrop: Color(0xFF303030),
  );

  @override
  KofePalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? action,
    Color? onAction,
    Color? imageBackdrop,
  }) => KofePalette(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    action: action ?? this.action,
    onAction: onAction ?? this.onAction,
    imageBackdrop: imageBackdrop ?? this.imageBackdrop,
  );

  @override
  KofePalette lerp(covariant ThemeExtension<KofePalette>? other, double t) {
    if (other is! KofePalette) return this;
    return KofePalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      imageBackdrop: Color.lerp(imageBackdrop, other.imageBackdrop, t)!,
    );
  }
}

extension KofeThemeContext on BuildContext {
  KofePalette get kofePalette =>
      Theme.of(this).extension<KofePalette>() ?? KofePalette.light;
}
