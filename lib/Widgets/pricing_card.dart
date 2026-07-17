import 'package:flutter/material.dart';

class PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final Color color;
  final double? basePrice;
  final int appliedDiscountPercent;

  const PricingCard({
    super.key,
    required this.title,
    required this.price,
    required this.color,
    this.basePrice,
    this.appliedDiscountPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPremium = title.toLowerCase().contains('premium');
    final bool isFreePlan = price.toLowerCase() == 'free';
    final double effectiveBasePrice = basePrice ?? 0;
    final bool hasDiscount = appliedDiscountPercent > 0 && basePrice != null;
    final double discountedPrice = hasDiscount
      ? effectiveBasePrice * (1 - (appliedDiscountPercent / 100))
      : effectiveBasePrice;

    String _formatMoney(double amount) {
      final rounded = amount.roundToDouble();
      if (amount == rounded) {
        return '\$${amount.toStringAsFixed(0)}';
      }
      return '\$${amount.toStringAsFixed(2)}';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPremium
              ? const [Color(0xFFFFFCF2), Color(0xFFFFF3C7)]
              : const [Color(0xFFF8FBFF), Color(0xFFEFF5FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPremium ? const Color(0xFFFFD86B) : const Color(0xFFD6E6FF),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isPremium ? Icons.workspace_premium_rounded : Icons.verified_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremium
                        ? hasDiscount
                            ? 'Coupon applied: $appliedDiscountPercent% off is active for this plan.'
                            : 'Advanced features and premium tools are on the way.'
                      : isFreePlan
                        ? 'Start free with core document tools and fast actions.'
                        : 'Best for regular users who need more usage and smoother workflow.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(effectiveBasePrice),
                      style: const TextStyle(
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                hasDiscount ? _formatMoney(discountedPrice) : price,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
