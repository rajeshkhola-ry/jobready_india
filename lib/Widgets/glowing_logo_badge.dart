import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GlowingLogoBadge extends StatelessWidget {
  final double size;
  final bool circular;

  const GlowingLogoBadge({
    super.key,
    this.size = 38,
    this.circular = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: SvgPicture.asset(
          'lib/public/assets/logo-gold-transparent.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
