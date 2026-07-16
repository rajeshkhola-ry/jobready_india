import 'package:flutter/material.dart';

class GlowingLogoBadge extends StatefulWidget {
  final double size;
  final bool circular;

  const GlowingLogoBadge({
    super.key,
    this.size = 38,
    this.circular = true,
  });

  @override
  State<GlowingLogoBadge> createState() => _GlowingLogoBadgeState();
}

class _GlowingLogoBadgeState extends State<GlowingLogoBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final blueOpacity = 0.48 + (0.34 * t);
        final yellowOpacity = 0.48 + (0.34 * (1 - t));
        final blur = 13.0 + (10.0 * t);
        final spread = 1.8 + (1.4 * t);

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.circular ? null : BorderRadius.circular(widget.size * 0.22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withOpacity(blueOpacity),
                blurRadius: blur,
                spreadRadius: spread,
                offset: const Offset(-2, -2),
              ),
              BoxShadow(
                color: const Color(0xFFFFC72C).withOpacity(yellowOpacity),
                blurRadius: blur,
                spreadRadius: spread,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                color: const Color(0xFFC28A00),
                fontSize: widget.size * 0.58,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
