import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Widgets/why_choose_card.dart';
import '../Widgets/glowing_logo_badge.dart';
import '../Widgets/upload_card_v2.dart';
import '../Widgets/tool_selector_v2.dart';
import '../Services/public_brand_config.dart';
import '../Services/api_config.dart';
import '../Services/coupon_service.dart';
import '../Services/document_history_service.dart';
import '../Services/integration_hub_service.dart';
import '../Services/owner_admin_access_service.dart';
import '../Services/plan_catalog_service.dart';
import '../Services/support_ticket_service.dart';
import '../Services/user_rating_service.dart';
import '../Services/user_account_service.dart';
import '../Services/user_auth_service.dart';
import '../Services/usage_quota_service.dart';
import '../Services/razorpay_service.dart';
import '../Widgets/user_auth_dialog.dart';
import '../Widgets/ai_resume_feature_banner.dart';
import '../Widgets/brand_logo_button.dart';
import '../Widgets/production_footer.dart';
import 'ai_resume_builder_page.dart';
import 'compression_benchmark_page.dart';
import 'compression_tool_page.dart';
import 'convert_tool_page.dart';
import 'launch_readiness_page.dart';
import 'launch_runbook_page.dart';
import 'merge_tool_page.dart';
import 'pdf_edit_page.dart';
import 'plan_features_page.dart';
import 'post_launch_control_page.dart';
import 'split_tool_page.dart';
import 'system_check_page.dart';
import 'terms_conditions_page.dart';
import 'v2/photo/photo_hd_workspace_page.dart';

const Map<String, String> _paymentCurrencyLabels = {
  'USD': 'US Dollar (USD)',
  'INR': 'Indian Rupee (INR)',
  'EUR': 'Euro (EUR)',
  'GBP': 'British Pound (GBP)',
  'AED': 'UAE Dirham (AED)',
  'SAR': 'Saudi Riyal (SAR)',
  'CAD': 'Canadian Dollar (CAD)',
  'AUD': 'Australian Dollar (AUD)',
  'SGD': 'Singapore Dollar (SGD)',
  'JPY': 'Japanese Yen (JPY)',
  'CNY': 'Chinese Yuan (CNY)',
  'HKD': 'Hong Kong Dollar (HKD)',
  'NZD': 'New Zealand Dollar (NZD)',
  'CHF': 'Swiss Franc (CHF)',
  'ZAR': 'South African Rand (ZAR)',
  'SEK': 'Swedish Krona (SEK)',
  'NOK': 'Norwegian Krone (NOK)',
  'DKK': 'Danish Krone (DKK)',
  'MYR': 'Malaysian Ringgit (MYR)',
  'THB': 'Thai Baht (THB)',
  'OTHER': 'Other countries (USD rates applicable)',
};

const Map<String, double> _paymentCurrencyRates = {
  'USD': 1.0,
  'EUR': 0.92,
  'GBP': 0.78,
  'AED': 3.67,
  'SAR': 3.75,
  'CAD': 1.37,
  'AUD': 1.52,
  'SGD': 1.35,
  'JPY': 158.0,
  'CNY': 7.26,
  'HKD': 7.81,
  'NZD': 1.66,
  'CHF': 0.89,
  'ZAR': 18.1,
  'SEK': 10.5,
  'NOK': 10.7,
  'DKK': 6.86,
  'MYR': 4.7,
  'THB': 36.3,
  'OTHER': 1.0,
};

const Map<String, String> _paymentCurrencySymbols = {
  'USD': '\$',
  'INR': '₹',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'SGD': 'S\$',
  'JPY': '¥',
  'CNY': '¥',
  'HKD': 'HK\$',
  'NZD': 'NZ\$',
  'CHF': 'CHF ',
  'ZAR': 'R ',
  'SEK': 'SEK ',
  'NOK': 'NOK ',
  'DKK': 'DKK ',
  'MYR': 'RM ',
  'THB': '฿',
    'OTHER': '\$',
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

String resolvePreferredPaymentCurrency({
  String? storedCurrency,
  String? profileCountry,
  String? browserLanguage,
}) {
  final normalizedStoredCurrency = (storedCurrency ?? '').trim().toUpperCase();
  if (normalizedStoredCurrency.isNotEmpty && _paymentCurrencyLabels.containsKey(normalizedStoredCurrency)) {
    return normalizedStoredCurrency;
  }

  final normalizedCountry = (profileCountry ?? '').trim().toLowerCase();
  final normalizedCountryCode = (profileCountry ?? '').trim().toUpperCase();
  final normalizedBrowserLanguage = (browserLanguage ?? '').trim().toLowerCase();

  final isIndia = normalizedCountry.contains('india') ||
      normalizedCountryCode == 'IN' ||
      normalizedBrowserLanguage == 'hi' ||
      normalizedBrowserLanguage.startsWith('hi-') ||
      normalizedBrowserLanguage.contains('en-in') ||
      normalizedBrowserLanguage.endsWith('-in') ||
      normalizedBrowserLanguage.contains('-in');

  return isIndia ? 'INR' : 'USD';
}

class HomePageV2 extends StatefulWidget {
  const HomePageV2({super.key});

  @override
  State<HomePageV2> createState() => _HomePageV2State();
}

class _HomePageV2State extends State<HomePageV2> {
  int _pricingDiscountPercent = 0;
  String _activeGateway = ApiService.getActivePaymentGateway();
  String _selectedPlanForPayment = 'Free';
  String _selectedPaymentCurrency = 'USD';
  String? _selectedUsageType;
  bool _showLiveOfferBanner = false;
  String _liveOfferText = '';
  bool _showCookieConsentBanner = false;
  late PlanCatalogConfig _planCatalog;
  bool get _showAdminControls => OwnerAdminAccessService.isUnlocked;

  // Manual pricing control: update these values any time.
  // INR Pricing
  static const double _sevenDayPlanInr = 49.0;
  static const double _monthlyPlanInr = 99.0;
  static const double _yearlyPlanInr = 799.0;
  static const double _lifetimePlanInr = 1999.0;

  // USD Pricing
  static const double _sevenDayPlanUsd = 0.99;
  static const double _monthlyPlanUsd = 1.99;
  static const double _yearlyPlanUsd = 14.99;
  static const double _lifetimePlanUsd = 39.0;

  static const double _businessIncreaseMultiplier = 1.75;

  @override
  void initState() {
    super.initState();
    _planCatalog = PlanCatalogService.load();
    _showCookieConsentBanner = !_hasAcceptedCookieConsent();
    _selectedPaymentCurrency = _resolveInitialPaymentCurrency();
  }

  String _resolveInitialPaymentCurrency() {
    final profile = UserAccountService.getProfile();
    final browserLanguage = html.window.navigator.language;
    final storedCurrency = _getStoredPaymentCurrency();
    return resolvePreferredPaymentCurrency(
      storedCurrency: storedCurrency,
      profileCountry: profile.country,
      browserLanguage: browserLanguage,
    );
  }

  bool _hasAcceptedCookieConsent() {
    final storedValue = html.window.localStorage['jobready_cookie_consent'];
    return storedValue == 'accepted';
  }

  String _getStoredPaymentCurrency() {
    final storedValue = html.window.localStorage['jobready_payment_currency'];
    final normalizedValue = (storedValue ?? '').trim().toUpperCase();
    return normalizedValue;
  }

  void _persistPaymentCurrency(String currency) {
    html.window.localStorage['jobready_payment_currency'] = currency;
  }

  void _acceptCookieConsent() {
    html.window.localStorage['jobready_cookie_consent'] = 'accepted';
    setState(() {
      _showCookieConsentBanner = false;
    });
  }

  double _priceForUsage(double personalMonthlyPrice) {
    if (_selectedUsageType == 'Business') {
      return personalMonthlyPrice * _businessIncreaseMultiplier;
    }
    return personalMonthlyPrice;
  }

  double _baseUsdPriceForPlan(String plan) {
    final configured = _planCatalog.usdPrices[plan];
    if (configured != null) {
      return configured;
    }

    switch (plan) {
      case '7Days':
        return _sevenDayPlanUsd;
      case 'Monthly':
        return _monthlyPlanUsd;
      case 'Yearly':
        return _yearlyPlanUsd;
      case 'Lifetime':
        return _lifetimePlanUsd;
      default:
        return 0;
    }
  }

  double _baseInrPriceForPlan(String plan) {
    final configured = _planCatalog.inrPrices[plan];
    if (configured != null) {
      return configured;
    }

    switch (plan) {
      case '7Days':
        return _sevenDayPlanInr;
      case 'Monthly':
        return _monthlyPlanInr;
      case 'Yearly':
        return _yearlyPlanInr;
      case 'Lifetime':
        return _lifetimePlanInr;
      default:
        return 0;
    }
  }

  double _displayAmountForPlan(String plan, String currencyCode) {
    if (plan == 'Free') {
      return 0;
    }

    if (currencyCode == 'INR') {
      return _priceForUsage(_baseInrPriceForPlan(plan));
    }

    final usdBase = _priceForUsage(_baseUsdPriceForPlan(plan));
    final rate = _paymentCurrencyRates[currencyCode] ?? 1.0;
    return usdBase * rate;
  }

  String _planPriceLine(String plan, String suffix) {
    final inrAmount = _displayAmountForPlan(plan, 'INR');
    if (_selectedPaymentCurrency == 'INR') {
      return '${_formatCurrencyAmount(inrAmount, 'INR')}$suffix';
    }

    final converted = _displayAmountForPlan(plan, _selectedPaymentCurrency);
    return '${_formatCurrencyAmount(inrAmount, 'INR')} / ${_formatCurrencyAmount(converted, _selectedPaymentCurrency)}$suffix';
  }

  void _openMailComposer({required String subject, required String body}) {
    final mailto =
        '${PublicBrandConfig.supportEmailMailto}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    html.window.open(mailto, '_blank');
  }

  void _showSuggestionDialog() {
    final suggestionController = TextEditingController();
    String selectedType = 'Suggestion';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Send Issue / Suggestion / Query'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'Issue', child: Text('Issue')),
                    DropdownMenuItem(value: 'Suggestion', child: Text('Suggestion')),
                    DropdownMenuItem(value: 'Query', child: Text('Query')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedType = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ticket Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: suggestionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write your issue, suggestion, or query here',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A ticket number will be generated automatically for your record.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = suggestionController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please write your message first.')),
                  );
                  return;
                }

                final ticket = await SupportTicketService.createTicket(
                  type: selectedType,
                  message: message,
                  source: 'V1 app (merged)',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                if (!mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _openMailComposer(
                  subject: 'GETREADYJOB $selectedType - ${ticket.ticketNumber}',
                  body:
                      'Ticket Number: ${ticket.ticketNumber}\nType: ${ticket.type}\nSource: ${ticket.source}\nCreated: ${ticket.createdAtIso}\n\nMessage:\n$message',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ticket ${ticket.ticketNumber} created. Mailbox opened for send.',
                    ),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    ).then((_) {
      suggestionController.dispose();
    });
  }

  Future<void> _showQuickPanel(Widget child) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _handleUsageMenu(String value) async {
    switch (value) {
      case 'view':
        await _showQuickPanel(const _DailyUsageQuotaSection());
        break;
      case 'reset':
        await UsageQuotaService.clearToday();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today usage counters cleared.')),
        );
        break;
    }
  }

  Future<void> _handleRecentDocumentsMenu(String value) async {
    if (value == 'open') {
      await _showQuickPanel(const _RecentDocumentsSection());
      return;
    }

    if (value == 'clear') {
      await DocumentHistoryService.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recent document history cleared.')),
      );
      return;
    }

    if (value.startsWith('keep:')) {
      final limit = int.tryParse(value.split(':').last);
      if (limit == null) {
        return;
      }
      await DocumentHistoryService.setRetentionLimit(limit);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('History retention updated to last $limit entries.')),
      );
    }
  }

  Future<void> _openUserLoginPanel() async {
    if (UserAuthService.isSignedIn) {
      await _showPostLoginPrompt();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => UserAuthDialog(
        stayOnHomeAfterAuth: true,
        onAuthenticated: (_, __) {
          if (!mounted) {
            return;
          }
          setState(() {});
          Future<void>.microtask(_showPostLoginPrompt);
        },
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showPostLoginPrompt() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('You are logged in'),
        content: const Text(
          'You are logged in successfully. If you want to go to your user account, press User Account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Stay on Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!mounted) {
                return;
              }
              Navigator.of(context).pushNamed('/dashboard');
            },
            child: const Text('User Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckoutFlow(String plan) async {
    final resolvedCurrency = _resolveInitialPaymentCurrency();
    setState(() {
      _selectedPlanForPayment = plan;
      _selectedPaymentCurrency = resolvedCurrency;
      _persistPaymentCurrency(resolvedCurrency);
    });

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SingleChildScrollView(
                    child: _UserPaymentPanel(
                      activeGateway: _activeGateway,
                      selectedPlan: _selectedPlanForPayment,
                      selectedCurrency: _selectedPaymentCurrency,
                      usageType: _selectedUsageType,
                      sevenDayAmount: _displayAmountForPlan('7Days', _selectedPaymentCurrency),
                      monthlyAmount: _displayAmountForPlan('Monthly', _selectedPaymentCurrency),
                      yearlyAmount: _displayAmountForPlan('Yearly', _selectedPaymentCurrency),
                      lifetimePlanAmount: _displayAmountForPlan('Lifetime', _selectedPaymentCurrency),
                      onPlanChanged: (value) {
                        setState(() {
                          _selectedPlanForPayment = value;
                        });
                      },
                      onCurrencyChanged: (value) {
                        setState(() {
                          _selectedPaymentCurrency = value;
                          _persistPaymentCurrency(value);
                        });
                      },
                      onUsageTypeChanged: (value) {
                        setState(() {
                          _selectedUsageType = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlanSelection(String plan) async {
    if (_selectedUsageType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Personal or Business first.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedPlanForPayment = plan;
    });

    if (UserAuthService.isSignedIn) {
      await _openCheckoutFlow(plan);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => UserAuthDialog(
        preselectedPlan: plan,
        stayOnHomeAfterAuth: true,
        onAuthenticated: (selectedPlan, _) {
          if (!mounted) {
            return;
          }
          setState(() {});
          if (selectedPlan == null || selectedPlan.trim().isEmpty) {
            return;
          }
          Future<void>.microtask(() => _openCheckoutFlow(selectedPlan));
        },
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevenDayPriceLine = _planPriceLine('7Days', ' for 7 days');
    final monthlyPriceLine = _planPriceLine('Monthly', ' per month');
    final yearlyPriceLine = _planPriceLine('Yearly', ' per year');
    final lifetimePriceLine = _planPriceLine('Lifetime', ' one-time');
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFEFF),
        foregroundColor: const Color(0xFF0F172A),
        centerTitle: true,
        toolbarHeight: 72,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFDCE7F3), width: 1),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openUserLoginPanel,
            icon: Icon(UserAuthService.isSignedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded, size: 16),
            label: const Text('User Login'),
            style: TextButton.styleFrom(
              foregroundColor: UserAuthService.isSignedIn ? const Color(0xFF166534) : const Color(0xFF334155),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _TopActionIcon(
            tooltip: 'Benchmark',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF3F648A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CompressionBenchmarkPage(),
                ),
              );
            },
          ),
          _TopActionIcon(
            tooltip: 'Readiness',
            icon: Icons.rocket_launch_rounded,
            iconColor: const Color(0xFF3C7A67),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LaunchReadinessPage(),
                ),
              );
            },
          ),
          _TopActionIcon(
            tooltip: 'Runbook',
            icon: Icons.task_alt_rounded,
            iconColor: const Color(0xFF4E5F96),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LaunchRunbookPage(),
                ),
              );
            },
          ),
          _TopActionIcon(
            tooltip: 'Post-Launch',
            icon: Icons.monitor_heart_rounded,
            iconColor: const Color(0xFF94664A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PostLaunchControlPage(),
                ),
              );
            },
          ),
          _TopActionIcon(
            tooltip: 'Support Email',
            icon: Icons.email_outlined,
            iconColor: const Color(0xFF7B5E2B),
            onTap: () {
              _openMailComposer(
                subject: 'GETREADYJOB Support Request',
                body: 'Hi GETREADYJOB Team,%0A%0APlease help me with:%0A',
              );
            },
          ),
          _TopActionIcon(
            tooltip: 'Terms & Conditions',
            icon: Icons.gavel_rounded,
            iconColor: const Color(0xFF6F5675),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsConditionsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoButton(
              size: 34,
              tooltip: 'Go to home',
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'GET READY JOB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFDBF4FF).withValues(alpha: 0.55),
                      const Color(0xFFDBF4FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE8FDE9).withValues(alpha: 0.60),
                      const Color(0xFFE8FDE9).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD8E6FA)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1490A3BE),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Upload one document or multiple files together and start working instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1D3557),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AiResumeFeatureBanner(activePlan: _selectedPlanForPayment),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FCFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8E6F7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1090A3BE),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Welcome to GETREADYJOB!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF244466),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _V2Column(),
                const SizedBox(height: 10),
                if (_showLiveOfferBanner && _liveOfferText.trim().isNotEmpty) ...[
                  _LiveOfferBanner(text: _liveOfferText),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                const SizedBox(height: 4),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFEFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDE7F1)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1290A3BE),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Ad Space',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                      _FixedAdSpace(adPlacement: 'banner_home'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _WhyChooseSection(),
                const SizedBox(height: 18),
                const _SectionHeader(
                  title: 'Plans',
                  subtitle: 'Simple access today, premium workspace upgrades coming next.',
                ),
                const SizedBox(height: 12),
                _UsageTypeSelector(
                  selectedType: _selectedUsageType,
                  onChanged: (value) {
                    setState(() {
                      _selectedUsageType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF7FCFF), Color(0xFFE9FDF3)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB9E9D0), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF0D7A5F),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Usage type required before payment',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF155E4A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select Personal or Business first, then continue with your plan. Annual access uses 10-month payment for 12 months.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E6A56),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PlanCardsSection(
                  selectedCurrency: _selectedPaymentCurrency,
                  sevenDayPriceLine: sevenDayPriceLine,
                  monthlyPriceLine: monthlyPriceLine,
                  yearlyPriceLine: yearlyPriceLine,
                  lifetimePriceLine: lifetimePriceLine,
                  enabledToolsByPlan: _planCatalog.enabledToolsByPlan,
                  discountPercent: _pricingDiscountPercent,
                  selectedPlan: _selectedPlanForPayment,
                  usageType: _selectedUsageType,
                  onPlanSelected: _handlePlanSelection,
                ),
                const SizedBox(height: 12),
                _UserPaymentPanel(
                  activeGateway: _activeGateway,
                  selectedPlan: _selectedPlanForPayment,
                  selectedCurrency: _selectedPaymentCurrency,
                  usageType: _selectedUsageType,
                  sevenDayAmount: _displayAmountForPlan('7Days', _selectedPaymentCurrency),
                  monthlyAmount: _displayAmountForPlan('Monthly', _selectedPaymentCurrency),
                  yearlyAmount: _displayAmountForPlan('Yearly', _selectedPaymentCurrency),
                  lifetimePlanAmount: _displayAmountForPlan('Lifetime', _selectedPaymentCurrency),
                  onPlanChanged: (plan) {
                    setState(() {
                      _selectedPlanForPayment = plan;
                    });
                  },
                  onCurrencyChanged: (currency) {
                    setState(() {
                      _selectedPaymentCurrency = currency;
                    });
                  },
                  onUsageTypeChanged: (usageType) {
                    setState(() {
                      _selectedUsageType = usageType;
                    });
                  },
                ),
                const SizedBox(height: 10),
                const _AboutUsSection(),
                const SizedBox(height: 10),
                const _FuturePlanSection(),
                const SizedBox(height: 10),
                const _UserRatingSection(),
                const SizedBox(height: 10),
                _SuggestionSection(
                  onTap: () {
                    _showSuggestionDialog();
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFEFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDCE7F3)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F2937).withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Daily usage options',
                        onSelected: _handleUsageMenu,
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'view',
                            child: Text('Open Daily Usage'),
                          ),
                          PopupMenuItem<String>(
                            value: 'reset',
                            child: Text('Reset Today Counters'),
                          ),
                        ],
                        child: _QuickAccessButton(
                          icon: Icons.tune_rounded,
                          label: 'Daily Usage',
                          accent: const Color(0xFF0F172A),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Recent documents options',
                        onSelected: _handleRecentDocumentsMenu,
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'open',
                            child: Text('Open Recent Documents'),
                          ),
                          PopupMenuItem<String>(
                            value: 'clear',
                            child: Text('Clear Recent Documents'),
                          ),
                          PopupMenuItem<String>(
                            value: 'keep:20',
                            child: Text('Keep 20'),
                          ),
                          PopupMenuItem<String>(
                            value: 'keep:50',
                            child: Text('Keep 50'),
                          ),
                          PopupMenuItem<String>(
                            value: 'keep:100',
                            child: Text('Keep 100'),
                          ),
                          PopupMenuItem<String>(
                            value: 'keep:200',
                            child: Text('Keep 200'),
                          ),
                        ],
                        child: _QuickAccessButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: 'Recent Documents',
                          accent: const Color(0xFF0F766E),
                        ),
                      ),
                      _QuickAccessActionButton(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin Login',
                        accent: const Color(0xFFB45309),
                        onTap: () {
                          Navigator.of(context).pushNamed('/admin');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    GlowingLogoBadge(size: 32, circular: true),
                  ],
                ),
                const SizedBox(height: 8),
                _FooterInfoRow(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  value: PublicBrandConfig.websiteDomain,
                ),
                const SizedBox(height: 8),
                _FooterInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Support',
                  value: PublicBrandConfig.supportEmail,
                ),
                const SizedBox(height: 12),
                const ProductionFooter(),
                const SizedBox(height: 6),
              ],
            ),
          ),
          if (_showCookieConsentBanner)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132238),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'We use essential local browser cache & cookies to keep tools fast and your sessions smooth. We do not store your uploaded files or images on our servers.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/terms');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFC72C),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                child: const Text('Read Terms & Conditions'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _acceptCookieConsent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC72C),
                                foregroundColor: const Color(0xFF111827),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('Accept & Continue'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickAccessActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedAdSpace extends StatefulWidget {
  final String adPlacement;

  const _FixedAdSpace({required this.adPlacement});

  @override
  State<_FixedAdSpace> createState() => _FixedAdSpaceState();
}

class _LiveOfferBanner extends StatelessWidget {
  final String text;

  const _LiveOfferBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7CC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_rounded, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyChooseAdSection extends StatelessWidget {
  const _WhyChooseAdSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (!isWide) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WhyChooseCard(scale: 0.6),
              SizedBox(height: 10),
              _FixedAdSpace(adPlacement: 'banner_why_choose_mobile'),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: WhyChooseCard(scale: 0.6),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _FixedAdSpace(adPlacement: 'banner_why_choose_top'),
                  SizedBox(height: 10),
                  _FixedAdSpace(adPlacement: 'banner_why_choose_bottom'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UsageTypeSelector extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String> onChanged;

  const _UsageTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildTypeChip({required String label, required String subtitle}) {
      final selected = selectedType == label;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(label),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE0F2FE) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFF0284C7) : const Color(0xFFD1D5DB),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? const Color(0xFF0284C7) : const Color(0xFF6B7280),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          const Text(
            'Select Usage Type (Required)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              buildTypeChip(
                label: 'Personal',
                subtitle: 'Standard pricing — For personal, individual documents only (not for official or commercial use).',
              ),
              const SizedBox(width: 8),
              buildTypeChip(
                label: 'Business',
                subtitle: 'Business pricing — For official, corporate, or commercial document processing to ensure regulatory compliance.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCardsSection extends StatelessWidget {
  final String selectedCurrency;
  final String sevenDayPriceLine;
  final String monthlyPriceLine;
  final String yearlyPriceLine;
  final String lifetimePriceLine;
  final Map<String, List<String>> enabledToolsByPlan;
  final int discountPercent;
  final String selectedPlan;
  final String? usageType;
  final ValueChanged<String> onPlanSelected;

  const _PlanCardsSection({
    required this.selectedCurrency,
    required this.sevenDayPriceLine,
    required this.monthlyPriceLine,
    required this.yearlyPriceLine,
    required this.lifetimePriceLine,
    required this.enabledToolsByPlan,
    required this.discountPercent,
    required this.selectedPlan,
    required this.usageType,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 980;
        final cards = [
          _PlanCardTile(
            title: 'FREE',
            subtitle: 'Core tools, quick checks, and starter workflow access',
            priceLine: '₹0 / \$0',
            enabledTools: enabledToolsByPlan['Free'] ?? const <String>[],
            buttonLabel: 'Select Plan',
            selected: selectedPlan == 'Free',
            onSelected: () => onPlanSelected('Free'),
          ),
          _PlanCardTile(
            title: '7 DAYS',
            subtitle: 'Test PDF edit, PDF to Word, OCR, and premium workflow controls',
            priceLine: sevenDayPriceLine,
            enabledTools: enabledToolsByPlan['7Days'] ?? const <String>[],
            buttonLabel: 'Select Plan',
            selected: selectedPlan == '7Days',
            onSelected: () => onPlanSelected('7Days'),
          ),
          _PlanCardTile(
            title: 'MONTHLY',
            subtitle: 'Monthly access with document conversion, edit, and support workflows',
            priceLine: monthlyPriceLine,
            enabledTools: enabledToolsByPlan['Monthly'] ?? const <String>[],
            buttonLabel: 'Select Plan',
            badgeLabel: 'Popular',
            selected: selectedPlan == 'Monthly',
            onSelected: () => onPlanSelected('Monthly'),
          ),
          _PlanCardTile(
            title: 'YEARLY',
            subtitle: 'Best value for regular use, higher limits, and full plan coverage',
            priceLine: yearlyPriceLine,
            enabledTools: enabledToolsByPlan['Yearly'] ?? const <String>[],
            buttonLabel: 'Select Plan',
            badgeLabel: 'Best Value',
            recommended: true,
            selected: selectedPlan == 'Yearly',
            onSelected: () => onPlanSelected('Yearly'),
          ),
          _PlanCardTile(
            title: 'LIFETIME LAUNCH OFFER',
            subtitle: 'One-time access for 1 desktop/laptop and 1 mobile device',
            priceLine: lifetimePriceLine,
            enabledTools: enabledToolsByPlan['Lifetime'] ?? const <String>[],
            buttonLabel: 'Select Plan',
            selected: selectedPlan == 'Lifetime',
            onSelected: () => onPlanSelected('Lifetime'),
          ),
        ];

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _buildFeatureListCta(context),
              const SizedBox(height: 8),
              if (usageType != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${usageType == 'Business' ? 'Business' : 'Personal'} mode active. Payment display currency: $selectedCurrency.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            _buildFeatureListCta(context),
            const SizedBox(height: 8),
            if (usageType != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${usageType == 'Business' ? 'Business' : 'Personal'} mode active. Payment display currency: $selectedCurrency.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureListCta(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PlanFeaturesPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Color(0xFFDCEAFE)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF93C5FD), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(
                Icons.list_alt_rounded,
                color: Color(0xFF1D4ED8),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Full Function List',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PDF edit, OCR (Optical Character Recognition), payments, and plan detail matrix',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Color(0xFF1D4ED8),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCardTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String priceLine;
  final List<String> enabledTools;
  final String buttonLabel;
  final String? badgeLabel;
  final bool recommended;
  final bool selected;
  final VoidCallback onSelected;

  const _PlanCardTile({
    required this.title,
    required this.subtitle,
    required this.priceLine,
    required this.enabledTools,
    required this.buttonLabel,
    this.badgeLabel,
    this.recommended = false,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_PlanCardTile> createState() => _PlanCardTileState();
}

class _PlanCardTileState extends State<_PlanCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isPro = widget.title == 'Pro';

    final List<Color> backgroundGradient = widget.recommended
        ? const [Color(0xFFEEF6FF), Color(0xFFDDEEFF)]
        : isPro
            ? const [Color(0xFFEFFCF8), Color(0xFFD8F5EC)]
            : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)];

    final Color outlineColor = widget.selected
        ? const Color(0xFF0F766E)
        : (widget.recommended
            ? const Color(0xFF1D74D8)
            : (isPro ? const Color(0xFF0F766E) : const Color(0xFFD1D5DB)));

    final Color accentColor = widget.recommended
        ? const Color(0xFF1D74D8)
        : (isPro ? const Color(0xFF0F766E) : const Color(0xFF1F2937));

    final IconData planIcon = widget.recommended
        ? Icons.auto_awesome_rounded
        : (isPro ? Icons.bolt_rounded : Icons.shield_outlined);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: outlineColor,
            width: widget.selected ? 2 : (widget.recommended ? 2 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(widget.selected || _hovered ? 0.24 : 0.12),
              blurRadius: widget.selected || _hovered ? 24 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.recommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF1D74D8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withOpacity(0.25)),
                      ),
                      child: Icon(planIcon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                      if (widget.selected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.badgeLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Text(
                      widget.badgeLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
                if (widget.enabledTools.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Enabled tools: ${widget.enabledTools.join(', ')}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Text(
                    widget.priceLine,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.selected ? accentColor : const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      elevation: widget.selected ? 2.5 : 1,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _FixedAdSpaceState extends State<_FixedAdSpace> {
  String _title = 'Sponsored';
  String _subtitle = 'Loading ad slot...';
  String _provider = 'admob';

  @override
  void initState() {
    super.initState();
    _title = 'Sponsored';
    _subtitle = 'Partner offer space (fixed slot).';
    _provider = 'admob';
  }

  Future<void> _loadAdPayload() async {
    // Intentionally disabled in production hotfix path.
  }

  Future<void> _onTapAd() async {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ad click tracked for $_provider (${widget.adPlacement}).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTapAd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFECFEFF), Color(0xFFEFF6FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _provider.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4ED8),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationHubPanel extends StatefulWidget {
  const _IntegrationHubPanel();

  @override
  State<_IntegrationHubPanel> createState() => _IntegrationHubPanelState();
}

class _IntegrationHubPanelState extends State<_IntegrationHubPanel> {
  late final Future<List<IntegrationApp>> _appsFuture;

  @override
  void initState() {
    super.initState();
    _appsFuture = IntegrationHubService.getEnabledApps();
  }

  Future<void> _runFirstAction(IntegrationApp app) async {
    if (app.actions.isEmpty) {
      return;
    }

    final action = app.actions.first;
    final result = await IntegrationHubService.runAction(
      app: app,
      action: action,
      payload: {
        'source': 'jobready_v2',
        'trigger': 'manual_test',
      },
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${app.name}: ${result['message'] ?? 'Integration action sent'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<IntegrationApp>>(
      future: _appsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final apps = snapshot.data ?? const <IntegrationApp>[];
        if (apps.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No enabled integrations found in manifest.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return Column(
          children: apps
              .map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _IntegrationAppTile(
                    app: app,
                    onTap: () => _runFirstAction(app),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _IntegrationAppTile extends StatelessWidget {
  final IntegrationApp app;
  final VoidCallback onTap;

  const _IntegrationAppTile({
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE5F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE0EAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hub_rounded,
                color: Color(0xFF1D4ED8),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${app.auth.displayLabel} | ${app.actions.length} actions',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF1D4ED8),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayControlPanel extends StatefulWidget {
  final String activeGateway;
  final ValueChanged<String> onGatewayChanged;

  const _GatewayControlPanel({
    required this.activeGateway,
    required this.onGatewayChanged,
  });

  @override
  State<_GatewayControlPanel> createState() => _GatewayControlPanelState();
}

class _OwnerAdminSession {
  static bool isUnlocked = false;
}

class _GatewayControlPanelState extends State<_GatewayControlPanel> {
  static const String _ownerCode = 'JR-OWNER-2026';
  final TextEditingController _ownerCodeController = TextEditingController();
  bool _isOwnerUnlocked = _OwnerAdminSession.isUnlocked;
  String _statusText = 'Owner lock active';

  @override
  void initState() {
    super.initState();
    if (_OwnerAdminSession.isUnlocked) {
      _statusText = 'Owner unlocked. You can switch payment gateway now.';
    }
  }

  @override
  void dispose() {
    _ownerCodeController.dispose();
    super.dispose();
  }

  void _unlockOwner() {
    final isValid = _ownerCodeController.text.trim() == _ownerCode;
    setState(() {
      _isOwnerUnlocked = isValid;
      if (isValid) {
        _OwnerAdminSession.isUnlocked = true;
      }
      _statusText = isValid
          ? 'Owner unlocked. You can switch payment gateway now.'
          : 'Invalid owner code';
    });
  }

  void _setGateway(String gateway) {
    final result = ApiService.setActivePaymentGateway(gateway);
    if (result['status'] == 'success') {
      final updated = result['gateway']?.toString() ?? gateway;
      widget.onGatewayChanged(updated);
    }

    final message = result['message']?.toString() ?? 'Gateway update failed';
    setState(() {
      _statusText = message;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateways = ApiService.getSupportedPaymentGateways();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFEFF), Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFFAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owner Payment Gateway Control',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active gateway: ${widget.activeGateway.toUpperCase()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 10),
          if (!_isOwnerUnlocked) ...[
            TextField(
              controller: _ownerCodeController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter owner code',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _unlockOwner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Unlock Owner Controls'),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: gateways
                  .map(
                    (gateway) => ChoiceChip(
                      label: Text(gateway.toUpperCase()),
                      selected: widget.activeGateway == gateway,
                      onSelected: (_) => _setGateway(gateway),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _statusText.toLowerCase().contains('invalid')
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerIntegrationHubPanel extends StatefulWidget {
  const _OwnerIntegrationHubPanel();

  @override
  State<_OwnerIntegrationHubPanel> createState() => _OwnerIntegrationHubPanelState();
}

class _OwnerIntegrationHubPanelState extends State<_OwnerIntegrationHubPanel> {
  static const String _ownerCode = 'JR-OWNER-2026';
  final TextEditingController _ownerCodeController = TextEditingController();
  bool _isUnlocked = _OwnerAdminSession.isUnlocked;
  String _status = 'Integration Hub is owner-only.';

  @override
  void initState() {
    super.initState();
    if (_OwnerAdminSession.isUnlocked) {
      _status = 'Owner unlocked.';
    }
  }

  @override
  void dispose() {
    _ownerCodeController.dispose();
    super.dispose();
  }

  void _unlock() {
    final ok = _ownerCodeController.text.trim() == _ownerCode;
    setState(() {
      _isUnlocked = ok;
      if (ok) {
        _OwnerAdminSession.isUnlocked = true;
      }
      _status = ok ? 'Owner unlocked.' : 'Invalid owner code';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owner Integration Hub',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _status,
            style: TextStyle(
              fontSize: 12,
              color: _status.toLowerCase().contains('invalid')
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (!_isUnlocked) ...[
            TextField(
              controller: _ownerCodeController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter owner code',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _unlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Unlock Integration Hub'),
              ),
            ),
          ] else ...[
            const _SectionHeader(
              title: 'Integration Hub',
              subtitle: 'Connect external apps via API manifest, without future UI code changes.',
            ),
            const SizedBox(height: 8),
            const _IntegrationHubPanel(),
          ],
        ],
      ),
    );
  }
}

class _UserPaymentPanel extends StatefulWidget {
  final String activeGateway;
  final String selectedPlan;
  final String selectedCurrency;
  final String? usageType;
  final double sevenDayAmount;
  final double monthlyAmount;
  final double yearlyAmount;
  final double lifetimePlanAmount;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onUsageTypeChanged;

  const _UserPaymentPanel({
    required this.activeGateway,
    required this.selectedPlan,
    required this.selectedCurrency,
    required this.usageType,
    required this.sevenDayAmount,
    required this.monthlyAmount,
    required this.yearlyAmount,
    required this.lifetimePlanAmount,
    required this.onPlanChanged,
    required this.onCurrencyChanged,
    required this.onUsageTypeChanged,
  });

  @override
  State<_UserPaymentPanel> createState() => _UserPaymentPanelState();
}

class _UserPaymentPanelState extends State<_UserPaymentPanel> {
  bool _submitting = false;
  bool _creatingPaymentLink = false;
  Map<String, dynamic>? _lastCheckoutResponse;
  String _localCurrency = 'USD';

  static const Duration _checkoutTimeout = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _localCurrency = widget.selectedCurrency;
  }

  @override
  void didUpdateWidget(covariant _UserPaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCurrency != widget.selectedCurrency) {
      _localCurrency = widget.selectedCurrency;
    }
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
      planId: widget.selectedPlan,
      amount: _chargeAmountForPlan(widget.selectedPlan),
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
    Map<String, dynamic> mapped = <String, dynamic>{};
    if (raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        mapped = Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Unexpected response format from $url.');
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
    Object? lastError;
    for (final url in _candidateApiUrls(path)) {
      try {
        return await _requestJson(method, url, body: body);
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(_friendlyCheckoutError(lastError, path));
  }

  String _friendlyCheckoutError(Object? error, String path) {
    final raw = (error?.toString() ?? 'Unknown payment error')
        .replaceFirst('Exception: ', '')
        .trim();
    if (raw.contains('HTTP 404') || raw.contains('Unable to reach payment API')) {
      return 'Payment service endpoint is not reachable for $path. Please retry in 1 minute.';
    }
    if (raw.contains('Recurring digits in customer contact are disallowed')) {
      return 'Please update your mobile number in account profile and try payment again.';
    }
    if (raw.contains('minified:') || raw.contains('ProgressEvent')) {
      return 'Payment request failed before checkout opened. Please refresh and try again.';
    }
    return raw;
  }

  Map<String, dynamic> _buildBillingPayload() {
    final profile = UserAccountService.getProfile();
    final session = UserAuthService.getSession();

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : (session?.displayName.trim().isNotEmpty == true ? session!.displayName.trim() : 'User');
    final email = profile.email.trim().isNotEmpty
        ? profile.email.trim()
      : (session?.email.trim().isNotEmpty == true ? session!.email.trim() : '');
    final mobileRaw = profile.mobileNumber.trim().isNotEmpty
        ? profile.mobileNumber.trim()
      : (session?.mobileNumber.trim() ?? '');
    final mobileDigits = mobileRaw.replaceAll(RegExp(r'\D'), '');
    final normalizedMobile = mobileDigits;

    return {
      'name': displayName,
      'company': '',
      'address': '',
      'country': profile.country.trim().isEmpty ? 'India' : profile.country.trim(),
      'gstin': '',
      'email': email,
      'mobile': normalizedMobile,
    };
  }

  Future<Map<String, dynamic>> _createPaymentLinkFromBilling(Map<String, dynamic> billing) async {
    final amountMinor = (_chargeAmountForPlan(widget.selectedPlan) * 100).round();
    if (amountMinor <= 0) {
      throw Exception('Invalid payment amount for selected plan.');
    }

    final payload = {
      'gateway': _resolvedGatewayName(),
      'amount': amountMinor,
      'currency': _localCurrency,
      'receipt': 'plink-${widget.selectedPlan.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
      'planId': widget.selectedPlan,
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
        normalized.contains('unable to load razorpay checkout sdk');
  }

  Future<Map<String, dynamic>> _openRazorpayAndVerify({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    required Map<String, dynamic> billing,
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
      'description': ApiConfig.razorpayConfig.description,
      'order_id': orderId,
      'prefill': {
        'name': billing['name']?.toString() ?? 'User',
        'email': billing['email']?.toString() ?? '',
        'contact': billing['mobile']?.toString() ?? '',
      },
      'theme': {
        'color': '#${ApiConfig.razorpayConfig.themeColor.toUpperCase()}',
      },
    };

    final messageSubscription = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) {
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
      '/api/verify-payment',
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

  Future<void> _openAuthThenContinue() async {
    await showDialog<void>(
      context: context,
      builder: (authContext) => UserAuthDialog(
        preselectedPlan: widget.selectedPlan,
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
          'selected_plan': widget.selectedPlan,
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
          'selected_plan': widget.selectedPlan,
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
          'selected_plan': widget.selectedPlan,
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
      if (keyId.isEmpty) {
        throw Exception('Razorpay public key is not configured on the server.');
      }

      final amountMinor = (_chargeAmountForPlan(widget.selectedPlan) * 100).round();
      if (amountMinor <= 0) {
        throw Exception('Invalid payment amount for selected plan.');
      }

      final createOrderPayload = {
        'gateway': _resolvedGatewayName(),
        'amount': amountMinor,
        'currency': _localCurrency,
        'receipt': 'plan-${widget.selectedPlan.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
        'planId': widget.selectedPlan,
        'billing': billing,
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

      final orderId = createOrderResponse['order_id']?.toString() ?? '';
      final orderAmount = int.tryParse(createOrderResponse['amount']?.toString() ?? '') ?? amountMinor;
      final orderCurrency = createOrderResponse['currency']?.toString().toUpperCase() ?? _localCurrency;

      if (orderId.isEmpty) {
        throw Exception('Payment order ID is missing from server response.');
      }

      setState(() {
        _lastCheckoutResponse = {
          ...readiness,
          'selected_plan': widget.selectedPlan,
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

      const message = 'Payment verified successfully.';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
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

  Widget _buildReadinessCard() {
    final readiness = _readiness();
    final status = readiness['status']?.toString() ?? 'blocked';
    final statusColor = _statusColor(status);
    final amount = _chargeAmountForPlan(widget.selectedPlan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
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
          Text(
            'Plan: ${widget.selectedPlan} | Amount: ${_formatCurrencyAmount(amount, _localCurrency)} | Usage: ${widget.usageType ?? 'NOT SELECTED'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE5F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A94A3B8),
            blurRadius: 18,
            offset: Offset(0, 8),
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
              color: Color(0xFF1E1B4B),
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
                widget.onCurrencyChanged(value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Payment currency',
              helperText: 'USD-based conversion is used for global currencies. Choose "Other countries" when your currency is not listed. INR stays on the India rate card.',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          _buildReadinessCard(),
          const SizedBox(height: 8),
          const Text(
            'Usage Type',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Personal'),
                  selected: widget.usageType == 'Personal',
                  onSelected: (_) => widget.onUsageTypeChanged('Personal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Business'),
                  selected: widget.usageType == 'Business',
                  onSelected: (_) => widget.onUsageTypeChanged('Business'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('${widget.selectedPlan}_${widget.usageType}_${_localCurrency}'),
            value: widget.selectedPlan,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'Free',
                child: Text(
                  buildPlanDisplayLabel(
                    plan: 'Free',
                    amount: 0,
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
                widget.onPlanChanged(value);
              }
            },            decoration: InputDecoration(
              labelText: 'Choose plan',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.selectedPlan != 'Basic')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Text(
                widget.selectedPlan == '7Days'
                    ? 'Short access plan selected: ${_formatCurrencyAmount(widget.sevenDayAmount, _localCurrency)} for 7-day use.'
                    : _isSubscriptionPlan(widget.selectedPlan)
                        ? 'Offer active: Pay for 10 months (${_formatCurrencyAmount(_monthlyForPlan(widget.selectedPlan) * 10, _localCurrency)}) and get 12 months access.'
                        : 'One-time Lifetime plan payment: ${_formatCurrencyAmount(widget.lifetimePlanAmount, _localCurrency)}.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C4A6E),
                ),
              ),
            ),
          if (widget.selectedPlan != 'Basic') const SizedBox(height: 10),
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
                backgroundColor: const Color(0xFF0B1220),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
                shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
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
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.white,
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
    );
  }
}

class _OwnerOfferManagerPanel extends StatefulWidget {
  final void Function(bool enabled, String offerText, String promoCode, Duration? validity)
      onOfferUpdated;

  const _OwnerOfferManagerPanel({
    required this.onOfferUpdated,
  });

  @override
  State<_OwnerOfferManagerPanel> createState() => _OwnerOfferManagerPanelState();
}

class _AdminLoginPanel extends StatefulWidget {
  final VoidCallback onUnlocked;

  const _AdminLoginPanel({
    required this.onUnlocked,
  });

  @override
  State<_AdminLoginPanel> createState() => _AdminLoginPanelState();
}

class _AdminLoginPanelState extends State<_AdminLoginPanel> {
  late final TextEditingController _adminIdController;
  final TextEditingController _passwordController = TextEditingController();
  String _status = 'Admin login required to open dashboard controls.';
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _adminIdController = TextEditingController(text: OwnerAdminAccessService.adminId);
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() {
    final ok = OwnerAdminAccessService.unlockWithCredentials(
      _adminIdController.text,
      _passwordController.text,
    );
    setState(() {
      _status = ok ? 'Admin dashboard unlocked.' : 'Invalid admin ID or password.';
    });
    if (ok) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Login',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'First login: ID Admin and password Admin@2026!. After login, open Admin Login Settings to set your own password.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminIdController,
            decoration: InputDecoration(
              labelText: 'Admin ID',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Login for Admin Controls'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _status.toLowerCase().contains('invalid')
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCredentialsPanel extends StatefulWidget {
  const _AdminCredentialsPanel();

  @override
  State<_AdminCredentialsPanel> createState() => _AdminCredentialsPanelState();
}

class _AdminCredentialsPanelState extends State<_AdminCredentialsPanel> {
  late final TextEditingController _adminIdController;
  final TextEditingController _passwordController = TextEditingController();
  String _status = 'Set your admin ID/password here. Leave password blank to keep existing one.';
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _adminIdController = TextEditingController(text: OwnerAdminAccessService.adminId);
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    final currentPassword = OwnerAdminAccessService.adminPassword;
    final nextPassword = _passwordController.text.trim().isEmpty
        ? currentPassword
        : _passwordController.text.trim();

    await OwnerAdminAccessService.setCredentials(
      adminId: _adminIdController.text.trim(),
      password: nextPassword,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Admin credentials updated. Use new values on next login.';
      _passwordController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin login ID/password saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Login Settings',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0C4A6E)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminIdController,
            decoration: InputDecoration(
              labelText: 'Admin ID',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'New Password (optional)',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveCredentials,
              icon: const Icon(Icons.password_rounded),
              label: const Text('Save Admin ID / Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _status,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSystemCheckPanel extends StatelessWidget {
  const _AdminSystemCheckPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Check Box',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'API: Ready | Payment: Config-only | Gateway: Owner control active | QA: Validation route available',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SystemCheckPage()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Open full validation checks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF1D4ED8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBankAdsStatusPanel extends StatelessWidget {
  const _AdminBankAdsStatusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank & Ads Status Panel',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Live status: legacy Bank/Ads file links are blocked from public access. Keep monitoring alerts active for urgent events.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              html.window.open('https://getreadyjob.com/downloads/bank_api_packet_v1_1.md', '_blank');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Verify blocked legacy links now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF1D4ED8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCatalogManagerPanel extends StatefulWidget {
  final PlanCatalogConfig initialConfig;
  final ValueChanged<PlanCatalogConfig> onConfigSaved;

  const _PlanCatalogManagerPanel({
    required this.initialConfig,
    required this.onConfigSaved,
  });

  @override
  State<_PlanCatalogManagerPanel> createState() => _PlanCatalogManagerPanelState();
}

class _PlanCatalogManagerPanelState extends State<_PlanCatalogManagerPanel> {
  static const List<String> _plans = <String>['Free', '7Days', 'Monthly', 'Yearly', 'Lifetime'];
  static const List<String> _allTools = PlanCatalogConfig.registeredToolNames;

  late Map<String, TextEditingController> _inrControllers;
  late Map<String, TextEditingController> _usdControllers;
  late Map<String, TextEditingController> _quotaControllers;
  late Map<String, List<String>> _enabledToolsByPlan;

  @override
  void initState() {
    super.initState();
    _hydrateFromConfig(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant _PlanCatalogManagerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialConfig != widget.initialConfig) {
      _disposeControllers();
      _hydrateFromConfig(widget.initialConfig);
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _hydrateFromConfig(PlanCatalogConfig config) {
    _inrControllers = {
      for (final plan in _plans)
        plan: TextEditingController(text: (config.inrPrices[plan] ?? 0).toString())
    };
    _usdControllers = {
      for (final plan in _plans)
        plan: TextEditingController(text: (config.usdPrices[plan] ?? 0).toString())
    };
    _quotaControllers = {
      for (final plan in _plans)
        plan: TextEditingController(text: config.userQuotasByPlan[plan] ?? PlanCatalogConfig.defaults().userQuotasByPlan[plan] ?? '2')
    };
    _enabledToolsByPlan = {
      for (final plan in _plans)
        plan: List<String>.from(config.enabledToolsByPlan[plan] ?? const <String>[])
    };
  }

  void _disposeControllers() {
    for (final controller in _inrControllers.values) {
      controller.dispose();
    }
    for (final controller in _usdControllers.values) {
      controller.dispose();
    }
    for (final controller in _quotaControllers.values) {
      controller.dispose();
    }
  }

  double _readAmount(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.trim()) ?? fallback;
  }

  Future<void> _saveConfig() async {
    final defaults = PlanCatalogConfig.defaults();
    final inr = <String, double>{};
    final usd = <String, double>{};
    final quotas = <String, String>{};

    for (final plan in _plans) {
      inr[plan] = _readAmount(_inrControllers[plan]!, defaults.inrPrices[plan] ?? 0);
      usd[plan] = _readAmount(_usdControllers[plan]!, defaults.usdPrices[plan] ?? 0);
      final rawQuota = _quotaControllers[plan]!.text.trim();
      quotas[plan] = rawQuota.isEmpty ? (defaults.userQuotasByPlan[plan] ?? '2') : rawQuota;
    }

    final config = PlanCatalogConfig(
      inrPrices: inr,
      usdPrices: usd,
      enabledToolsByPlan: {
        for (final plan in _plans) plan: List<String>.from(_enabledToolsByPlan[plan] ?? const <String>[])
      },
      userQuotasByPlan: quotas,
    );

    await PlanCatalogService.save(config);
    widget.onConfigSaved(config);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan rates and tool permissions saved.')),
    );
  }

  Future<void> _resetConfig() async {
    await PlanCatalogService.reset();
    final resetConfig = PlanCatalogConfig.defaults();
    setState(() {
      _disposeControllers();
      _hydrateFromConfig(resetConfig);
    });
    widget.onConfigSaved(resetConfig);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan catalog reset to defaults.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Card Manager',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Update plan amounts and tick tools per plan. Saved settings apply instantly on cards.',
            style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (final plan in _plans) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inrControllers[plan],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'INR',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _usdControllers[plan],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'USD',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quotaControllers[plan],
                    decoration: InputDecoration(
                      labelText: 'User Quota',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      helperText: '2, 50, 200, 1000, Unlimited',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 0,
                    children: [
                      for (final tool in _allTools)
                        FilterChip(
                          label: Text(tool),
                          selected: (_enabledToolsByPlan[plan] ?? const <String>[]).contains(tool),
                          onSelected: (selected) {
                            setState(() {
                              final selectedTools = _enabledToolsByPlan[plan] ?? <String>[];
                              if (selected) {
                                if (!selectedTools.contains(tool)) {
                                  selectedTools.add(tool);
                                }
                              } else {
                                selectedTools.remove(tool);
                              }
                              _enabledToolsByPlan[plan] = selectedTools;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Plan Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetConfig,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset Defaults'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerOfferManagerPanelState extends State<_OwnerOfferManagerPanel> {
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _promoController = TextEditingController(text: 'JRFREE1001Y');
  bool _showOffer = false;
  Duration? _validity = const Duration(days: 365);

  @override
  void dispose() {
    _offerController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void _applyOffer() {
    widget.onOfferUpdated(
      _showOffer,
      _offerController.text,
      _promoController.text,
      _validity,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer and promo settings updated on home page.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owner Offer & Promo Box',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Show offer on home page',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
                Switch(
                  value: _showOffer,
                  onChanged: (value) => setState(() => _showOffer = value),
                ),
              ],
            ),
          ),
          TextField(
            controller: _offerController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Write offer text here (New Year, Diwali, etc.)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promoController,
            decoration: InputDecoration(
              hintText: 'Promo code (example: NEWYEAR100)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Duration?>(
            initialValue: _validity,
            items: const [
              DropdownMenuItem<Duration?>(value: Duration(days: 365), child: Text('1 Year')),
              DropdownMenuItem<Duration?>(value: Duration(days: 30), child: Text('1 Month')),
              DropdownMenuItem<Duration?>(value: Duration(days: 7), child: Text('1 Week')),
            ],
            onChanged: (value) => setState(() => _validity = value),
            decoration: InputDecoration(
              labelText: 'Promo validity',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyOffer,
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publish Offer & Promo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutUsSection extends StatelessWidget {
  const _AboutUsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About Us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          SizedBox(height: 6),
          Text(
            'GETREADYJOB helps users process documents faster with reliable tools for conversion, compression, and premium workflow automation. We focus on simple steps, stable output quality, and practical productivity for individuals and teams.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _FuturePlanSection extends StatelessWidget {
  const _FuturePlanSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Future Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          SizedBox(height: 6),
          Text(
            'Our new Version 2 will deliver a cleaner workspace, stronger payment and plan controls, deeper API integrations, and better performance across browsers. It will include smarter sharing options, offer automation, and owner-level controls for promotions and gateway switching. We are also expanding enterprise-ready features with better operational controls and launch runbooks. The goal is a faster, simpler, and more scalable experience for all users.',
            style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  final VoidCallback onTap;

  const _SuggestionSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.feedback_outlined),
        label: const Text('Send Suggestion'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _UserRatingSection extends StatefulWidget {
  const _UserRatingSection();

  @override
  State<_UserRatingSection> createState() => _UserRatingSectionState();
}

class _UserRatingSectionState extends State<_UserRatingSection> {
  int _selectedStars = 5;
  UserRatingSummary _summary = UserRatingService.getSummary();

  Future<void> _submit() async {
    await UserRatingService.submitRating(_selectedStars);
    if (!mounted) {
      return;
    }

    setState(() {
      _summary = UserRatingService.getSummary();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thanks. You rated $_selectedStars star(s).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Rating',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Rate your experience from 1 to 5 stars.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                tooltip: '$star star',
                onPressed: () {
                  setState(() {
                    _selectedStars = star;
                  });
                },
                icon: Icon(
                  star <= _selectedStars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              );
            }),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Submit Rating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _summary.publicVisible
                ? (_summary.totalCount == 0
                    ? 'Overall rating: no ratings yet.'
                    : 'Overall rating: ${_summary.average.toStringAsFixed(2)} / 5 from ${_summary.totalCount} users.')
                : 'Overall rating is currently hidden by admin.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRatingControlPanel extends StatefulWidget {
  const _AdminRatingControlPanel();

  @override
  State<_AdminRatingControlPanel> createState() => _AdminRatingControlPanelState();
}

class _AdminRatingControlPanelState extends State<_AdminRatingControlPanel> {
  String _statusText = 'Admin controls ready.';
  UserRatingSummary _summary = UserRatingService.getSummary();

  Future<void> _setVisibility(bool visible) async {
    await UserRatingService.setPublicVisible(visible);
    if (!mounted) {
      return;
    }

    setState(() {
      _summary = UserRatingService.getSummary();
      _statusText = visible
          ? 'Overall rating display set to YES (public).'
          : 'Overall rating display set to NO (hidden).';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFEFF), Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFFAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Rating Control',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _summary.totalCount == 0
                ? 'Actual rating: no ratings yet.'
                : 'Actual rating: ${_summary.average.toStringAsFixed(2)} / 5 from ${_summary.totalCount} users.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ratings today: ${_summary.todayCount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show overall rating on site (Yes / No)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Yes'),
                selected: _summary.publicVisible,
                onSelected: (_) => _setVisibility(true),
              ),
              ChoiceChip(
                label: const Text('No'),
                selected: !_summary.publicVisible,
                onSelected: (_) => _setVisibility(false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBadge extends StatelessWidget {
  final String label;

  const _FooterBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _FooterInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FooterInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFFFC72C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TopActionIcon({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFCFEFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E4F2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1290A3BE),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CouponControlPanel extends StatefulWidget {
  final ValueChanged<int> onDiscountChanged;

  const _CouponControlPanel({required this.onDiscountChanged});

  @override
  State<_CouponControlPanel> createState() => _CouponControlPanelState();
}

class _CouponControlPanelState extends State<_CouponControlPanel> {
  final TextEditingController _couponInputController = TextEditingController();
  final TextEditingController _discountInputController = TextEditingController(text: '20');
  static const String _ownerAccessCode = String.fromEnvironment('OWNER_ACCESS_CODE');

  int _selectedDiscount = 20;
  Duration? _selectedValidity;
  bool _isSettingsSaved = false;
  bool _isAdminUnlocked = false;
  bool _isPanelExpanded = false;
  CouponData? _lastGenerated;
  String _applyMessage = 'Generate coupon or redeem existing one-time code';
  int _appliedDiscount = 0;

  @override
  void dispose() {
    _couponInputController.dispose();
    _discountInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coupons = CouponService.getAllCoupons();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Coupon Control',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isPanelExpanded = !_isPanelExpanded;
                  });
                },
                icon: Icon(
                  _isPanelExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 16,
                ),
                label: Text(_isPanelExpanded ? 'Hide' : 'Show'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (!_isPanelExpanded)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Promo section minimized. Expand when needed.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
          if (_isPanelExpanded) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Users can redeem promo code here. Owner controls are protected.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _toggleOwnerAccess,
                  icon: Icon(_isAdminUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16),
                  label: Text(_isAdminUnlocked ? 'Owner On' : 'Owner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (_isAdminUnlocked) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Owner Tools',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                subtitle: const Text(
                  'Expand only when needed',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                children: [
                  TextField(
                    controller: _discountInputController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {
                        _isSettingsSaved = false;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage',
                      hintText: 'Enter value between 1 and 100',
                      suffixText: '%',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Validity Window',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _validityChip('24 Hours', const Duration(hours: 24)),
                      _validityChip('1 Week', const Duration(days: 7)),
                      _validityChip('1 Month', const Duration(days: 30)),
                      _validityChip('No Expiry', null),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFF0F172A)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _savePromoSettings,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text(
                        'Save Promo Settings',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _generateCoupon,
                      icon: const Icon(Icons.local_offer_rounded, size: 16),
                      label: const Text(
                        'Create Promo Code',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  if (_lastGenerated != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final latest = _lastGenerated;
                        if (latest == null) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF7FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCE7FF)),
                          ),
                          child: SelectableText(
                            'Latest: ${latest.code}  (${latest.discountPercent}% OFF)  ${_formatExpiryText(latest)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (coupons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Generated Coupons',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...coupons.take(5).map(_couponRow),
                  ],
                ],
              ),
            ),
            ],
            const SizedBox(height: 8),
            TextField(
            controller: _couponInputController,
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.4),
              ),
            ),
            ),
            const SizedBox(height: 6),
            SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _redeemCoupon,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text(
                'Redeem Promo Code',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            ),
            const SizedBox(height: 6),
            Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _appliedDiscount > 0 ? const Color(0xFFEAFBF0) : const Color(0xFFFFF4F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _appliedDiscount > 0 ? const Color(0xFFB9F3CC) : const Color(0xFFFECACA),
              ),
            ),
            child: Text(
              _applyMessage,
              style: TextStyle(
                fontSize: 11,
                color: _appliedDiscount > 0 ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleOwnerAccess() {
    if (_isAdminUnlocked) {
      setState(() {
        _isAdminUnlocked = false;
      });
      return;
    }

    if (_ownerAccessCode.trim().isEmpty) {
      setState(() {
        _applyMessage = 'Owner access is disabled. Start app with --dart-define=OWNER_ACCESS_CODE=YourCode';
        _appliedDiscount = 0;
      });
      return;
    }

    _showOwnerAccessDialog();
  }

  void _showOwnerAccessDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Owner Access'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter owner code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = pinController.text.trim();
              Navigator.of(dialogContext).pop();
              if (code == _ownerAccessCode) {
                setState(() {
                  _isAdminUnlocked = true;
                });
              } else {
                setState(() {
                  _applyMessage = 'Invalid owner code';
                  _appliedDiscount = 0;
                });
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    ).then((_) {
      pinController.dispose();
    });
  }

  Widget _validityChip(String label, Duration? validity) {
    final selected = _selectedValidity == validity;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedValidity = validity;
          _isSettingsSaved = false;
        });
      },
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF1F2937),
        fontWeight: FontWeight.w700,
      ),
      selectedColor: const Color(0xFF007AFF),
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    );
  }

  String _formatExpiryText(CouponData coupon) {
    final expiry = coupon.expiresAt;
    if (expiry == null) {
      return 'No expiry';
    }

    final remaining = expiry.difference(coupon.createdAt);
    if (remaining.inHours <= 24) {
      return 'Valid 24 hours';
    }
    if (remaining.inDays <= 7) {
      return 'Valid 1 week';
    }
    if (remaining.inDays <= 31) {
      return 'Valid 1 month';
    }
    return 'Expiry set';
  }

  String _currentValidityLabel() {
    if (_selectedValidity == null) {
      return 'No expiry';
    }
    if (_selectedValidity == const Duration(hours: 24)) {
      return '24 hours';
    }
    if (_selectedValidity == const Duration(days: 7)) {
      return '1 week';
    }
    if (_selectedValidity == const Duration(days: 30)) {
      return '1 month';
    }
    return 'Custom';
  }

  Widget _couponRow(CouponData coupon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${coupon.code}  (${coupon.discountPercent}%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            coupon.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: coupon.isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }

  void _generateCoupon() {
    if (!_isSettingsSaved) {
      setState(() {
        _appliedDiscount = 0;
        _applyMessage = 'Save promo settings first before creating a promo code';
      });
      widget.onDiscountChanged(0);
      return;
    }

    final coupon = CouponService.generateCoupon(
      discountPercent: _selectedDiscount,
      validFor: _selectedValidity,
    );

    setState(() {
      _lastGenerated = coupon;
      _applyMessage = 'Generated ${coupon.code} (${coupon.discountPercent}% OFF, ${_currentValidityLabel()})';
      _appliedDiscount = 0;
    });
    widget.onDiscountChanged(0);
  }

  void _savePromoSettings() {
    final discount = int.tryParse(_discountInputController.text.trim());

    if (discount == null || discount < 1 || discount > 100) {
      setState(() {
        _isSettingsSaved = false;
        _appliedDiscount = 0;
        _applyMessage = 'Enter a valid discount between 1% and 100%';
      });
      widget.onDiscountChanged(0);
      return;
    }

    setState(() {
      _selectedDiscount = discount;
      _isSettingsSaved = true;
      _appliedDiscount = 0;
      _applyMessage = 'Promo settings saved: ${discount}% OFF, ${_currentValidityLabel()}';
    });
    widget.onDiscountChanged(0);
  }

  void _redeemCoupon() {
    final result = CouponService.redeemCoupon(_couponInputController.text);
    setState(() {
      _applyMessage = result.message;
      _appliedDiscount = result.valid ? result.discountPercent : 0;
    });
    widget.onDiscountChanged(result.valid ? result.discountPercent : 0);
  }
}

class _V2Column extends StatelessWidget {
  const _V2Column();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UploadCardV2(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF0F172A), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sponsored / Featured: AI Resume Builder and HD Photo Enhancer now highlighted for faster access.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _MostPopularToolsCard(),
        const SizedBox(height: 10),
        const ToolSelectorV2(),
      ],
    );
  }
}

class _WhyChooseSection extends StatelessWidget {
  const _WhyChooseSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WhyChooseCard(),
              SizedBox(height: 12),
              _WhyChooseIllustrationPlaceholder(),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: WhyChooseCard()),
            SizedBox(width: 16),
            Expanded(flex: 1, child: _WhyChooseIllustrationPlaceholder()),
          ],
        );
      },
    );
  }
}

class _WhyChooseIllustrationPlaceholder extends StatelessWidget {
  const _WhyChooseIllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF2FF), Color(0xFFDCEBFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFD4F3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: Color(0xFFFFC72C)),
                    SizedBox(width: 4),
                    Text(
                      'PRO STUDIO SUITE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '100% Safe',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD166)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Resume Builder',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ATS Optimized • 104 Templates',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF65A30D)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF93C5FD)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_outlined, color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HD Photo Studio',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '100KB Passport • Studio Polish',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF475569), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Document Engine',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Compress • Convert • Merge • Split',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _IllustrationBadge(icon: Icons.speed_rounded, label: 'Instant Processing'),
              _IllustrationBadge(icon: Icons.cloud_done_rounded, label: 'Zero Data Storage'),
              _IllustrationBadge(icon: Icons.star_rounded, label: 'A4 Layout Ready'),
            ],
          ),
        ],
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IllustrationBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF0F172A)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class _MostPopularToolsCard extends StatelessWidget {
  const _MostPopularToolsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Popular Tools',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 640
                      ? 2
                      : 1;

              final flagshipTools = <Widget>[
                _PopularToolRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Resume Builder',
                  description: 'Build ATS-ready resumes with AI-guided summaries and formatting.',
                  isFlagship: true,
                  badgeText: '1 FREE USE',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AiResumeBuilderPage()),
                    );
                  },
                ),
                _PopularToolRow(
                  icon: Icons.photo_camera_outlined,
                  label: 'HD Photo Converter / Enhancer',
                  description: 'Enhance, resize, and convert photos to studio-quality output.',
                  isFlagship: true,
                  badgeText: '1 FREE USE',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PhotoHdWorkspacePage()),
                    );
                  },
                ),
                _PopularToolRow(
                  icon: Icons.document_scanner_outlined,
                  label: 'PDF to PDF OCR Tool',
                  description: 'Extract and search text from scanned documents accurately.',
                  isFlagship: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfEditPage()),
                  ),
                ),
              ];

              final tools = <Widget>[
                _PopularToolRow(
                  icon: Icons.description_outlined,
                  label: 'PDF to Word',
                  description: 'Convert PDF documents into fully editable Word files in seconds.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConvertToolPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.image_outlined,
                  label: 'JPG to PDF',
                  description: 'Turn one or more images into a clean, shareable PDF file.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConvertToolPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.compress_outlined,
                  label: 'Compress PDF',
                  description: 'Shrink file size while keeping document quality intact.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompressionToolPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.merge_type,
                  label: 'Merge PDF',
                  description: 'Combine multiple PDF files into a single organized document.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MergeToolPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.call_split_outlined,
                  label: 'Split PDF',
                  description: 'Break a large PDF into separate, easy-to-share pages or sections.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SplitToolPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Protect PDF',
                  description: 'Add access protection to keep sensitive documents secure.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfEditPage()),
                  ),
                ),
                _PopularToolRow(
                  icon: Icons.edit_note_rounded,
                  label: 'Edit PDF',
                  description: 'Make quick text and layout edits directly inside your PDF.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfEditPage()),
                  ),
                ),
              ];

              final rows = <Widget>[];
              for (var i = 0; i < tools.length; i += crossAxisCount) {
                final rowItems = tools.skip(i).take(crossAxisCount).toList();
                rows.add(
                  Padding(
                    padding: EdgeInsets.only(bottom: i + crossAxisCount < tools.length ? 10 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < crossAxisCount; col++) ...[
                          if (col > 0) const SizedBox(width: 10),
                          Expanded(child: col < rowItems.length ? rowItems[col] : const SizedBox.shrink()),
                        ],
                      ],
                    ),
                  ),
                );
              }

              final flagshipRow = constraints.maxWidth >= 900
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < flagshipTools.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: flagshipTools[i]),
                        ],
                      ],
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < flagshipTools.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            SizedBox(width: 300, child: flagshipTools[i]),
                          ],
                        ],
                      ),
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flagship tools',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  flagshipRow,
                  const SizedBox(height: 10),
                  Column(children: rows),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PopularToolRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool isFlagship;
  final String? badgeText;

  const _PopularToolRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.isFlagship = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isFlagship ? const Color(0xFFFFF7E6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isFlagship ? const Color(0xFFFFD166) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isFlagship ? const Color(0xFFFFC72C).withValues(alpha: 0.18) : const Color(0xFFEFF4FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFlagship) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC72C),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'FLAGSHIP',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), letterSpacing: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D), letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentDocumentsSection extends StatefulWidget {
  final bool showHeader;

  const _RecentDocumentsSection({this.showHeader = true});

  @override
  State<_RecentDocumentsSection> createState() => _RecentDocumentsSectionState();
}

class _RecentDocumentsSectionState extends State<_RecentDocumentsSection> {
  static const List<int> _retentionOptions = [20, 50, 100, 200];

  List<DocumentHistoryEntry> _entries = const [];
  String _searchQuery = '';
  String _selectedFormat = 'All';
  bool _todayOnly = false;
  int _retentionLimit = 100;

  @override
  void initState() {
    super.initState();
    _retentionLimit = DocumentHistoryService.getRetentionLimit();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entries = DocumentHistoryService.getEntries();
    });
  }

  List<String> _availableFormats() {
    final formats = _entries
        .map((e) => e.outputFormat.trim())
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...formats];
  }

  bool _isToday(DateTime value) {
    final now = DateTime.now().toLocal();
    final local = value.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  List<DocumentHistoryEntry> _filteredEntries() {
    final query = _searchQuery.trim().toLowerCase();
    return _entries.where((entry) {
      if (_selectedFormat != 'All' && entry.outputFormat != _selectedFormat) {
        return false;
      }
      if (_todayOnly && !_isToday(entry.recordedAt)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return entry.fileName.toLowerCase().contains(query) ||
          entry.outputFormat.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _clearHistory() async {
    await DocumentHistoryService.clear();
    if (!mounted) {
      return;
    }
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recent document history cleared.')),
    );
  }

  Future<void> _updateRetentionLimit(int limit) async {
    await DocumentHistoryService.setRetentionLimit(limit);
    if (!mounted) {
      return;
    }
    setState(() {
      _retentionLimit = limit;
      _entries = DocumentHistoryService.getEntries();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('History retention updated to last $limit entries.')),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  String _formatWhen(DateTime time) {
    final local = time.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries();
    final formats = _availableFormats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showHeader)
                const Expanded(
                  child: Text(
                    'Document History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Manage recent outputs from the top menu options.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              if (widget.showHeader)
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (widget.showHeader)
                TextButton.icon(
                  onPressed: _entries.isEmpty ? null : _clearHistory,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: _retentionLimit,
                  isExpanded: true,
                  items: _retentionOptions
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('Keep $value'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null && value != _retentionLimit) {
                      _updateRetentionLimit(value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Retention',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search file name or format',
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFormat,
                  isExpanded: true,
                  items: formats
                      .map(
                        (format) => DropdownMenuItem<String>(
                          value: format,
                          child: Text(
                            format,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedFormat = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Output format',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Today only'),
                selected: _todayOnly,
                onSelected: (value) {
                  setState(() {
                    _todayOnly = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Showing ${filteredEntries.length} of ${_entries.length}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No recent downloads yet. Completed outputs will appear here automatically.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            )
          else if (filteredEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No items match current filters.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            )
          else
            ...filteredEntries.take(10).map(
              (entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.outputFormat} • ${_formatBytes(entry.fileSizeBytes)} • ${_formatWhen(entry.recordedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyUsageQuotaSection extends StatefulWidget {
  final bool showHeader;

  const _DailyUsageQuotaSection({this.showHeader = true});

  @override
  State<_DailyUsageQuotaSection> createState() => _DailyUsageQuotaSectionState();
}

class _DailyUsageQuotaSectionState extends State<_DailyUsageQuotaSection> {
  late UsageQuotaSummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = UsageQuotaService.getTodaySummary();
  }

  void _refresh() {
    setState(() {
      _summary = UsageQuotaService.getTodaySummary();
    });
  }

  Future<void> _clearToday() async {
    await UsageQuotaService.clearToday();
    if (!mounted) {
      return;
    }
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Today usage counters cleared.')),
    );
  }

  Color _statusColor(int used, int limit) {
    final ratio = limit == 0 ? 0.0 : used / limit;
    if (ratio >= 1) {
      return const Color(0xFFB91C1C);
    }
    if (ratio >= 0.8) {
      return const Color(0xFFB45309);
    }
    return const Color(0xFF166534);
  }

  Widget _metric(String label, int used, int limit) {
    final color = _statusColor(used, limit);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              '$used / $limit',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool nearOrOverLimit =
        _summary.conversions >= (_summary.conversionLimit * 0.8) ||
        _summary.compressions >= (_summary.compressionLimit * 0.8) ||
        _summary.merges >= (_summary.mergeLimit * 0.8) ||
        _summary.splits >= (_summary.splitLimit * 0.8);
    final bool overLimit =
        _summary.conversions >= _summary.conversionLimit ||
        _summary.compressions >= _summary.compressionLimit ||
        _summary.merges >= _summary.mergeLimit ||
        _summary.splits >= _summary.splitLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showHeader)
                const Expanded(
                  child: Text(
                    'Daily Usage',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Today\'s usage counters',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                ),
              if (widget.showHeader)
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F172A), visualDensity: VisualDensity.compact),
                ),
              if (widget.showHeader)
                TextButton.icon(
                  onPressed: _clearToday,
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C), visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Local free-tier counters for today. Upgrade prompts can be attached to these limits next.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
          if (nearOrOverLimit) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: overLimit ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: overLimit ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                ),
              ),
              child: Text(
                overLimit
                    ? 'One or more free-tier limits are reached today. User should continue with a paid plan or wait for daily reset.'
                    : 'Usage is nearing today\'s free-tier limit. This is the right point to show upgrade guidance.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: overLimit ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _metric('Convert', _summary.conversions, _summary.conversionLimit),
              const SizedBox(width: 8),
              _metric('Compress', _summary.compressions, _summary.compressionLimit),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric('Merge', _summary.merges, _summary.mergeLimit),
              const SizedBox(width: 8),
              _metric('Split', _summary.splits, _summary.splitLimit),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserAccountPrivacySection extends StatefulWidget {
  final bool showHeader;

  const _UserAccountPrivacySection({this.showHeader = true});

  @override
  State<_UserAccountPrivacySection> createState() => _UserAccountPrivacySectionState();
}

class _UserAccountPrivacySectionState extends State<_UserAccountPrivacySection> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  static const List<String> _countryOptions = <String>[
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Singapore',
    'UAE',
    'Other',
  ];
  static const Map<String, String> _countryDialCodeMap = <String, String>{
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'Canada': '+1',
    'Australia': '+61',
    'Germany': '+49',
    'France': '+33',
    'Singapore': '+65',
    'UAE': '+971',
    'Other': '+00',
  };
  static const Map<String, String> _localeCountryMap = <String, String>{
    'IN': 'India',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'AU': 'Australia',
    'DE': 'Germany',
    'FR': 'France',
    'SG': 'Singapore',
    'AE': 'UAE',
  };

  String _selectedCountry = 'India';
  String _selectedCountryCode = '+91';
  bool _googleLoginPreferred = false;

  String _detectCountryByLocale() {
    final language = html.window.navigator.language?.toUpperCase() ?? '';
    if (!language.contains('-')) {
      return 'India';
    }
    final region = language.split('-').last;
    return _localeCountryMap[region] ?? 'India';
  }

  @override
  void initState() {
    super.initState();
    final profile = UserAccountService.getProfile();
    final localeCountry = _detectCountryByLocale();
    _nameController = TextEditingController(text: profile.displayName);
    _emailController = TextEditingController(text: profile.email);
    _mobileController = TextEditingController(text: profile.mobileNumber);
    _selectedCountry = profile.country.isNotEmpty ? profile.country : localeCountry;
    _selectedCountryCode = profile.countryCode.isNotEmpty
      ? profile.countryCode
      : (_countryDialCodeMap[_selectedCountry] ?? '+91');
    _googleLoginPreferred = profile.googleLoginPreferred;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    if (email.isEmpty || _selectedCountry.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country and Email are required.')),
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (mobile.isNotEmpty && !RegExp(r'^[0-9]{6,15}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number.')),
      );
      return;
    }

    final previousProfile = UserAccountService.getProfile();
    final profile = previousProfile.copyWith(
      displayName: name,
      email: email,
      country: _selectedCountry,
      countryCode: _selectedCountryCode,
      mobileNumber: mobile,
      historyEnabled: true,
      googleLoginPreferred: _googleLoginPreferred,
    );

    await UserAccountService.saveProfile(profile);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account details saved.')),
    );
  }

  void _loginWithGoogle() {
    html.window.open('https://accounts.google.com/signin', '_blank');
    setState(() {
      _googleLoginPreferred = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google sign-in page opened.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            const Text(
              'User Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Update details to continue.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email ID',
              hintText: 'name@example.com',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCountry,
            items: _countryOptions
                .map(
                  (country) => DropdownMenuItem<String>(
                    value: country,
                    child: Text(country),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedCountry = value;
                _selectedCountryCode = _countryDialCodeMap[value] ?? _selectedCountryCode;
              });
            },
            decoration: InputDecoration(
              labelText: 'Country',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 122,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCountryCode,
                  items: _countryDialCodeMap.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.value,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCountryCode = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Code',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number (optional for login)',
                    hintText: '9876543210',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loginWithGoogle,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 20),
              label: const Text('Login with Google'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Create Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
