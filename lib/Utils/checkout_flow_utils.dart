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
  }) {
    if (isSignedIn) {
      return false;
    }
    return !hasProfile;
  }

  static String buildSuccessMessage(String planName) {
    final normalizedPlan = (planName.isEmpty ? 'selected plan' : planName)
        .trim();
    return 'You are signed in and can continue with checkout for $normalizedPlan.';
  }
}
