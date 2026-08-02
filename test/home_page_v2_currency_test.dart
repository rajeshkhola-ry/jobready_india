import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Pages/home_page_v2.dart';

void main() {
  group('resolvePreferredPaymentCurrency', () {
    test('prefers a previously saved currency selection', () {
      expect(
        resolvePreferredPaymentCurrency(
          storedCurrency: 'EUR',
          profileCountry: 'India',
          browserLanguage: 'en-IN',
        ),
        'EUR',
      );
    });

    test('defaults to INR when the profile country is India', () {
      expect(
        resolvePreferredPaymentCurrency(
          profileCountry: 'India',
          browserLanguage: 'en-US',
        ),
        'INR',
      );
    });

    test('defaults to USD for international users', () {
      expect(
        resolvePreferredPaymentCurrency(
          profileCountry: 'United States',
          browserLanguage: 'en-US',
        ),
        'USD',
      );
    });
  });
}
