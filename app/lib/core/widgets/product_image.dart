import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight product photo. Prefer cutout PNGs (RGBA) from assets.
/// No ColorFiltered — it lagged on scroll grids.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  final String asset;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(asset);
    final isNetwork = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    final fallback = Icon(
      Icons.local_cafe,
      size: (height ?? width ?? 64) * 0.4,
      color: context.kofePalette.ink,
    );
    if (isNetwork) {
      return Image.network(
        asset,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
