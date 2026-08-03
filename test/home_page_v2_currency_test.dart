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

  group('buildPlanDisplayLabel', () {
    test('uses INR formatting when the selected currency is INR', () {
      expect(
        buildPlanDisplayLabel(
          plan: 'Monthly',
          amount: 99,
          currencyCode: 'INR',
          monthlyAmount: 99,
          yearlyAmount: 799,
          lifetimePlanAmount: 1999,
        ),
        'MONTHLY - ₹99/month',
      );
    });

    test('uses USD formatting for the selected currency', () {
      expect(
        buildPlanDisplayLabel(
          plan: 'Yearly',
          amount: 14.99,
          currencyCode: 'USD',
          monthlyAmount: 1.99,
          yearlyAmount: 14.99,
          lifetimePlanAmount: 39,
        ),
        'YEARLY - \$14.99/year ⭐',
      );
    });
  });
}
