import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

abstract final class KofeLayout {
  static const pageInset = 20.0;
  static const pageHorizontal = EdgeInsets.symmetric(horizontal: pageInset);
  static const pageSafeArea = EdgeInsets.symmetric(horizontal: pageInset);
}

class KofeSurface extends StatelessWidget {
  const KofeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = AppRadii.md,
    this.onTap,
    this.borderColor,
    this.margin,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: _resolvedColor(palette),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }

  Color _resolvedColor(KofePalette palette) {
    if (color == null || color == AppColors.surface) return palette.surface;
    if (color == AppColors.canvas || color == AppColors.cream) return palette.canvas;
    if (color == AppColors.searchFill || color == AppColors.creamWarm) {
      return palette.surfaceMuted;
    }
    if (color == AppColors.forest || color == AppColors.forestDeep) return palette.ink;
    if (color == AppColors.sageSoft) return palette.surfaceMuted;
    return color!;
  }
}

class KofeSectionTitle extends StatelessWidget {
  const KofeSectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.ink),
          ),
        ),
        if (action != null)
          DefaultTextStyle.merge(
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 14),
            child: action!,
          ),
      ],
    );
  }
}

class KofeRoundIcon extends StatelessWidget {
  const KofeRoundIcon({
    super.key,
    required this.icon,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _resolvedFill(palette),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: _resolvedIcon(palette), size: 20),
    );
  }

  Color _resolvedFill(KofePalette palette) {
    if (color == null) return palette.surfaceMuted;
    if (color == AppColors.sageSoft || color == AppColors.creamWarm) return palette.surfaceMuted;
    if (color == AppColors.forest || color == AppColors.forestDeep) return palette.ink;
    if (color == AppColors.surface) return palette.surface;
    return color!;
  }

  Color _resolvedIcon(KofePalette palette) {
    if (iconColor == null || iconColor == AppColors.ink || iconColor == AppColors.forest || iconColor == AppColors.forestDeep) {
      return palette.ink;
    }
    if (iconColor == AppColors.cream || iconColor == AppColors.onForest) return palette.canvas;
    return iconColor!;
  }
}

class KofeAddButton extends StatelessWidget {
  const KofeAddButton({super.key, this.onTap, this.size = 42});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: palette.action,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.add_rounded, color: palette.onAction, size: 22),
        ),
      ),
    );
  }
}

class KofeQuantityControl extends StatelessWidget {
  const KofeQuantityControl({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
  });

  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final size = compact ? 30.0 : 38.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _round(context, Icons.remove_rounded, onMinus, size, palette.surfaceMuted, palette.ink),
        SizedBox(
          width: compact ? 28 : 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.w800),
          ),
        ),
        _round(context, Icons.add_rounded, onPlus, size, palette.action, palette.onAction),
      ],
    );
  }

  Widget _round(BuildContext context, IconData icon, VoidCallback onTap, double size, Color fill, Color iconColor) =>
      Material(
        color: fill,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: size, height: size, child: Icon(icon, color: iconColor, size: 18)),
        ),
      );
}
