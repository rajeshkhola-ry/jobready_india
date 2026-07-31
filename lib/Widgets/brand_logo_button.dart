import 'package:flutter/material.dart';

import 'glowing_logo_badge.dart';

class BrandLogoButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  const BrandLogoButton({
    super.key,
    this.size = 32,
    this.onTap,
    this.padding = const EdgeInsets.all(4),
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Padding(
      padding: padding,
      child: GlowingLogoBadge(size: size, circular: true),
    );

    final content = onTap == null
        ? badge
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size * 0.35),
            child: badge,
          );

    if (tooltip == null || tooltip!.isEmpty) {
      return content;
    }

    return Tooltip(message: tooltip!, child: content);
  }
}
