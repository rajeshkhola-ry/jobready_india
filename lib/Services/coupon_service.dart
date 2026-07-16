import 'dart:math';

class CouponData {
  final String code;
  final int discountPercent;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int maxUses;
  int usedCount;

  CouponData({
    required this.code,
    required this.discountPercent,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses = 1,
    this.usedCount = 0,
  });

  bool get isUsedUp => usedCount >= maxUses;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isActive => !isUsedUp && !isExpired;

  String get statusLabel {
    if (isUsedUp) return 'Used';
    if (isExpired) return 'Expired';
    return 'Active';
  }
}

class CouponValidationResult {
  final bool valid;
  final String message;
  final int discountPercent;

  const CouponValidationResult({
    required this.valid,
    required this.message,
    this.discountPercent = 0,
  });
}

class CouponService {
  static final Map<String, CouponData> _couponStore = {};
  static final Random _random = Random.secure();
  static bool _seededDefaults = false;

  static void _ensureDefaultCoupons() {
    if (_seededDefaults) {
      return;
    }
    _seededDefaults = true;

    final now = DateTime.now();

    _couponStore['JRFREE1001Y'] = CouponData(
      code: 'JRFREE1001Y',
      discountPercent: 100,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 365)),
      maxUses: 999999,
      usedCount: 0,
    );

    _couponStore['JRPREMIUM1001Y'] = CouponData(
      code: 'JRPREMIUM1001Y',
      discountPercent: 100,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 365)),
      maxUses: 999999,
      usedCount: 0,
    );
  }

  static CouponData generateCoupon({
    required int discountPercent,
    Duration? validFor,
  }) {
    _ensureDefaultCoupons();

    if (discountPercent < 1 || discountPercent > 100) {
      throw ArgumentError('Discount must be between 1 and 100 percent');
    }

    final now = DateTime.now();
    final code = _generateCode(discountPercent);

    final coupon = CouponData(
      code: code,
      discountPercent: discountPercent,
      createdAt: now,
      expiresAt: validFor == null ? null : now.add(validFor),
      maxUses: 1,
      usedCount: 0,
    );

    _couponStore[code] = coupon;
    return coupon;
  }

  static CouponData upsertCoupon({
    required String code,
    required int discountPercent,
    Duration? validFor,
    int maxUses = 999999,
  }) {
    _ensureDefaultCoupons();

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Coupon code cannot be empty');
    }
    if (discountPercent < 1 || discountPercent > 100) {
      throw ArgumentError('Discount must be between 1 and 100 percent');
    }

    final now = DateTime.now();
    final coupon = CouponData(
      code: normalizedCode,
      discountPercent: discountPercent,
      createdAt: now,
      expiresAt: validFor == null ? null : now.add(validFor),
      maxUses: maxUses,
      usedCount: 0,
    );

    _couponStore[normalizedCode] = coupon;
    return coupon;
  }

  static List<CouponData> getAllCoupons() {
    _ensureDefaultCoupons();
    final coupons = _couponStore.values.toList();
    coupons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return coupons;
  }

  static CouponValidationResult validateCoupon(String rawCode) {
    _ensureDefaultCoupons();
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return const CouponValidationResult(valid: false, message: 'Enter a coupon code');
    }

    final coupon = _couponStore[code];
    if (coupon == null) {
      return const CouponValidationResult(valid: false, message: 'Coupon not found');
    }

    if (coupon.isUsedUp) {
      return const CouponValidationResult(valid: false, message: 'Coupon already used once');
    }

    if (coupon.isExpired) {
      return const CouponValidationResult(valid: false, message: 'Coupon expired');
    }

    return CouponValidationResult(
      valid: true,
      message: 'Coupon applied: ${coupon.discountPercent}% discount',
      discountPercent: coupon.discountPercent,
    );
  }

  static CouponValidationResult redeemCoupon(String rawCode) {
    _ensureDefaultCoupons();
    final code = rawCode.trim().toUpperCase();
    final validation = validateCoupon(code);
    if (!validation.valid) {
      return validation;
    }

    final coupon = _couponStore[code]!;
    coupon.usedCount += 1;

    return CouponValidationResult(
      valid: true,
      message: 'Coupon redeemed: ${coupon.discountPercent}% discount (one-time used)',
      discountPercent: coupon.discountPercent,
    );
  }

  static String _generateCode(int discountPercent) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      final suffix = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
      code = 'JR${discountPercent}_$suffix';
    } while (_couponStore.containsKey(code));
    return code;
  }
}
