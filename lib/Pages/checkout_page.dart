import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop' as js_interop;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/api_config.dart';
import '../Services/razorpay_service.dart';
import '../Services/user_account_service.dart';
import '../Services/user_auth_service.dart';
import '../Services/voice_quota_service.dart';
import '../Widgets/user_auth_dialog.dart';

const Map<String, String> _paymentCurrencyLabels = {
  'USD': 'US Dollar (USD)',
  'INR': 'Indian Rupee (INR)',
};

const Map<String, String> _paymentCurrencySymbols = {
  'USD': '\$',
  'INR': '₹',
};

String _formatCurrencyAmount(double amount, String currencyCode) {
  final symbol = _paymentCurrencySymbols[currencyCode] ?? '$currencyCode ';
  final showWholeOnly = currencyCode == 'JPY';
  final rounded = amount.roundToDouble();
  final formatted = showWholeOnly
      ? amount.round().toString()
      : amount == rounded
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
  return '$symbol$formatted';
}

String buildPlanDisplayLabel({
  required String plan,
  required double amount,
  required String currencyCode,
  required double monthlyAmount,
  required double yearlyAmount,
  required double lifetimePlanAmount,
}) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final displayAmount = _formatCurrencyAmount(amount, normalizedCurrency);

  switch (plan) {
    case 'Free':
      return 'FREE - ${_formatCurrencyAmount(0, normalizedCurrency)}';
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

/// Never surfaces a raw, non-human-readable object (e.g. a minified JS interop
/// error) to the user - every caller gets a clean, safe string back instead.
String _safeErrorText(Object? error, {String fallback = 'Unable to complete request. Please try again.'}) {
  if (error == null) {
    return fallback;
  }
  if (error is String) {
    final trimmed = error.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  String raw;
  try {
    raw = error.toString();
  } catch (_) {
    return fallback;
  }
  raw = raw.replaceFirst('Exception: ', '').trim();
  final looksOpaque = raw.isEmpty ||
      raw.startsWith('Instance of ') ||
      raw.contains('minified:') ||
      raw.contains('ProgressEvent') ||
      raw.contains('[object ');
  return looksOpaque ? fallback : raw;
}

/// Dedicated full-page checkout: Promo Code, GSTIN/billing, and Payment for a
/// paid plan selected on the Homepage. Never used for the Free plan (that is
/// activated directly from the Homepage without opening checkout).
class CheckoutPage extends StatefulWidget {
  final String planId;
  final String billingPeriod;
  final double amount;
  final String currency;
  final String activeGateway;
  final String? usageType;
  final double sevenDayAmount;
  final double monthlyAmount;
  final double yearlyAmount;
  final double lifetimePlanAmount;

  const CheckoutPage({
    super.key,
    required this.planId,
    required this.billingPeriod,
    required this.amount,
    required this.currency,
    required this.activeGateway,
    required this.usageType,
    required this.sevenDayAmount,
    required this.monthlyAmount,
    required this.yearlyAmount,
    required this.lifetimePlanAmount,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _submitting = false;
  bool _creatingPaymentLink = false;
  Map<String, dynamic>? _lastCheckoutResponse;
  String _localCurrency = 'USD';
  late final TextEditingController _checkoutGstinController;
  late final TextEditingController _checkoutCompanyController;
  late final TextEditingController _checkoutBillingEmailController;
  late final TextEditingController _promoCodeController;
  bool _isSezUnit = false;

  List<Map<String, dynamic>> _availableOffers = <Map<String, dynamic>>[];
  Map<String, dynamic>? _appliedPromo;
  String? _promoMessage;
  bool _promoMessageIsError = false;
  bool _promoValidating = false;

  static const Duration _checkoutTimeout = Duration(minutes: 10);
  late String _selectedPlan;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.planId;
    _localCurrency = (widget.currency == 'INR' || widget.currency == 'USD')
        ? widget.currency
        : 'USD';
    final profile = UserAccountService.getProfile();
    _checkoutGstinController = TextEditingController(text: profile.gstin);
    _checkoutCompanyController = TextEditingController(text: profile.companyName);
    _checkoutBillingEmailController = TextEditingController();
    _promoCodeController = TextEditingController();
    _loadAvailableOffers();
  }

  @override
  void dispose() {
    _checkoutGstinController.dispose();
    _checkoutCompanyController.dispose();
    _checkoutBillingEmailController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableOffers() async {
    try {
      final response = await _requestJsonWithFallback('GET', '/api/public/promo-codes');
      final offers = (response['offers'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _availableOffers = offers.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (_) {
      // Offers are a convenience UI - silently skip if unavailable, manual code entry still works.
    }
  }

  String _promoDiscountLabel(Map<String, dynamic> offer) {
    final percent = (offer['discountPercent'] as num?)?.toDouble() ?? 0;
    final flat = (offer['discountFlat'] as num?)?.toDouble() ?? 0;
    if (percent > 0) return '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1)}% off';
    if (flat > 0) return '₹${flat.toStringAsFixed(flat.truncateToDouble() == flat ? 0 : 2)} off';
    return 'Offer';
  }

  Future<void> _applyPromoCode(String rawCode, {bool silent = false}) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      if (!silent) {
        setState(() {
          _promoMessageIsError = true;
          _promoMessage = 'Enter a promo code first.';
        });
      }
      return;
    }

    final amountMinor = (_chargeAmountForPlan(_selectedPlan) * 100).round();
    if (amountMinor <= 0) {
      return;
    }

    setState(() {
      _promoValidating = true;
      if (!silent) {
        _promoMessage = null;
      }
    });

    try {
      final response = await _requestJsonWithFallback(
        'POST',
        '/api/public/promo-codes/validate',
        body: {'code': code, 'amount': amountMinor, 'currency': _localCurrency, 'planId': _selectedPlan},
      );
      if (!mounted) return;
      final promo = (response['promo'] as Map?) ?? const {};
      setState(() {
        _promoValidating = false;
        _appliedPromo = {
          'code': code,
          'discountPercent': (promo['discountPercent'] as num?)?.toDouble() ?? 0,
          'discountFlat': (promo['discountFlat'] as num?)?.toDouble() ?? 0,
        };
        _promoMessageIsError = false;
        _promoMessage = 'Promo code "$code" applied successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _promoValidating = false;
        _appliedPromo = null;
        _promoMessageIsError = true;
        _promoMessage = _safeErrorText(error);
      });
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromo = null;
      _promoMessage = null;
      _promoMessageIsError = false;
      _promoCodeController.clear();
    });
  }

  double _discountAmountForPlan(String plan) {
    if (_appliedPromo == null) {
      return 0;
    }
    final baseAmount = _chargeAmountForPlan(plan);
    final percent = (_appliedPromo!['discountPercent'] as num?)?.toDouble() ?? 0;
    final flat = (_appliedPromo!['discountFlat'] as num?)?.toDouble() ?? 0;
    if (percent > 0) {
      return (baseAmount * percent / 100);
    }
    if (flat > 0) {
      return flat > baseAmount ? baseAmount : flat;
    }
    return 0;
  }

  double _discountedAmountForPlan(String plan) {
    final baseAmount = _chargeAmountForPlan(plan);
    final discount = _discountAmountForPlan(plan);
    final result = baseAmount - discount;
    return result < 0 ? 0 : result;
  }

  bool _canProceedWithPurchase() {
    return UserAuthService.isSignedIn;
  }

  double _monthlyForPlan(String plan) {
    if (plan == 'Monthly') return widget.monthlyAmount;
    if (plan == 'Yearly') return widget.yearlyAmount / 12;
    return 0;
  }

  bool _isSubscriptionPlan(String plan) {
    return plan == 'Monthly' || plan == 'Yearly';
  }

  double _chargeAmountForPlan(String plan) {
    if (plan == '7Days') {
      return widget.sevenDayAmount;
    }
    if (plan == 'Lifetime') {
      return widget.lifetimePlanAmount;
    }
    if (plan == 'Yearly') {
      return widget.yearlyAmount;
    }
    if (plan == 'Monthly') {
      return widget.monthlyAmount;
    }
    return 0;
  }

  Map<String, dynamic> _readiness() {
    return ApiService.buildPaymentReadiness(
      gateway: widget.activeGateway,
      planId: _selectedPlan,
      amount: _chargeAmountForPlan(_selectedPlan),
      currency: _localCurrency,
      usageType: widget.usageType,
    );
  }

  String _apiUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized;
  }

  List<String> _candidateApiUrls(String path) {
    final normalized = _apiUrl(path);
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final fallback = '$base$normalized';
    if (fallback == normalized) {
      return <String>[normalized];
    }
    // Prefer the configured backend first, then same-origin as fallback.
    return <String>[fallback, normalized];
  }

  String _resolvedGatewayName() {
    final configured = widget.activeGateway.trim().toLowerCase();
    if (configured.isNotEmpty) {
      return configured;
    }
    return 'razorpay';
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    html.HttpRequest response;
    try {
      response = await html.HttpRequest.request(
        url,
        method: method,
        sendData: body == null ? null : jsonEncode(body),
        requestHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
    } catch (_) {
      throw Exception('Unable to reach payment API at $url.');
    }

    final raw = response.responseText ?? '{}';
    final contentType = response.getResponseHeader('content-type')?.toLowerCase() ?? '';
    if (_looksLikeHtmlResponse(raw, contentType)) {
      throw Exception('Payment service returned HTML instead of JSON from $url.');
    }

    Map<String, dynamic> mapped = <String, dynamic>{};
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          mapped = Map<String, dynamic>.from(decoded);
        } else {
          throw Exception('Unexpected response format from $url.');
        }
      } on FormatException {
        throw Exception('Payment service returned non-JSON response from $url.');
      }
    }

    mapped['_http_status'] = response.status;
    final status = response.status ?? 0;
    if (status < 200 || status >= 300) {
      final backendError = mapped['error']?.toString().trim() ?? '';
      if (backendError.isNotEmpty) {
        throw Exception(backendError);
      }
      throw Exception('Payment service returned HTTP $status.');
    }

    return mapped;
  }

  Future<Map<String, dynamic>> _requestJsonWithFallback(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    Object? primaryError;
    Object? lastError;
    final candidates = _candidateApiUrls(path);
    for (var i = 0; i < candidates.length; i++) {
      final url = candidates[i];
      try {
        return await _requestJson(method, url, body: body);
      } catch (error) {
        if (i == 0) {
          primaryError = error;
        }

        if (_isNonJsonResponseError(error) && primaryError != null) {
          lastError = primaryError;
        } else {
          lastError = error;
        }
      }
    }

    throw Exception(_friendlyCheckoutError(lastError, path));
  }

  bool _looksLikeHtmlResponse(String raw, String contentType) {
    final normalizedBody = raw.trimLeft().toLowerCase();
    return contentType.contains('text/html') ||
        normalizedBody.startsWith('<!doctype html') ||
        normalizedBody.startsWith('<html');
  }

  bool _isNonJsonResponseError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('html instead of json') ||
        normalized.contains('non-json response') ||
        normalized.contains('is not valid json') ||
        normalized.contains('unexpected token') ||
        normalized.contains('<!doctype');
  }

  String _friendlyCheckoutError(Object? error, String path) {
    final raw = _safeErrorText(
      error,
      fallback: 'Payment request failed before checkout opened. Please refresh and try again.',
    );
    if (raw.contains('HTTP 404') || raw.contains('Unable to reach payment API')) {
      return 'Payment service endpoint is not reachable for $path. Please retry in 1 minute.';
    }
    if (raw.contains('returned HTML instead of JSON') || raw.contains('returned non-JSON response')) {
      return 'Payment service endpoint is not reachable for $path. Please retry in 1 minute.';
    }
    if (raw.contains('Recurring digits in customer contact are disallowed')) {
      return 'Please update your mobile number in account profile and try payment again.';
    }
    return raw;
  }

  Map<String, dynamic> _buildBillingPayload() {
    final profile = UserAccountService.getProfile();
    final session = UserAuthService.getSession();
    final isBusiness = (widget.usageType ?? 'Personal') == 'Business';

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : (session?.displayName.trim().isNotEmpty == true ? session!.displayName.trim() : 'User');
    final typedBillingEmail = _checkoutBillingEmailController.text.trim();
    final email = typedBillingEmail.isNotEmpty
        ? typedBillingEmail
        : (profile.email.trim().isNotEmpty
            ? profile.email.trim()
            : (session?.email.trim().isNotEmpty == true ? session!.email.trim() : ''));
    final mobileRaw = profile.mobileNumber.trim().isNotEmpty
        ? profile.mobileNumber.trim()
        : (session?.mobileNumber.trim() ?? '');
    final mobileDigits = mobileRaw.replaceAll(RegExp(r'\D'), '');
    final normalizedMobile = mobileDigits;
    final country = profile.country.trim().isEmpty ? 'India' : profile.country.trim();
    final state = isBusiness
        ? (profile.billingState.trim().isNotEmpty ? profile.billingState.trim() : country)
        : country;
    final typedCompany = _checkoutCompanyController.text.trim();
    final company = isBusiness ? (typedCompany.isNotEmpty ? typedCompany : profile.companyName.trim()) : '';
    final typedGstin = _checkoutGstinController.text.trim().toUpperCase();
    final gstin = typedGstin.isNotEmpty ? typedGstin : profile.gstin.trim();

    return {
      'name': displayName,
      'company': company,
      'address': '',
      'country': country,
      'state': state,
      'gstin': gstin,
      'email': email,
      'mobile': normalizedMobile,
      'sez': (isBusiness && _isSezUnit) ? 'YES' : 'NO',
    };
  }

  Future<Map<String, dynamic>> _createPaymentLinkFromBilling(Map<String, dynamic> billing) async {
    final amountMinor = (_chargeAmountForPlan(_selectedPlan) * 100).round();
    if (amountMinor <= 0) {
      throw Exception('Invalid payment amount for selected plan.');
    }

    final payload = {
      'gateway': _resolvedGatewayName(),
      'amount': amountMinor,
      'currency': _localCurrency,
      'receipt': 'plink-${_selectedPlan.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
      'planId': _selectedPlan,
      'billing': billing,
    };

    final response = await _requestJsonWithFallback(
      'POST',
      '/api/create-payment-link',
      body: payload,
    );

    if (response['success'] != true) {
      final failure = response['error']?.toString() ?? 'Unable to generate payment link.';
      throw Exception(failure);
    }

    final paymentLink = response['payment_link']?.toString().trim() ?? '';
    if (paymentLink.isEmpty) {
      throw Exception('Payment link was created but link URL is missing.');
    }

    return response;
  }

  bool _shouldFallbackToPaymentLink(String failureMessage) {
    final normalized = failureMessage.toLowerCase();
    if (normalized.contains('cancelled by user')) {
      return false;
    }
    return normalized.contains('did not open') ||
        normalized.contains('timed out') ||
        normalized.contains('before checkout opened') ||
        normalized.contains('unable to load razorpay checkout sdk') ||
        normalized.contains('nosuchmethoderror') ||
        normalized.contains('is not a function') ||
        normalized.contains('.nk is not a function');
  }

  Map<String, dynamic>? _decodeBridgeMessage(dynamic data) {
    dynamic normalized = data;

    if (normalized is String) {
      final candidate = normalized.trim();
      if (candidate.isNotEmpty) {
        try {
          normalized = jsonDecode(candidate);
        } catch (_) {
          return null;
        }
      }
    }

    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }

    try {
      final dartified = (normalized as js_interop.JSAny?).dartify();
      if (dartified is Map) {
        return Map<String, dynamic>.from(dartified);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<Map<String, dynamic>> _openRazorpayAndVerify({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    required Map<String, dynamic> billing,
    String verifyPath = '/api/verify-payment',
    String? description,
  }) async {
    final initialized = await RazorpayPaymentService.instance.initialize();
    if (!initialized) {
      throw Exception('Unable to load Razorpay checkout SDK.');
    }

    final completer = Completer<Map<String, String>>();
    final bridgeToken = 'rzp_${DateTime.now().microsecondsSinceEpoch}';

    final baseOptions = {
      'key': keyId,
      'amount': amount,
      'currency': currency,
      'name': ApiConfig.razorpayConfig.businessName,
      'description': description ?? ApiConfig.razorpayConfig.description,
      'order_id': orderId,
      'prefill': {
        'name': billing['name']?.toString() ?? 'User',
        'email': billing['email']?.toString() ?? '',
        'contact': billing['mobile']?.toString() ?? '',
      },
      'notes': {
        'name': billing['name']?.toString() ?? '',
        'company': billing['company']?.toString() ?? '',
        'gstin': billing['gstin']?.toString() ?? '',
        'state': billing['state']?.toString() ?? '',
        'country': billing['country']?.toString() ?? 'India',
        'sez': billing['sez']?.toString() ?? 'NO',
      },
      'theme': {
        'color': '#${ApiConfig.razorpayConfig.themeColor.toUpperCase()}',
      },
    };

    final messageSubscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) {
        return;
      }
      final source = data['source']?.toString() ?? '';
      final token = data['token']?.toString() ?? '';
      if (source != 'jobready_razorpay' || token != bridgeToken) {
        return;
      }

      final type = data['type']?.toString() ?? '';
      if (type == 'success') {
        final payloadRaw = data['payload'];
        if (payloadRaw is Map) {
          if (!completer.isCompleted) {
            completer.complete({
              'order_id': payloadRaw['order_id']?.toString() ?? '',
              'payment_id': payloadRaw['payment_id']?.toString() ?? '',
              'signature': payloadRaw['signature']?.toString() ?? '',
            });
          }
        }
      } else if (type == 'dismiss') {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Payment cancelled by user.'));
        }
      } else if (type == 'failed') {
        final payloadRaw = data['payload'];
        final message = payloadRaw is Map
            ? payloadRaw['message']?.toString().trim()
            : null;
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message?.isNotEmpty == true
                ? message
                : 'Razorpay checkout could not be opened.'),
          );
        }
      }
    });

    final optionsJson = jsonEncode(baseOptions);
    final script = '''
(function() {
  if (!window.Razorpay) {
    window.postMessage({ source: 'jobready_razorpay', token: '$bridgeToken', type: 'dismiss' }, window.location.origin);
    return;
  }
  const opts = $optionsJson;
  opts.handler = function(response) {
    window.postMessage({
      source: 'jobready_razorpay',
      token: '$bridgeToken',
      type: 'success',
      payload: {
        order_id: response.razorpay_order_id || '',
        payment_id: response.razorpay_payment_id || '',
        signature: response.razorpay_signature || ''
      }
    }, window.location.origin);
  };
  opts.modal = {
    ondismiss: function() {
      window.postMessage({ source: 'jobready_razorpay', token: '$bridgeToken', type: 'dismiss' }, window.location.origin);
    }
  };
  const checkout = new window.Razorpay(opts);
  if (checkout && typeof checkout.on === 'function') {
    checkout.on('payment.failed', function(response) {
      const message = response && response.error && response.error.description
        ? response.error.description
        : 'Razorpay payment failed before confirmation.';
      window.postMessage({
        source: 'jobready_razorpay',
        token: '$bridgeToken',
        type: 'failed',
        payload: { message: message }
      }, window.location.origin);
    });
  }
  try {
    checkout.open();
  } catch (error) {
    window.postMessage({
      source: 'jobready_razorpay',
      token: '$bridgeToken',
      type: 'failed',
      payload: { message: 'Razorpay checkout did not open. Please allow popups and try again.' }
    }, window.location.origin);
    return;
  }

  setTimeout(function() {
    const hasFrame = !!document.querySelector('.razorpay-container, iframe[src*="razorpay"]');
    if (!hasFrame) {
      window.postMessage({
        source: 'jobready_razorpay',
        token: '$bridgeToken',
        type: 'failed',
        payload: { message: 'Razorpay checkout did not open. Please allow popups/cookies or use payment link.' }
      }, window.location.origin);
    }
  }, 2200);
})();
''';

    js.context.callMethod('eval', [script]);

    late final Map<String, String> paymentResult;
    try {
      paymentResult = await completer.future.timeout(
        _checkoutTimeout,
        onTimeout: () => throw TimeoutException('Payment confirmation timed out.'),
      );
    } finally {
      await messageSubscription.cancel();
    }

    final verifyPayload = {
      'order_id': paymentResult['order_id'],
      'payment_id': paymentResult['payment_id'],
      'signature': paymentResult['signature'],
    };

      final verifyResponse = await _requestJsonWithFallback(
      'POST',
      verifyPath,
      body: verifyPayload,
    );

    if (verifyResponse['success'] != true) {
      final failure = verifyResponse['error']?.toString() ?? 'Payment verification failed.';
      throw Exception(failure);
    }

    return {
      ...verifyResponse,
      ...paymentResult,
    };
  }

  Future<void> _showPaymentSuccessFlow({required String plan}) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$plan plan activated',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your payment has been confirmed. Continue in the main app and start using the tools right away.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (!mounted) {
                          return;
                        }
                        html.window.open('https://getreadyjob.com/', '_self');
                      },
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Open Main App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAuthThenContinue() async {
    await showDialog<void>(
      context: context,
      builder: (authContext) => UserAuthDialog(
        preselectedPlan: _selectedPlan,
        selectedCurrency: _localCurrency,
        stayOnHomeAfterAuth: true,
        onAuthenticated: (_, __) {
          if (!mounted) {
            return;
          }
          Future<void>.microtask(() => _continueToPayment(context));
        },
      ),
    );
  }

  Future<void> _createPaymentLink(BuildContext context) async {
    if (_submitting || _creatingPaymentLink) {
      return;
    }

    if (!_canProceedWithPurchase()) {
      await _openAuthThenContinue();
      return;
    }

    final readiness = _readiness();
    final readinessStatus = readiness['status']?.toString() ?? 'configuration_required';
    if (readinessStatus != 'ready_for_integration') {
      setState(() {
        _lastCheckoutResponse = {
          ...readiness,
          'selected_plan': _selectedPlan,
          'checkout_state': readinessStatus,
        };
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readiness['message']?.toString() ?? 'Checkout is not ready for payment link creation.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _creatingPaymentLink = true;
    });

    try {
      final billing = _buildBillingPayload();
      final response = await _createPaymentLinkFromBilling(billing);
      final paymentLink = response['payment_link']?.toString().trim() ?? '';

      setState(() {
        _lastCheckoutResponse = {
          ...response,
          'checkout_state': 'payment_link_created',
          'status': 'ready_for_integration',
          'label': 'Payment Link Created',
          'message': 'Razorpay payment link generated successfully. Share or open the link to complete payment.',
          'order_id': response['reference_id']?.toString() ?? 'N/A',
        };
      });

      html.window.open(paymentLink, '_blank');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment link created and opened in a new tab.')),
        );
      }
    } catch (error) {
      final failureMessage = _friendlyCheckoutError(error, '/api/create-payment-link');
      if (mounted) {
        setState(() {
          _lastCheckoutResponse = {
            ...readiness,
            'checkout_state': 'payment_link_failed',
            'status': 'unavailable',
            'label': 'Payment Link Failed',
            'message': failureMessage,
            'order_id': _lastCheckoutResponse?['order_id']?.toString() ?? 'N/A',
          };
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _creatingPaymentLink = false;
        });
      }
    }
  }

  Future<void> _continueToPayment(BuildContext context) async {
    if (!_canProceedWithPurchase()) {
      await _openAuthThenContinue();
      return;
    }

    final readiness = _readiness();
    final readinessStatus = readiness['status']?.toString() ?? 'configuration_required';
    if (readinessStatus == 'configuration_required') {
      setState(() {
        _lastCheckoutResponse = {
          ...readiness,
          'selected_plan': _selectedPlan,
          'checkout_state': 'configuration_required',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readiness['message']?.toString() ?? 'Configuration is still required.')),
      );
      return;
    }

    if (readinessStatus == 'unavailable') {
      setState(() {
        _lastCheckoutResponse = {
          ...readiness,
          'selected_plan': _selectedPlan,
          'checkout_state': 'unavailable',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readiness['message']?.toString() ?? 'Checkout is unavailable for this selection.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    Map<String, dynamic>? billingForFallback;
    try {
      if (!mounted || !context.mounted) {
        return;
      }

      final billing = _buildBillingPayload();
      billingForFallback = billing;
      final keyResponse = await _requestJsonWithFallback('GET', '/api/config');
      final keyId = keyResponse['key_id']?.toString().trim() ?? '';

      final amountMinor = (_chargeAmountForPlan(_selectedPlan) * 100).round();
      if (amountMinor <= 0) {
        throw Exception('Invalid payment amount for selected plan.');
      }

      final createOrderPayload = {
        'gateway': _resolvedGatewayName(),
        'amount': amountMinor,
        'currency': _localCurrency,
        'receipt': 'plan-${_selectedPlan.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
        'planId': _selectedPlan,
        'billing': billing,
        'promoCode': _appliedPromo?['code'] ?? '',
      };

      final createOrderResponse = await _requestJsonWithFallback(
        'POST',
        '/api/create-order',
        body: createOrderPayload,
      );

      if (createOrderResponse['success'] != true) {
        final failure = createOrderResponse['error']?.toString() ?? 'Unable to create payment order.';
        throw Exception(failure);
      }

      final isLocalCheckout = createOrderResponse['localOnly'] == true;
      final orderId = createOrderResponse['order_id']?.toString() ?? '';
      final orderAmount = int.tryParse(createOrderResponse['amount']?.toString() ?? '') ?? amountMinor;
      final orderCurrency = createOrderResponse['currency']?.toString().toUpperCase() ?? _localCurrency;

      if (orderId.isEmpty) {
        throw Exception('Payment order ID is missing from server response.');
      }

      if (isLocalCheckout) {
        setState(() {
          _lastCheckoutResponse = {
            ...readiness,
            'selected_plan': _selectedPlan,
            'checkout_state': 'local_checkout_ready',
            'status': 'ready_for_integration',
            'label': 'Local Checkout Ready',
            'message': 'Checkout is running in local fallback mode because the payment provider is not configured for this environment. Access has been granted in test mode.',
            'order_id': orderId,
            'localOnly': true,
          };
        });

        final profile = UserAccountService.getProfile();
        final selectedPlan = _selectedPlan;
        final isPaidPlan = selectedPlan != 'Free';
        final paidProfile = profile.copyWith(
          activePlan: selectedPlan,
          planId: selectedPlan.toLowerCase(),
          planName: selectedPlan,
          planStatus: 'active',
          remainingCredits: isPaidPlan ? 999 : 3,
          planCurrency: _localCurrency,
          planPrice: _chargeAmountForPlan(selectedPlan),
          planSummary: isPaidPlan ? '$selectedPlan access is active.' : 'Free access to core tools',
          toolsUnlimited: selectedPlan == 'Lifetime' || selectedPlan == 'Yearly' || selectedPlan == 'Monthly',
        );
        await UserAccountService.saveProfile(paidProfile);
        await VoiceQuotaService.applyPlanQuotaAllocation(selectedPlan);

        if (mounted) {
          setState(() {});
          await _showPaymentSuccessFlow(plan: _selectedPlan);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local checkout fallback accepted. Access is enabled for this session.')),
          );
        }
        return;
      }

      if (keyId.isEmpty) {
        throw Exception('Razorpay public key is not configured on the server.');
      }

      setState(() {
        _lastCheckoutResponse = {
          ...readiness,
          'selected_plan': _selectedPlan,
          'checkout_state': 'order_created',
          'status': 'ready_for_integration',
          'label': 'Order Created',
          'message': 'Payment order created successfully. Opening Razorpay checkout...',
          'order_id': orderId,
        };
      });

      final verification = await _openRazorpayAndVerify(
        keyId: keyId,
        orderId: orderId,
        amount: orderAmount,
        currency: orderCurrency,
        billing: billing,
      );

      setState(() {
        _lastCheckoutResponse = {
          ...verification,
          'checkout_state': 'verified',
          'status': 'ready_for_integration',
          'label': 'Payment Verified',
          'message': 'Payment processed and verified successfully.',
        };
      });

      final profile = UserAccountService.getProfile();
      final selectedPlan = _selectedPlan;
      final isPaidPlan = selectedPlan != 'Free';
      final paidProfile = profile.copyWith(
        activePlan: selectedPlan,
        planId: selectedPlan.toLowerCase(),
        planName: selectedPlan,
        planStatus: 'active',
        remainingCredits: isPaidPlan ? 999 : 3,
        planCurrency: _localCurrency,
        planPrice: _chargeAmountForPlan(selectedPlan),
        planSummary: isPaidPlan ? '$selectedPlan access is active.' : 'Free access to core tools',
        toolsUnlimited: selectedPlan == 'Lifetime' || selectedPlan == 'Yearly' || selectedPlan == 'Monthly',
      );
      await UserAccountService.saveProfile(paidProfile);
      await VoiceQuotaService.applyPlanQuotaAllocation(selectedPlan);

      if (mounted) {
        setState(() {});
        await _showPaymentSuccessFlow(plan: _selectedPlan);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verified successfully.')),
      );
    } catch (error) {
      final failureMessage = _friendlyCheckoutError(error, '/api/create-order');
      final shouldFallback = billingForFallback != null && _shouldFallbackToPaymentLink(failureMessage);
      if (shouldFallback) {
        try {
          final paymentLinkResponse = await _createPaymentLinkFromBilling(billingForFallback);
          final paymentLink = paymentLinkResponse['payment_link']?.toString().trim() ?? '';
          html.window.open(paymentLink, '_blank');
          if (mounted) {
            setState(() {
              _lastCheckoutResponse = {
                ...paymentLinkResponse,
                'checkout_state': 'payment_link_created',
                'status': 'ready_for_integration',
                'label': 'Checkout Fallback Activated',
                'message': 'Razorpay popup did not open. Payment link was generated and opened in a new tab.',
                'order_id': paymentLinkResponse['reference_id']?.toString() ?? _lastCheckoutResponse?['order_id']?.toString() ?? 'N/A',
              };
            });
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Razorpay popup was blocked. Opened payment link in new tab.')),
            );
          }
          return;
        } catch (fallbackError) {
          final fallbackFailure = _friendlyCheckoutError(fallbackError, '/api/create-payment-link');
          if (mounted) {
            setState(() {
              _lastCheckoutResponse = {
                ...readiness,
                'checkout_state': 'payment_link_failed',
                'status': 'unavailable',
                'label': 'Payment Link Fallback Failed',
                'message': fallbackFailure,
                'order_id': _lastCheckoutResponse?['order_id']?.toString() ?? 'N/A',
              };
            });
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(fallbackFailure)),
            );
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _lastCheckoutResponse = {
            ...readiness,
            'checkout_state': 'failed',
            'status': 'unavailable',
            'label': 'Payment Failed',
            'message': failureMessage,
            'order_id': _lastCheckoutResponse?['order_id']?.toString() ?? 'N/A',
          };
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready_for_integration':
        return const Color(0xFF166534);
      case 'configuration_required':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  Widget _buildUsageAndBillingSection() {
    final isBusiness = widget.usageType == 'Business';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isBusiness)
            TextField(
              controller: _checkoutGstinController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'GSTIN (Optional)',
                hintText: 'Please enter your GSTIN if you want a tax invoice, or leave blank and proceed.',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else ...[
            const Text(
              'Fill company details for a B2B business invoice, or skip to proceed.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _checkoutCompanyController,
              decoration: InputDecoration(
                labelText: 'Company / Business Legal Name',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _checkoutBillingEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Billing Email ID',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _checkoutGstinController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'GSTIN',
                hintText: 'Enter your 15-digit GSTIN (optional)',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            CheckboxListTile(
              value: _isSezUnit,
              onChanged: (value) => setState(() => _isSezUnit = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: const Color(0xFF1E3A8A),
              title: const Text(
                'Is this an SEZ unit / developer? (18% IGST applies; claim refund/ITC with tax invoice)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadinessCard() {
    final readiness = _readiness();
    final status = readiness['status']?.toString() ?? 'blocked';
    final statusColor = _statusColor(status);
    final amount = _chargeAmountForPlan(_selectedPlan);
    final discount = _discountAmountForPlan(_selectedPlan);
    final discountedAmount = _discountedAmountForPlan(_selectedPlan);
    final hasDiscount = _appliedPromo != null && discount > 0;
    final billingCountry = UserAccountService.getProfile().country.trim();
    final isExportSupply = billingCountry.isNotEmpty && billingCountry.toLowerCase() != 'india';
    final taxLine = isExportSupply
        ? 'Tax: Export of Services (0% GST) - zero-rated supply, no GST charged.'
        : (_isSezUnit
            ? 'Tax: 18% IGST (SEZ with Payment of IGST) - included in the amount above.'
            : 'Tax: 18% GST included in the amount above.');
    final recalculatedGstLine = (!isExportSupply && hasDiscount)
        ? 'Recalculated after discount: Base ${_formatCurrencyAmount(discountedAmount / 1.18, _localCurrency)} + GST ${_formatCurrencyAmount(discountedAmount - (discountedAmount / 1.18), _localCurrency)} = ${_formatCurrencyAmount(discountedAmount, _localCurrency)} payable.'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5FAFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DFF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  readiness['label']?.toString() ?? status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  readiness['message']?.toString() ?? 'Payment readiness unavailable.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasDiscount) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Plan: ${_selectedPlan} | Usage: ${widget.usageType ?? 'NOT SELECTED'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatCurrencyAmount(amount, _localCurrency),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '- ${_formatCurrencyAmount(discount, _localCurrency)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 6),
                Text(
                  '= ${_formatCurrencyAmount(discountedAmount, _localCurrency)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ] else
            Text(
              'Plan: ${_selectedPlan} | Amount: ${_formatCurrencyAmount(amount, _localCurrency)} | Usage: ${widget.usageType ?? 'NOT SELECTED'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          const SizedBox(height: 4),
          Text(
            taxLine,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isExportSupply ? const Color(0xFF0F766E) : const Color(0xFF334155),
            ),
          ),
          if (recalculatedGstLine != null) ...[
            const SizedBox(height: 4),
            Text(
              recalculatedGstLine,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Gateway display: ${_resolvedGatewayName().toUpperCase()} | Currency mode: ${readiness['currency_mode']?.toString() ?? 'n/a'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          Text(
            status == 'ready_for_integration'
                ? 'Secure flow: create order, open Razorpay, then verify payment.'
                : 'Resolve configuration notes above before attempting checkout.',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    final applicableOffers = _availableOffers.where((offer) {
      final applicablePlans = (offer['applicablePlans'] as List?)?.map((item) => item.toString()).toList() ?? const <String>[];
      return applicablePlans.isEmpty || applicablePlans.contains(_selectedPlan);
    }).toList();
    final hasOffers = applicableOffers.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DFF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a promo code?',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF16324D)),
          ),
          if (hasOffers) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: null,
              isExpanded: true,
              hint: const Text('Available offers', style: TextStyle(fontSize: 12.5)),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FBFF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: applicableOffers
                  .map(
                    (offer) => DropdownMenuItem<String>(
                      value: offer['code'].toString(),
                      child: Text(
                        '${offer['code']} - ${_promoDiscountLabel(offer)}${(offer['description'] ?? '').toString().isNotEmpty ? ' (${offer['description']})' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  _promoCodeController.text = value;
                  _applyPromoCode(value);
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  textCapitalization: TextCapitalization.characters,
                  enabled: _appliedPromo == null,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter promo code',
                    filled: true,
                    fillColor: const Color(0xFFF8FBFF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_appliedPromo == null)
                ElevatedButton(
                  onPressed: _promoValidating ? null : () => _applyPromoCode(_promoCodeController.text),
                  child: Text(_promoValidating ? 'Checking...' : 'Apply'),
                )
              else
                OutlinedButton(
                  onPressed: _removePromoCode,
                  child: const Text('Remove'),
                ),
            ],
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _promoMessageIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: _promoMessageIsError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _promoMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _promoMessageIsError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutResponseCard() {
    final response = _lastCheckoutResponse;
    if (response == null) {
      return const SizedBox.shrink();
    }

    final status = response['status']?.toString() ?? 'unknown';
    final statusColor = _statusColor(status);
    final reference = response['order_id']?.toString() ?? 'N/A';
    final summary = response['message']?.toString() ?? 'No local checkout summary available.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest checkout state',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
          ),
          const SizedBox(height: 6),
          Text(
            response['label']?.toString() ?? status.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            'Reference: $reference',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            buildPlanDisplayLabel(
              plan: widget.planId,
              amount: widget.amount,
              currencyCode: widget.currency,
              monthlyAmount: widget.monthlyAmount,
              yearlyAmount: widget.yearlyAmount,
              lifetimePlanAmount: widget.lifetimePlanAmount,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Billing: ${widget.billingPeriod} • Currency: ${widget.currency}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderSummaryHeader(),
                const SizedBox(height: 12),
                Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FCFF), Color(0xFFF4F8FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E1F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A94A3B8),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected payment gateway: ${_resolvedGatewayName().toUpperCase()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16324D),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _localCurrency,
            isExpanded: true,
            items: _paymentCurrencyLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _localCurrency = value;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Payment currency',
              helperText: 'Auto geo-detection selects INR for India and USD for other countries. You can switch manually anytime.',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          _buildReadinessCard(),
          const SizedBox(height: 8),
          _buildPromoCodeSection(),
          const SizedBox(height: 8),
          _buildUsageAndBillingSection(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('${_selectedPlan}_${widget.usageType}_${_localCurrency}'),
            value: _selectedPlan,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: '7Days',
                child: Text(
                  buildPlanDisplayLabel(
                    plan: '7Days',
                    amount: widget.sevenDayAmount,
                    currencyCode: _localCurrency,
                    monthlyAmount: widget.monthlyAmount,
                    yearlyAmount: widget.yearlyAmount,
                    lifetimePlanAmount: widget.lifetimePlanAmount,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Monthly',
                child: Text(
                  buildPlanDisplayLabel(
                    plan: 'Monthly',
                    amount: widget.monthlyAmount,
                    currencyCode: _localCurrency,
                    monthlyAmount: widget.monthlyAmount,
                    yearlyAmount: widget.yearlyAmount,
                    lifetimePlanAmount: widget.lifetimePlanAmount,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Yearly',
                child: Text(
                  buildPlanDisplayLabel(
                    plan: 'Yearly',
                    amount: widget.yearlyAmount,
                    currencyCode: _localCurrency,
                    monthlyAmount: widget.monthlyAmount,
                    yearlyAmount: widget.yearlyAmount,
                    lifetimePlanAmount: widget.lifetimePlanAmount,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Lifetime',
                child: Text(
                  buildPlanDisplayLabel(
                    plan: 'Lifetime',
                    amount: widget.lifetimePlanAmount,
                    currencyCode: _localCurrency,
                    monthlyAmount: widget.monthlyAmount,
                    yearlyAmount: widget.yearlyAmount,
                    lifetimePlanAmount: widget.lifetimePlanAmount,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPlan = value;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Choose plan',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedPlan != 'Basic')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB9DFFF)),
              ),
              child: Text(
                _selectedPlan == '7Days'
                    ? 'Short access plan selected: ${_formatCurrencyAmount(widget.sevenDayAmount, _localCurrency)} for 7-day use.'
                    : _isSubscriptionPlan(_selectedPlan)
                        ? 'Offer active: Pay for 10 months (${_formatCurrencyAmount(_monthlyForPlan(_selectedPlan) * 10, _localCurrency)}) and get 12 months access.'
                        : 'One-time Lifetime plan payment: ${_formatCurrencyAmount(widget.lifetimePlanAmount, _localCurrency)}.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C3D63),
                ),
              ),
            ),
          if (_selectedPlan != 'Basic') const SizedBox(height: 10),
          if (_lastCheckoutResponse != null) ...[
            _buildCheckoutResponseCard(),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_submitting || _creatingPaymentLink) ? null : () => _continueToPayment(context),
              icon: const Icon(Icons.payments_rounded, size: 22),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _submitting ? 'Creating Checkout...' : 'Continue to Payment',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF123A63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                shadowColor: const Color(0xFF123A63).withValues(alpha: 0.28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_submitting || _creatingPaymentLink) ? null : () => _createPaymentLink(context),
              icon: const Icon(Icons.link_rounded, size: 20),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _creatingPaymentLink ? 'Generating Payment Link...' : 'Generate Razorpay Payment Link',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF123A63),
                side: const BorderSide(color: Color(0xFFD0DCEC)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                backgroundColor: const Color(0xFFFCFEFF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To view your quota details or upgrade later, open User Account after sign up/sign in.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
