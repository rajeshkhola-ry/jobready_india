/// API Configuration and Service Layer
/// Future-ready for advertisements, analytics, app links, and third-party integrations

enum ApiEnvironment { development, staging, production }

class ApiConfig {
  static const ApiEnvironment environment = ApiEnvironment.production;

  // ==================== BASE URLs ====================
  static String get baseUrl {
    switch (environment) {
      case ApiEnvironment.development:
        return 'http://localhost:8080/api/v1';
      case ApiEnvironment.staging:
        return 'https://staging-api.getreadyjob.com/api/v1';
      case ApiEnvironment.production:
        return 'https://api.getreadyjob.com/api/v1';
    }
  }

  // ==================== ANALYTICS ====================
  static const String analyticsEndpoint = '/analytics';
  static const String eventsEndpoint = '/events';

  // Supported events: app_open, tool_used, file_processed, error, ad_shown, etc.
  static const List<String> supportedEvents = [
    'app_open',
    'tool_used',
    'file_processed',
    'compression_completed',
    'conversion_completed',
    'merge_completed',
    'split_completed',
    'error_occurred',
    'ad_shown',
    'ad_clicked',
    'user_signup',
    'user_login',
  ];

  // ==================== ADVERTISEMENTS ====================
  /// Ad Network Configurations (ready for integration)
  static const String admobAppId = 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy'; // Update with real ID
  static const String admobBannerId = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String admobInterstitialId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const String admobRewardedId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID

  /// Facebook Ads (future integration)
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String facebookPlacementId = 'YOUR_FACEBOOK_PLACEMENT_ID';

  /// MoPub (future integration)
  static const String mopubAdUnitId = 'YOUR_MOPUB_AD_UNIT_ID';

  // ==================== APP LINKS & DEEPLINKS ====================
  static const String appLinkBaseUrl = 'https://getreadyjob.com';
  static const String appDeepLinkScheme = 'jobready://';

  static const Map<String, String> deepLinks = {
    'compress': 'jobready://tool/compress',
    'convert': 'jobready://tool/convert',
    'merge': 'jobready://tool/merge',
    'split': 'jobready://tool/split',
    'settings': 'jobready://settings',
    'about': 'jobready://about',
  };

  // ==================== EXTERNAL APP LINKS ====================
  static const String websiteUrl = 'https://getreadyjob.com';
  static const String supportEmailUrl = 'https://getreadyjob.com/support';
  static const String privacyPolicyUrl = 'https://getreadyjob.com/privacy';
  static const String termsOfServiceUrl = 'https://getreadyjob.com/terms';

  // Play Store / App Store Links
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.jobready.app';
  static const String appStoreUrl =
      'https://apps.apple.com/app/jobready/id1234567890';

  // ==================== SOCIAL MEDIA LINKS ====================
  static const Map<String, String> socialLinks = {
    'website': 'https://getreadyjob.com',
    'email': 'rajesh.khola@outlook.com',
    'twitter': 'https://twitter.com/getreadyjob',
    'facebook': 'https://facebook.com/getreadyjob',
    'instagram': 'https://instagram.com/getreadyjob',
    'linkedin': 'https://linkedin.com/company/getreadyjob',
  };

  // ==================== CRASH REPORTING ====================
  /// Firebase Crashlytics (ready for integration)
  static const String firebaseProjectId = 'jobready-production';
  static const bool enableCrashReporting = true;

  // ==================== FEATURE FLAGS ====================
  static const Map<String, bool> featureFlags = {
    'ads_enabled': true,
    'premium_enabled': true,
    'offline_mode': true,
    'dark_mode': true,
    'email_otp_enabled': false,
    'beta_features': false,
  };

  // ==================== API ENDPOINTS ====================
  /// Compression Service Endpoints
  static const String compressionEndpoint = '/files/compress';
  static const String compressionStatusEndpoint = '/files/compress/status';

  /// Conversion Service Endpoints
  static const String conversionEndpoint = '/files/convert';
  static const String conversionStatusEndpoint = '/files/convert/status';

  /// Merge Service Endpoints
  static const String mergeEndpoint = '/files/merge';
  static const String mergeStatusEndpoint = '/files/merge/status';

  /// Split Service Endpoints
  static const String splitEndpoint = '/files/split';
  static const String splitStatusEndpoint = '/files/split/status';

  /// User & Auth Endpoints
  static const String authEndpoint = '/auth';
  static const String otpRequestEndpoint = '/auth/otp/request';
  static const String otpVerifyEndpoint = '/auth/otp/verify';
  static const String otpResendEndpoint = '/auth/otp/resend';
  static const String userProfileEndpoint = '/user/profile';
  static const String userStatsEndpoint = '/user/stats';

  /// Feedback & Support
  static const String feedbackEndpoint = '/feedback';
  static const String bugReportEndpoint = '/bug-report';

  // ==================== TIMEOUT & RETRY CONFIG ====================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // ==================== HEADERS ====================
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'JOBREADY/1.0 (Flutter)',
  };

  // ==================== VERSION INFO ====================
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
  static const int buildNumber = 1;

  // ==================== RATE LIMITS ====================
  static const int maxCompressionPerDay = 100; // Free tier
  static const int maxConversionPerDay = 50; // Free tier
  static const int maxMergePerDay = 50; // Free tier
  static const int maxSplitPerDay = 50; // Free tier

  // ==================== FILE SIZE LIMITS ====================
  static const int maxFileSize = 500 * 1024 * 1024; // 500MB
  static const int maxCompressionTargetSize = 100 * 1024 * 1024; // 100MB
  static const int minCompressionTargetSize = 100 * 1024; // 100KB

  // ==================== PROMO & MONETIZATION ====================
  static const String promoCodeEndpoint = '/promo-codes';
  static const String subscriptionEndpoint = '/subscriptions';
  static const String purchaseEndpoint = '/purchases';
  static const String paymentCreateOrderEndpoint = '/payments/create-order';
  static const String paymentVerifyEndpoint = '/payments/verify';
  static const String paymentWebhookEndpoint = '/payments/webhook';
  static const String adInventoryEndpoint = '/ads/inventory';
  static const String adClickEndpoint = '/ads/click';
  static const String adImpressionEndpoint = '/ads/impression';
  static const String integrationManifestEndpoint = '/integrations/manifest';
  static const String integrationExecuteEndpoint = '/integrations/execute';

  /// Payment gateway defaults (manual configuration point)
  static const Map<String, dynamic> paymentGatewayDefaults = {
    'active_gateway': 'ccavenue',
    'supported_gateways': ['ccavenue', 'razorpay', 'paypal', 'stripe'],
    'currency': 'USD',
    'ccavenue': {
      'merchant_id': 'UPDATE_CCAVENUE_MERCHANT_ID',
      'access_code': 'UPDATE_CCAVENUE_ACCESS_CODE',
      'working_key': 'UPDATE_CCAVENUE_WORKING_KEY',
      'redirect_url': 'https://api.getreadyjob.com/api/v1/payments/callback',
      'cancel_url': 'https://api.getreadyjob.com/api/v1/payments/cancel',
    },
    'razorpay': {
      'key_id': 'UPDATE_RAZORPAY_KEY_ID',
      'key_secret': 'UPDATE_RAZORPAY_KEY_SECRET',
      'webhook_secret': 'UPDATE_RAZORPAY_WEBHOOK_SECRET',
      'redirect_url': 'https://api.getreadyjob.com/api/v1/payments/callback',
    },
    'paypal': {
      'client_id': 'UPDATE_PAYPAL_CLIENT_ID',
      'client_secret': 'UPDATE_PAYPAL_CLIENT_SECRET',
      'environment': 'live',
      'redirect_url': 'https://api.getreadyjob.com/api/v1/payments/callback',
      'cancel_url': 'https://api.getreadyjob.com/api/v1/payments/cancel',
    },
    'stripe': {
      'publishable_key': 'UPDATE_STRIPE_PUBLISHABLE_KEY',
      'secret_key': 'UPDATE_STRIPE_SECRET_KEY',
      'webhook_secret': 'UPDATE_STRIPE_WEBHOOK_SECRET',
      'redirect_url': 'https://api.getreadyjob.com/api/v1/payments/callback',
    },
  };

  static List<String> get supportedPaymentGateways {
    final gateways = paymentGatewayDefaults['supported_gateways'];
    if (gateways is List) {
      return gateways.map((item) => item.toString().toLowerCase()).toList();
    }
    return const ['ccavenue'];
  }

  static bool isSupportedPaymentGateway(String gateway) {
    return supportedPaymentGateways.contains(gateway.toLowerCase());
  }

  /// Ad linking defaults (manual configuration point)
  static const Map<String, dynamic> adLinkDefaults = {
    'active_provider': 'admob',
    'providers': {
      'admob': {
        'banner_unit_id': 'ca-app-pub-3940256099942544/6300978111',
        'interstitial_unit_id': 'ca-app-pub-3940256099942544/1033173712',
      },
      'ccavenue_affiliate': {
        'enabled': false,
        'banner_url': 'https://example.com/ccavenue-affiliate-banner',
      },
    },
  };

  /// Integration Hub defaults (manual configuration point)
  /// Add/edit connected apps here, or serve the same structure from backend manifest API.
  static const Map<String, dynamic> integrationHubDefaults = {
    'version': '1.0',
    'auto_sync_from_api': true,
    'apps': [
      {
        'id': 'ccavenue',
        'name': 'CCAvenue Payments',
        'enabled': true,
        'base_url': 'https://api.ccavenue.com',
        'auth_type': 'api_key',
        'auth': {
          'type': 'api_key',
          'header_name': 'X-Api-Key',
          'secret_ref': 'CCAVENUE_API_KEY',
          'token': 'UPDATE_CCAVENUE_API_KEY',
        },
        'actions': [
          {
            'id': 'create_order',
            'path': '/orders',
            'method': 'POST',
            'description': 'Create payment order from JOBREADY app',
          },
          {
            'id': 'verify_payment',
            'path': '/payments/verify',
            'method': 'POST',
            'description': 'Verify payment callback status',
          },
        ],
      },
      {
        'id': 'zapier',
        'name': 'Zapier Automation',
        'enabled': true,
        'base_url': 'https://hooks.zapier.com',
        'auth_type': 'none',
        'auth': {
          'type': 'none',
        },
        'actions': [
          {
            'id': 'send_event',
            'path': '/hooks/catch',
            'method': 'POST',
            'description': 'Send JOBREADY events to external workflows',
          },
        ],
      },
      {
        'id': 'stripe',
        'name': 'Stripe Billing',
        'enabled': false,
        'base_url': 'https://api.stripe.com/v1',
        'auth_type': 'bearer',
        'auth': {
          'type': 'bearer',
          'secret_ref': 'STRIPE_SECRET_KEY',
          'token': 'UPDATE_STRIPE_SECRET_KEY',
        },
        'actions': [
          {
            'id': 'create_checkout_session',
            'path': '/checkout/sessions',
            'method': 'POST',
            'description': 'Create checkout session for paid plan',
          },
        ],
      },
      {
        'id': 'salesforce',
        'name': 'Salesforce CRM',
        'enabled': false,
        'base_url': 'https://your-domain.my.salesforce.com/services/data/v60.0',
        'auth_type': 'oauth2',
        'auth': {
          'type': 'oauth2',
          'client_id': 'UPDATE_SF_CLIENT_ID',
          'secret_ref': 'SF_CLIENT_SECRET',
          'client_secret': 'UPDATE_SF_CLIENT_SECRET',
          'token_url': 'https://login.salesforce.com/services/oauth2/token',
          'scope': 'api refresh_token',
          'access_token': 'UPDATE_RUNTIME_ACCESS_TOKEN',
          'refresh_token': 'UPDATE_RUNTIME_REFRESH_TOKEN',
        },
        'actions': [
          {
            'id': 'send_event',
            'path': '/sobjects/Lead',
            'method': 'POST',
            'description': 'Create lead in CRM from JOBREADY user flow',
          },
        ],
      },
    ],
  };

  /// Ad Placement Strategy
  static const Map<String, dynamic> adStrategy = {
    'banner_home': {'frequency': 'always', 'position': 'bottom'},
    'interstitial_after_compress': {'frequency': 'every_3rd_use', 'delay': 2000},
    'interstitial_after_convert': {'frequency': 'every_3rd_use', 'delay': 2000},
    'rewarded_after_5_uses': {'frequency': 'every_5th_use', 'reward': 'ad_free_hour'},
  };
}

/// API Service Manager - Centralized API handling
class ApiService {
  static const String logTag = 'ApiService';
  static String? _activePaymentGatewayOverride;

  static String getActivePaymentGateway() {
    return (_activePaymentGatewayOverride ??
            ApiConfig.paymentGatewayDefaults['active_gateway']?.toString() ??
            'ccavenue')
        .toLowerCase();
  }

  static List<String> getSupportedPaymentGateways() {
    return ApiConfig.supportedPaymentGateways;
  }

  static Map<String, dynamic> setActivePaymentGateway(String gateway) {
    final normalized = gateway.toLowerCase();
    if (!ApiConfig.isSupportedPaymentGateway(normalized)) {
      return {
        'status': 'error',
        'gateway': gateway,
        'message':
            'Unsupported gateway. Supported: ${ApiConfig.supportedPaymentGateways.join(', ')}',
      };
    }

    _activePaymentGatewayOverride = normalized;
    return {
      'status': 'success',
      'gateway': normalized,
      'message': 'Active payment gateway set to $normalized',
    };
  }

  /// Log API request (for debugging/analytics)
  static Future<void> logApiRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
  }) async {
    print('[$logTag] $method $endpoint');
    if (data != null) {
      print('[$logTag] Payload: $data');
    }
  }

  /// Log API response
  static Future<void> logApiResponse({
    required String endpoint,
    required int statusCode,
    dynamic response,
  }) async {
    print('[$logTag] Response [$statusCode]: $endpoint');
    if (response != null) {
      print('[$logTag] Body: $response');
    }
  }

  /// Log analytics event
  static Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!ApiConfig.supportedEvents.contains(eventName)) {
      print('[$logTag] Warning: Unknown event - $eventName');
      return;
    }

    print('[$logTag] Event logged: $eventName');
    if (parameters != null) {
      print('[$logTag] Parameters: $parameters');
    }

    // TODO: Send to Analytics endpoint
    // Example: POST /api/v1/analytics/events
  }

  /// Get compression estimate
  static Future<Map<String, dynamic>> getCompressionEstimate({
    required int originalSize,
    required int targetSize,
  }) async {
    // Placeholder for future API call
    return {
      'status': 'success',
      'estimate_time_seconds': 5,
      'quality_score': 92,
      'compression_ratio': 0.45,
    };
  }

  /// Check ad eligibility (for frequency capping)
  static Future<bool> isEligibleForAd({
    required String adPlacement,
  }) async {
    // TODO: Check against frequency cap rules
    return true;
  }

  /// Get ad payload for a fixed placement, ready to link with provider/backend.
  static Future<Map<String, dynamic>> getAdPlacementPayload({
    required String adPlacement,
  }) async {
    final strategy = ApiConfig.adStrategy[adPlacement] as Map<String, dynamic>?;
    final provider = ApiConfig.adLinkDefaults['active_provider'];

    await logApiRequest(
      endpoint: ApiConfig.adInventoryEndpoint,
      method: 'GET',
      data: {
        'placement': adPlacement,
        'provider': provider,
      },
    );

    return {
      'status': 'success',
      'placement': adPlacement,
      'provider': provider,
      'strategy': strategy,
      'fallback_title': 'Sponsored',
      'fallback_text': 'Partner offer space (fixed slot).',
      'target_url': 'https://getreadyjob.com',
      'unit_id': ApiConfig.admobBannerId,
    };
  }

  /// Track ad interactions for analytics and billing reconciliation.
  static Future<void> trackAdInteraction({
    required String adPlacement,
    required String interactionType,
    String? adId,
    String? provider,
  }) async {
    await logApiRequest(
      endpoint: interactionType == 'click'
          ? ApiConfig.adClickEndpoint
          : ApiConfig.adImpressionEndpoint,
      method: 'POST',
      data: {
        'placement': adPlacement,
        'interaction_type': interactionType,
        'ad_id': adId,
        'provider': provider ?? ApiConfig.adLinkDefaults['active_provider'],
        'ts': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Fetch integration manifest from API with local fallback.
  static Future<Map<String, dynamic>> getIntegrationManifest() async {
    await logApiRequest(
      endpoint: ApiConfig.integrationManifestEndpoint,
      method: 'GET',
    );

    // Placeholder: backend can replace this with live manifest.
    return ApiConfig.integrationHubDefaults;
  }

  /// Generic integration executor.
  /// Any future external app action can be sent through this payload without changing app UI code.
  static Future<Map<String, dynamic>> executeIntegrationAction({
    required String appId,
    required String actionId,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? authConfig,
  }) async {
    final resolvedAuth = _resolveIntegrationAuth(authConfig);
    final requestPayload = {
      'app_id': appId,
      'action_id': actionId,
      'payload': payload,
      'auth': resolvedAuth,
      'requested_at': DateTime.now().toIso8601String(),
    };

    await logApiRequest(
      endpoint: ApiConfig.integrationExecuteEndpoint,
      method: 'POST',
      data: requestPayload,
    );

    // Placeholder response until backend endpoint is connected.
    return {
      'status': 'success',
      'app_id': appId,
      'action_id': actionId,
      'request_echo': payload,
      'auth_type': resolvedAuth['type'],
      'message': 'Integration action queued. Connect backend to execute real API call.',
    };
  }

  static Map<String, dynamic> _resolveIntegrationAuth(
    Map<String, dynamic>? authConfig,
  ) {
    if (authConfig == null || authConfig.isEmpty) {
      return {'type': 'none'};
    }

    final type = authConfig['type']?.toString().toLowerCase() ?? 'none';
    if (type == 'none') {
      return {'type': 'none'};
    }

    if (type == 'api_key') {
      return {
        'type': 'api_key',
        'header_name': authConfig['header_name']?.toString() ?? 'X-Api-Key',
        'secret_ref': authConfig['secret_ref']?.toString() ?? 'UNSPECIFIED_SECRET_REF',
      };
    }

    if (type == 'bearer') {
      return {
        'type': 'bearer',
        'secret_ref': authConfig['secret_ref']?.toString() ?? 'UNSPECIFIED_SECRET_REF',
      };
    }

    if (type == 'oauth2') {
      return {
        'type': 'oauth2',
        'client_id': authConfig['client_id']?.toString() ?? '',
        'token_url': authConfig['token_url']?.toString() ?? '',
        'scope': authConfig['scope']?.toString() ?? '',
        'secret_ref': authConfig['secret_ref']?.toString() ?? 'UNSPECIFIED_SECRET_REF',
      };
    }

    return {'type': type};
  }

  /// Get promo code validation
  static Future<Map<String, dynamic>> validatePromoCode({
    required String promoCode,
  }) async {
    // Placeholder for promo validation
    return {
      'valid': true,
      'discount_percent': 20,
      'expiry_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
    };
  }

  /// Create payment order payload for selected gateway
  static Future<Map<String, dynamic>> createPaymentOrder({
    required String gateway,
    required String planId,
    required double amount,
    String currency = 'USD',
    required String customerEmail,
    String? customerName,
    String? customerPhone,
    Map<String, dynamic>? metadata,
  }) async {
    final normalizedGateway = gateway.toLowerCase();
    if (!ApiConfig.isSupportedPaymentGateway(normalizedGateway)) {
      return {
        'status': 'error',
        'gateway': gateway,
        'message':
            'Unsupported gateway. Supported: ${ApiConfig.supportedPaymentGateways.join(', ')}',
      };
    }

    final payload = {
      'gateway': normalizedGateway,
      'plan_id': planId,
      'amount': amount,
      'currency': currency,
      'customer': {
        'email': customerEmail,
        'name': customerName,
        'phone': customerPhone,
      },
      'metadata': metadata ?? <String, dynamic>{},
    };

    await logApiRequest(
      endpoint: ApiConfig.paymentCreateOrderEndpoint,
      method: 'POST',
      data: payload,
    );

    // Placeholder response until backend endpoint is connected.
    return {
      'status': 'success',
      'gateway': normalizedGateway,
      'order_id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      'checkout_url':
        '${ApiConfig.baseUrl}${ApiConfig.paymentCreateOrderEndpoint}?gateway=$normalizedGateway',
      'currency': currency,
      'amount': amount,
      'message': 'Payment order created. Connect backend to return real checkout URL.',
    };
  }

  /// Verify payment status after gateway callback/webhook
  static Future<Map<String, dynamic>> verifyPayment({
    required String gateway,
    required String orderId,
    required String transactionId,
    String? signature,
  }) async {
    final normalizedGateway = gateway.toLowerCase();
    if (!ApiConfig.isSupportedPaymentGateway(normalizedGateway)) {
      return {
        'status': 'error',
        'gateway': gateway,
        'verified': false,
        'message':
            'Unsupported gateway. Supported: ${ApiConfig.supportedPaymentGateways.join(', ')}',
      };
    }

    final payload = {
      'gateway': normalizedGateway,
      'order_id': orderId,
      'transaction_id': transactionId,
      'signature': signature,
    };

    await logApiRequest(
      endpoint: ApiConfig.paymentVerifyEndpoint,
      method: 'POST',
      data: payload,
    );

    // Placeholder response until backend endpoint is connected.
    return {
      'status': 'success',
      'verified': true,
      'order_id': orderId,
      'transaction_id': transactionId,
      'gateway': normalizedGateway,
      'message': 'Payment verification simulated. Connect backend for cryptographic verification.',
    };
  }

  /// Request OTP for email verification/login.
  static Future<Map<String, dynamic>> requestEmailOtp({
    required String email,
    String purpose = 'login',
  }) async {
    final payload = {
      'email': email,
      'purpose': purpose,
      'channel': 'email',
      'requested_at': DateTime.now().toIso8601String(),
    };

    await logApiRequest(
      endpoint: ApiConfig.otpRequestEndpoint,
      method: 'POST',
      data: payload,
    );

    // Placeholder response until backend endpoint is connected.
    return {
      'status': 'success',
      'email': email,
      'purpose': purpose,
      'otp_reference': 'OTP-${DateTime.now().millisecondsSinceEpoch}',
      'message': 'OTP request created. Connect backend mail provider to send real OTP.',
    };
  }

  /// Verify OTP entered by user.
  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otpCode,
    String? otpReference,
  }) async {
    final payload = {
      'email': email,
      'otp_code': otpCode,
      'otp_reference': otpReference,
      'verified_at': DateTime.now().toIso8601String(),
    };

    await logApiRequest(
      endpoint: ApiConfig.otpVerifyEndpoint,
      method: 'POST',
      data: payload,
    );

    // Placeholder verification rule until backend endpoint is connected.
    final isValidShape = RegExp(r'^\d{6}$').hasMatch(otpCode);

    return {
      'status': isValidShape ? 'success' : 'error',
      'email': email,
      'verified': isValidShape,
      'message': isValidShape
          ? 'OTP format accepted. Connect backend for real OTP verification.'
          : 'Invalid OTP format. Enter a 6-digit OTP.',
    };
  }

  /// Resend OTP to the same email.
  static Future<Map<String, dynamic>> resendEmailOtp({
    required String email,
    String? otpReference,
  }) async {
    final payload = {
      'email': email,
      'otp_reference': otpReference,
      'resend_at': DateTime.now().toIso8601String(),
    };

    await logApiRequest(
      endpoint: ApiConfig.otpResendEndpoint,
      method: 'POST',
      data: payload,
    );

    // Placeholder response until backend endpoint is connected.
    return {
      'status': 'success',
      'email': email,
      'otp_reference': otpReference ?? 'OTP-${DateTime.now().millisecondsSinceEpoch}',
      'message': 'OTP resend queued. Connect backend mail provider for real delivery.',
    };
  }

  /// Submit feedback
  static Future<bool> submitFeedback({
    required String feedbackText,
    required double rating,
  }) async {
    print('[$logTag] Submitting feedback: $feedbackText (Rating: $rating)');
    // TODO: POST to /api/v1/feedback
    return true;
  }

  /// Report bug
  static Future<bool> reportBug({
    required String bugDescription,
    required String stackTrace,
  }) async {
    print('[$logTag] Reporting bug: $bugDescription');
    // TODO: POST to /api/v1/bug-report
    return true;
  }
}

/// Example Usage
/*
// Logging an event
await ApiService.logEvent(
  eventName: 'compression_completed',
  parameters: {
    'original_size_mb': 50,
    'compressed_size_mb': 20,
    'quality_score': 92,
    'time_seconds': 5,
  },
);

// Getting compression estimate
final estimate = await ApiService.getCompressionEstimate(
  originalSize: 50 * 1024 * 1024,
  targetSize: 20 * 1024 * 1024,
);

// Checking ad eligibility
final canShowAd = await ApiService.isEligibleForAd(
  adPlacement: 'interstitial_after_compress',
);

// Validating promo code
final promoValidation = await ApiService.validatePromoCode(
  promoCode: 'SAVE20',
);
*/
