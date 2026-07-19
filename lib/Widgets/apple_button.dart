import 'package:flutter/material.dart';

/// Apple-style button component (iOS/macBook design aesthetic)
class AppleButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final bool isPrimary;
  final double height;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isPrimary = true,
    this.height = 48,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<AppleButton> createState() => _AppleButtonState();
}

class _AppleButtonState extends State<AppleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;

    // Apple color palette
    final primaryBg = widget.backgroundColor ??
        (widget.isPrimary
        ? const Color(0xFF0E3A66) // JOBREADY Professional Navy
            : Colors.transparent);

    final primaryFg = widget.foregroundColor ??
      (widget.isPrimary ? Colors.white : const Color(0xFF0E3A66));

    final secondaryBg =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: widget.height,
        width: widget.isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: isEnabled
              ? (widget.isPrimary ? primaryBg : secondaryBg)
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12), // iOS standard radius
          boxShadow: [
            if (widget.isPrimary && isEnabled)
              BoxShadow(
                color: const Color(0xFF0E3A66).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: isEnabled ? _onTapDown : null,
            onTapUp: isEnabled ? _onTapUp : null,
            onTapCancel: isEnabled ? _onTapCancel : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: widget.padding ??
                  EdgeInsets.symmetric(
                    horizontal: widget.isFullWidth ? 14 : 20,
                  ),
              child: Row(
                mainAxisSize:
                    widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: isEnabled ? primaryFg : Colors.grey.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isEnabled ? primaryFg : Colors.grey.shade600,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple Segmented Button (for tool selection)
class AppleSegmentedButton extends StatefulWidget {
  final List<String> options;
  final Function(int) onChanged;
  final int selectedIndex;

  const AppleSegmentedButton({
    super.key,
    required this.options,
    required this.onChanged,
    this.selectedIndex = 0,
  });

  @override
  State<AppleSegmentedButton> createState() => _AppleSegmentedButtonState();
}

class _AppleSegmentedButtonState extends State<AppleSegmentedButton> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(
          widget.options.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onChanged(index);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedIndex == index
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedIndex == index
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.options[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedIndex == index
                      ? const Color(0xFF0E3A66)
                        : Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple Icon Button (Compact tool buttons)
class AppleIconButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const AppleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  State<AppleIconButton> createState() => _AppleIconButtonState();
}

class _AppleIconButtonState extends State<AppleIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.92)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color ?? const Color(0xFF0051BA),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
