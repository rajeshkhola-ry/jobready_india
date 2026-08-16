import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'dart:js' as js;

import 'api_config.dart';

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult({
    required this.success,
    this.message,
    this.paymentId,
    this.orderId,
    this.signature,
  });

  final bool success;
  final String? message;
  final String? paymentId;
  final String? orderId;
  final String? signature;
}

class RazorpayPaymentService {
  RazorpayPaymentService._internal();

  static final RazorpayPaymentService instance = RazorpayPaymentService._internal();

  factory RazorpayPaymentService() => instance;

  bool _scriptLoaded = false;
  bool _scriptLoading = false;
  Completer<void>? _scriptCompleter;

  bool get isConfigured => ApiConfig.razorpayConfig.keyId.isNotEmpty;

  Future<bool> initialize({bool forceReload = false}) async {
    if (!kIsWeb) {
      return false;
    }

    if (_scriptLoaded && !forceReload) {
      return true;
    }

    if (_scriptLoading) {
      await _scriptCompleter!.future;
      return _scriptLoaded;
    }

    _scriptLoading = true;
    _scriptCompleter = Completer<void>();

    final document = js.context['document'];
    final script = document.callMethod('createElement', ['script']);
    script['src'] = 'https://checkout.razorpay.com/v1/checkout.js';
    script['type'] = 'text/javascript';
    script['async'] = true;

    final headElement = document['head'];
    headElement.callMethod('appendChild', [script]);

    void completeLoad() {
      _scriptLoaded = true;
      _scriptLoading = false;
      if (!(_scriptCompleter?.isCompleted ?? true)) {
        _scriptCompleter?.complete();
      }
    }

    void completeError() {
      _scriptLoading = false;
      if (!(_scriptCompleter?.isCompleted ?? true)) {
        _scriptCompleter?.completeError(
          const FormatException('Razorpay checkout script failed to load.'),
        );
      }
    }

    script.callMethod('addEventListener', ['load', js_util.allowInterop(completeLoad)]);
    script.callMethod('addEventListener', ['error', js_util.allowInterop(completeError)]);

    try {
      await _scriptCompleter!.future;
      return _scriptLoaded;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object> buildCheckoutPayload({
    required String orderId,
    required String amountInPaise,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? description,
    String? callbackUrl,
  }) {
    final config = ApiConfig.razorpayConfig;
    final displayDescription = description ?? config.description;
    return <String, Object>{
      'key': config.keyId,
      'amount': amountInPaise,
      'currency': config.currency,
      'name': config.businessName,
      'description': displayDescription,
      'order_id': orderId,
      'prefill': <String, String>{
        'name': customerName,
        'email': customerEmail,
        'contact': customerPhone,
      },
      'theme': <String, String>{'color': config.themeColor},
      'callback_url': callbackUrl ?? config.callbackUrl,
    };
  }

  Future<RazorpayCheckoutResult> openCheckout({
    required String orderId,
    required String amountInPaise,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? description,
    String? callbackUrl,
  }) async {
    if (!kIsWeb) {
      return const RazorpayCheckoutResult(
        success: false,
        message: 'Razorpay checkout is only available on web.',
      );
    }

    if (!isConfigured) {
      return const RazorpayCheckoutResult(
        success: false,
        message: 'Razorpay key ID is not configured.',
      );
    }

    final ready = await initialize();
    if (!ready) {
      return const RazorpayCheckoutResult(
        success: false,
        message: 'Unable to load the Razorpay checkout SDK.',
      );
    }

    final orderPayload = buildCheckoutPayload(
      orderId: orderId,
      amountInPaise: amountInPaise,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      description: description,
      callbackUrl: callbackUrl,
    );

    try {
      final jsPayload = jsonEncode(orderPayload);
      final script = '''
(function() {
  const payload = $jsPayload;
  const razorpay = new window.Razorpay(payload);
  razorpay.open();
})();
''';
      js.context.callMethod('eval', [script]);
      return const RazorpayCheckoutResult(
        success: true,
        message: 'Razorpay checkout opened.',
      );
    } catch (error) {
      // Never surface a raw JS interop error object (e.g. "Instance of
      // 'minified:xx'") directly to the user.
      final safeMessage = error is String ? error : 'Unable to open Razorpay checkout. Please try again.';
      return RazorpayCheckoutResult(
        success: false,
        message: safeMessage,
      );
    }
  }
}
