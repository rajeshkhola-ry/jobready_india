class CheckoutFlowUtils {
  static String resolveSelectedCurrency(
    String? selectedCurrency,
    String fallbackCurrency,
  ) {
    final normalizedSelected = (selectedCurrency ?? '').trim().toUpperCase();
    if (normalizedSelected.isNotEmpty) {
      return normalizedSelected;
    }
    return (fallbackCurrency).trim().isNotEmpty
        ? fallbackCurrency.toUpperCase()
        : 'USD';
  }

  static bool shouldShowAuthPrompt({
    required bool isSignedIn,
    required bool hasProfile,
    bool hasStoredAuthToken = false,
  }) {
    if (isSignedIn || hasStoredAuthToken) {
      return false;
    }
    return !hasProfile;
  }

  static Map<String, dynamic> resolvePaymentSelection({
    required String selectedPlan,
    required String selectedCurrency,
    required double sevenDayAmount,
    required double monthlyAmount,
    required double yearlyAmount,
    required double lifetimePlanAmount,
  }) {
    final normalizedPlan = (selectedPlan ?? '').trim();
    final normalizedCurrency = resolveSelectedCurrency(
      selectedCurrency,
      'USD',
    );
    double amount = 0;

    switch (normalizedPlan) {
      case '7Days':
        amount = sevenDayAmount;
        break;
      case 'Monthly':
        amount = monthlyAmount;
        break;
      case 'Yearly':
        amount = yearlyAmount;
        break;
      case 'Lifetime':
        amount = lifetimePlanAmount;
        break;
      default:
        amount = 0;
    }

    return {
      'plan': normalizedPlan,
      'currency': normalizedCurrency,
      'amount': amount,
    };
  }

  static String buildSuccessMessage(String planName) {
    final normalizedPlan = (planName.isEmpty ? 'selected plan' : planName)
        .trim();
    return 'You are signed in and can continue with checkout for $normalizedPlan.';
  }
}
