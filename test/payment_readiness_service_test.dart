import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/api_config.dart';

void main() {
  group('Payment readiness service', () {
    test('returns configuration-required state when usage type is missing', () {
      final readiness = ApiService.buildPaymentReadiness(
        gateway: '',
        planId: 'Monthly',
        amount: 1.99,
        currency: 'USD',
        usageType: null,
      );

      expect(readiness['status'], 'configuration_required');
      expect(readiness['label'], 'Configuration Required');
    });

    test('returns unavailable state for free-plan checkout path', () {
      final readiness = ApiService.buildPaymentReadiness(
        gateway: '',
        planId: 'Free',
        amount: 0,
        currency: 'USD',
        usageType: 'Personal',
      );

      expect(readiness['status'], 'unavailable');
      expect(readiness['label'], 'Unavailable');
    });

    test('returns integration-ready state for paid plan with local selections complete', () {
      final readiness = ApiService.buildPaymentReadiness(
        gateway: '',
        planId: 'Monthly',
        amount: 1.99,
        currency: 'USD',
        usageType: 'Personal',
      );

      expect(readiness['status'], 'ready_for_integration');
      expect(readiness['label'], 'Ready for Integration');
      expect(readiness['currency_mode'], 'usd_converted_display');
    });
  });
}
