import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Utils/checkout_flow_utils.dart';

void main() {
  group('CheckoutFlowUtils', () {
    test(
      'prefers the explicitly selected currency over the fallback currency',
      () {
        expect(CheckoutFlowUtils.resolveSelectedCurrency('INR', 'USD'), 'INR');
      },
    );

    test('falls back to USD when no explicit currency is selected', () {
      expect(CheckoutFlowUtils.resolveSelectedCurrency('', 'USD'), 'USD');
    });

    test('skips the auth prompt for already signed-in users', () {
      expect(
        CheckoutFlowUtils.shouldShowAuthPrompt(
          isSignedIn: true,
          hasProfile: false,
        ),
        isFalse,
      );
    });

    test('keeps the confirmation message aligned with the selected plan', () {
      expect(
        CheckoutFlowUtils.buildSuccessMessage('Lifetime'),
        contains('Lifetime'),
      );
      expect(
        CheckoutFlowUtils.buildSuccessMessage('Lifetime'),
        contains('continue with checkout'),
      );
    });
  });
}
