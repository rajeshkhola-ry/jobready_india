import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/razorpay_service.dart';

void main() {
  group('RazorpayPaymentService', () {
    test('buildCheckoutPayload includes the order and customer values', () {
      final payload = RazorpayPaymentService.instance.buildCheckoutPayload(
        orderId: 'order_123',
        amountInPaise: '249900',
        customerName: 'Test User',
        customerEmail: 'test@example.com',
        customerPhone: '9999999999',
        description: 'Lifetime Pass',
      );

      expect(payload['order_id'], 'order_123');
      expect(payload['amount'], '249900');
      expect(payload['currency'], 'INR');
      expect(payload['description'], 'Lifetime Pass');
      expect((payload['prefill'] as Map<String, Object?>)['name'], 'Test User');
      expect((payload['prefill'] as Map<String, Object?>)['email'], 'test@example.com');
      expect((payload['prefill'] as Map<String, Object?>)['contact'], '9999999999');
    });
  });
}
