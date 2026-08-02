const Map<String, String> _paymentCurrencySymbols = {
  'USD': '\$',
  'INR': '₹',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'SGD': 'S\$',
  'JPY': '¥',
  'CNY': '¥',
  'HKD': 'HK\$',
  'NZD': 'NZ\$',
  'CHF': 'CHF ',
  'ZAR': 'R ',
  'SEK': 'SEK ',
  'NOK': 'NOK ',
  'DKK': 'DKK ',
  'MYR': 'RM ',
  'THB': '฿',
  'OTHER': '\$',
};

String formatCurrencyAmount(double amount, String currencyCode) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final symbol = _paymentCurrencySymbols[normalizedCurrency] ?? '$normalizedCurrency ';
  final showWholeOnly = normalizedCurrency == 'JPY';
  final rounded = amount.roundToDouble();
  final formatted = showWholeOnly
      ? amount.round().toString()
      : amount == rounded
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
  return '$symbol$formatted';
}

String planDisplayLabel({
  required String plan,
  required double amount,
  required String currencyCode,
  required double monthlyAmount,
  required double yearlyAmount,
  required double lifetimePlanAmount,
}) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final displayAmount = formatCurrencyAmount(amount, normalizedCurrency);

  switch (plan) {
    case 'Free':
      return 'FREE - ${formatCurrencyAmount(0, normalizedCurrency)}';
    case '7Days':
      return '7 DAYS - $displayAmount';
    case 'Monthly':
      return 'MONTHLY - $displayAmount/month';
    case 'Yearly':
      return 'YEARLY - $displayAmount/year ⭐';
    case 'Lifetime':
      return 'LIFETIME - $displayAmount one-time';
    default:
      return plan.toUpperCase();
  }
}
