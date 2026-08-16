import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

import '../Services/admin_remote_auth_service.dart';
import '../Services/auth_router_service.dart';
import '../Services/coupon_service.dart';
import '../Services/owner_admin_access_service.dart';
import '../Utils/web_safe_browser.dart';
import '../Services/plan_catalog_service.dart';
import '../Widgets/brand_logo_button.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late PlanCatalogConfig _config;
  late List<String> _auditEntries;
  late String _activeGateway;
  late bool _checkoutEnabled;
  late bool _requireAccount;
  late bool _resumeBuilderEnabled;
  late String _resumeHeadline;
  late int _couponCount;
  late int _planCount;
  late int _toolAccessCount;
  String? _csvExportError;
  bool _isCsvExporting = false;

  static const String _auditStorageKey = 'jobready_admin_activity_log_v1_1';
  static const String _checkoutStorageKey = 'jobready_admin_checkout_settings_v1_1';
  static const String _resumeStorageKey = 'jobready_admin_resume_settings_v1_1';

  @override
  void initState() {
    super.initState();
    if (!OwnerAdminAccessService.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
      });
      return;
    }

    if (!OwnerAdminAccessService.isTwoFactorVerifiedForSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/admin-2fa', (route) => false);
      });
      return;
    }

    _config = PlanCatalogService.load();
    _auditEntries = _loadAuditEntries();
    final checkoutSettings = _loadCheckoutSettings();
    _activeGateway = checkoutSettings['gateway'] as String? ?? 'razorpay';
    _checkoutEnabled = checkoutSettings['checkout_enabled'] as bool? ?? true;
    _requireAccount = checkoutSettings['require_account'] as bool? ?? true;
    final resumeSettings = _loadResumeSettings();
    _resumeBuilderEnabled = resumeSettings['enabled'] as bool? ?? true;
    _resumeHeadline = resumeSettings['headline'] as String? ?? 'Resume Builder';
    _refreshOverviewStats();
  }

  void _refreshOverviewStats() {
    final enabledToolNames = <String>{};
    for (final tools in _config.enabledToolsByPlan.values) {
      for (final tool in tools) {
        enabledToolNames.add(tool);
      }
    }
    _couponCount = CouponService.getAllCoupons().length;
    _planCount = _config.inrPrices.length;
    _toolAccessCount = enabledToolNames.length;
  }

  List<String> _loadAuditEntries() {
    try {
      final raw = WebSafeBrowser.readLocalStorage(_auditStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return <String>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((entry) => entry.toString()).toList(growable: false);
      }
    } catch (_) {}
    return <String>[];
  }

  Map<String, dynamic> _loadCheckoutSettings() {
    try {
      final raw = WebSafeBrowser.readLocalStorage(_checkoutStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Map<String, dynamic> _loadResumeSettings() {
    try {
      final raw = WebSafeBrowser.readLocalStorage(_resumeStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _storeAuditEntry(String entry) {
    final updated = <String>[..._auditEntries, '${DateTime.now().toIso8601String()} :: $entry'];
    if (updated.length > 12) {
      updated.removeRange(0, updated.length - 12);
    }
    _auditEntries = updated;
    try {
      WebSafeBrowser.writeLocalStorage(_auditStorageKey, jsonEncode(updated));
    } catch (_) {}
  }

  void _persistCheckoutSettings() {
    final data = <String, dynamic>{
      'gateway': _activeGateway,
      'checkout_enabled': _checkoutEnabled,
      'require_account': _requireAccount,
    };
    try {
      WebSafeBrowser.writeLocalStorage(_checkoutStorageKey, jsonEncode(data));
    } catch (_) {}
  }

  void _persistResumeSettings() {
    final data = <String, dynamic>{
      'enabled': _resumeBuilderEnabled,
      'headline': _resumeHeadline,
    };
    try {
      WebSafeBrowser.writeLocalStorage(_resumeStorageKey, jsonEncode(data));
    } catch (_) {}
  }

  void _openPricingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PricingDialog(
        initialConfig: _config,
        onSave: (config) {
          setState(() {
            _config = config;
            _refreshOverviewStats();
          });
          _storeAuditEntry('Pricing settings updated');
        },
      ),
    );
  }

  void _openPromoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PromoDialog(
        onSaved: () {
          setState(() {
            _refreshOverviewStats();
          });
          _storeAuditEntry('Promo codes updated');
        },
      ),
    );
  }

  void _openPaymentsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          return AlertDialog(
            title: const Text('Payments & access'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Checkout enabled'),
                  value: _checkoutEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      _checkoutEnabled = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require account before checkout'),
                  value: _requireAccount,
                  onChanged: (value) {
                    setDialogState(() {
                      _requireAccount = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _activeGateway,
                  decoration: const InputDecoration(labelText: 'Primary gateway'),
                  items: const [
                    DropdownMenuItem(value: 'razorpay', child: Text('Razorpay')),
                    DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                    DropdownMenuItem(value: 'cashfree', child: Text('Cashfree')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _activeGateway = value;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _persistCheckoutSettings();
                    _refreshOverviewStats();
                  });
                  _storeAuditEntry('Payment settings updated');
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAnalyticsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Analytics & logs'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active coupons: ${CouponService.getAllCoupons().length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Saved plan catalog: ${_config.inrPrices.length} plan entries'),
              const SizedBox(height: 12),
              const Text('Recent admin activity', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_auditEntries.isEmpty)
                const Text('No activity recorded yet.')
              else
                ..._auditEntries.reversed.take(6).map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $entry', style: const TextStyle(fontSize: 12)),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _auditEntries = <String>[];
                try {
                  WebSafeBrowser.removeLocalStorage(_auditStorageKey);
                } catch (_) {}
              });
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Clear logs'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openResumeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          return AlertDialog(
            title: const Text('Resume builder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resume builder enabled'),
                  value: _resumeBuilderEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      _resumeBuilderEnabled = value;
                    });
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Default headline'),
                  controller: TextEditingController(text: _resumeHeadline),
                  onChanged: (value) {
                    setDialogState(() {
                      _resumeHeadline = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _persistResumeSettings();
                    _refreshOverviewStats();
                  });
                  _storeAuditEntry('Resume builder settings updated');
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logoutAdmin() async {
    await AuthRouterService.clearAuthentication();
    OwnerAdminAccessService.lock();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
  }

  void _openGstReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _SalesAuditDialog(mode: 'gst'),
    );
  }

  void _openSalesOrdersDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _SalesAuditDialog(mode: 'orders'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoButton(
              size: 30,
              padding: const EdgeInsets.all(2),
              tooltip: 'Go to home',
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logoutAdmin,
            icon: const Icon(Icons.logout_rounded),
          ),
          IconButton(
            tooltip: 'Back to home',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F4EE), Color(0xFFF2F7FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Owner controls',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage pricing, coupons, payment access, logs, and resume-builder settings from one secure landing screen.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _logoutAdmin,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFFF1F2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live owner overview',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryChip(label: 'Configured plans', value: '$_planCount'),
                          _SummaryChip(label: 'Active coupons', value: '$_couponCount'),
                          _SummaryChip(label: 'Tool access rules', value: '$_toolAccessCount'),
                          _SummaryChip(label: 'Checkout', value: _checkoutEnabled ? 'Enabled' : 'Disabled'),
                          _SummaryChip(label: 'Resume builder', value: _resumeBuilderEnabled ? 'Enabled' : 'Disabled'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _AdminCard(
                      title: 'Pricing & plans',
                      description: 'Adjust plan pricing and tool permissions for each package.',
                      icon: Icons.price_change_outlined,
                      onTap: () => _openPricingDialog(context),
                    ),
                    _AdminCard(
                      title: 'Promo codes',
                      description: 'Create and manage campaign discounts and coupon availability.',
                      icon: Icons.local_offer_outlined,
                      onTap: () => _openPromoDialog(context),
                    ),
                    _AdminCard(
                      title: 'Payments & access',
                      description: 'Control checkout availability, account requirements, and gateway defaults.',
                      icon: Icons.credit_card_outlined,
                      onTap: () => _openPaymentsDialog(context),
                    ),
                    _AdminCard(
                      title: 'GST Report (GSTR-1 Ready)',
                      description: 'Tax filing export for your CA and the GST portal, with B2B / B2C / SEZ classification.',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => _openGstReportDialog(context),
                    ),
                    _AdminCard(
                      title: 'Sales & Orders Report',
                      description: 'Internal operations export for accounting, payments, and order reconciliation.',
                      icon: Icons.shopping_cart_checkout_outlined,
                      onTap: () => _openSalesOrdersDialog(context),
                    ),
                    _AdminCard(
                      title: 'Analytics & logs',
                      description: 'Review recent admin activity and the current live system summary.',
                      icon: Icons.analytics_outlined,
                      onTap: () => _openAnalyticsDialog(context),
                    ),
                    _AdminCard(
                      title: 'Resume builder',
                      description: 'Enable the builder and set the default resume experience.',
                      icon: Icons.article_outlined,
                      onTap: () => _openResumeDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Material(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF4F46E5), size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.45,
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

class _PricingDialog extends StatefulWidget {
  final PlanCatalogConfig initialConfig;
  final ValueChanged<PlanCatalogConfig> onSave;

  const _PricingDialog({required this.initialConfig, required this.onSave});

  @override
  State<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends State<_PricingDialog> {
  static const List<String> _plans = <String>['Free', '7Days', 'Monthly', 'Yearly', 'Lifetime'];
  static const List<String> _allTools = PlanCatalogConfig.registeredToolNames;

  late String _selectedPlan;
  late Map<String, TextEditingController> _inrControllers;
  late Map<String, TextEditingController> _usdControllers;
  late Map<String, TextEditingController> _quotaControllers;
  late Map<String, TextEditingController> _voiceQuotaControllers;
  late Map<String, List<String>> _enabledToolsByPlan;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = 'Monthly';
    _hydrateFromConfig(widget.initialConfig);
    _loadFromBackend();
  }

  @override
  void dispose() {
    for (final controller in _inrControllers.values) {
      controller.dispose();
    }
    for (final controller in _usdControllers.values) {
      controller.dispose();
    }
    for (final controller in _quotaControllers.values) {
      controller.dispose();
    }
    for (final controller in _voiceQuotaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrateFromConfig(PlanCatalogConfig config) {
    _inrControllers = {
      for (final plan in _plans) plan: TextEditingController(text: (config.inrPrices[plan] ?? 0).toString())
    };
    _usdControllers = {
      for (final plan in _plans) plan: TextEditingController(text: (config.usdPrices[plan] ?? 0).toString())
    };
    _quotaControllers = {
      for (final plan in _plans)
        plan: TextEditingController(text: config.userQuotasByPlan[plan] ?? PlanCatalogConfig.defaults().userQuotasByPlan[plan] ?? '2')
    };
    _voiceQuotaControllers = {
      for (final plan in _plans)
        plan: TextEditingController(text: config.voiceQuotasByPlan[plan] ?? PlanCatalogConfig.defaults().voiceQuotasByPlan[plan] ?? '5')
    };
    _enabledToolsByPlan = {
      for (final plan in _plans) plan: List<String>.from(config.enabledToolsByPlan[plan] ?? const <String>[])
    };
  }

  void _save() {
    final defaults = PlanCatalogConfig.defaults();
    final quotas = <String, String>{};
    final voiceQuotas = <String, String>{};
    for (final plan in _plans) {
      final raw = _quotaControllers[plan]!.text.trim();
      quotas[plan] = raw.isEmpty ? (defaults.userQuotasByPlan[plan] ?? '2') : raw;
      final rawVoice = _voiceQuotaControllers[plan]!.text.trim();
      voiceQuotas[plan] = rawVoice.isEmpty ? (defaults.voiceQuotasByPlan[plan] ?? '5') : rawVoice;
    }

    final config = PlanCatalogConfig(
      inrPrices: {
        for (final plan in _plans) plan: double.tryParse(_inrControllers[plan]!.text.trim()) ?? 0,
      },
      usdPrices: {
        for (final plan in _plans) plan: double.tryParse(_usdControllers[plan]!.text.trim()) ?? 0,
      },
      enabledToolsByPlan: {
        for (final plan in _plans) plan: List<String>.from(_enabledToolsByPlan[plan] ?? const <String>[])
      },
      userQuotasByPlan: quotas,
      voiceQuotasByPlan: voiceQuotas,
    );
    _saveToBackend(config);
  }

  Future<void> _loadFromBackend() async {
    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/public/plan-catalog');
      final response = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final catalog = (decoded['catalog'] as Map?) ?? {};
        final serverConfig = PlanCatalogConfig.fromMap({
          'inr_prices': catalog['inr_prices'],
          'usd_prices': catalog['usd_prices'],
          'enabled_tools_by_plan': widget.initialConfig.enabledToolsByPlan.map((k, v) => MapEntry(k, v)),
          // Use the fresh server values (not the possibly-stale initialConfig)
          // so an admin-saved "0" quota isn't silently reset back to the
          // hardcoded defaults every time this dialog re-opens.
          'user_quotas_by_plan': catalog['user_quotas_by_plan'] ?? widget.initialConfig.userQuotasByPlan,
          'voice_quotas_by_plan': catalog['voice_quotas_by_plan'] ?? widget.initialConfig.voiceQuotasByPlan,
        });
        setState(() {
          _hydrateFromConfig(serverConfig);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Keep the locally-cached values already hydrated in initState as a fallback.
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToBackend(PlanCatalogConfig config) async {
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Admin session is required to save pricing.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/plan-catalog');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $adminToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(config.toMap()),
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isSaving = false;
          _statusIsError = true;
          _statusMessage = 'Save failed (${response.statusCode}). Prices were not published to the live site.';
        });
        return;
      }
      await PlanCatalogService.save(config);
      widget.onSave(config);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _statusIsError = true;
        _statusMessage = 'Save failed. ${error.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTools = _enabledToolsByPlan[_selectedPlan] ?? const <String>[];
    return AlertDialog(
      title: const Text('Pricing & plans'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prices entered here are the final, all-in-one amount shown to customers '
                '(already includes 18% GST). They publish to the live site immediately on Save.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (_isLoading) const LinearProgressIndicator(),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusIsError ? const Color(0xFFFFF1F2) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusIsError ? const Color(0xFFDC2626) : const Color(0xFF0EA5E9)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusIsError ? const Color(0xFF991B1B) : const Color(0xFF0C4A6E),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPlan,
                decoration: const InputDecoration(labelText: 'Plan to edit'),
                items: _plans.map((plan) => DropdownMenuItem(value: plan, child: Text(plan))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPlan = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inrControllers[_selectedPlan],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'INR price'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _usdControllers[_selectedPlan],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'USD price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quotaControllers[_selectedPlan],
                decoration: const InputDecoration(
                  labelText: 'User Quota',
                  helperText: 'Examples: 2, 50, 200, 1000, Unlimited',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _voiceQuotaControllers[_selectedPlan],
                decoration: const InputDecoration(
                  labelText: 'Voice Commands Quota',
                  helperText: 'Examples: 5, 50, 200, 1000, Unlimited',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tool access', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTools.map((tool) {
                  final isSelected = selectedTools.contains(tool);
                  return FilterChip(
                    label: Text(tool),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        final tools = List<String>.from(_enabledToolsByPlan[_selectedPlan] ?? const <String>[]);
                        if (value) {
                          if (!tools.contains(tool)) {
                            tools.add(tool);
                          }
                        } else {
                          tools.remove(tool);
                        }
                        _enabledToolsByPlan[_selectedPlan] = tools;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_isLoading || _isSaving) ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _SalesAuditDialog extends StatefulWidget {
  /// 'gst' renders the GSTR-1 filing export, 'orders' the internal sales report.
  final String mode;

  const _SalesAuditDialog({this.mode = 'gst'});

  @override
  State<_SalesAuditDialog> createState() => _SalesAuditDialogState();
}

class _SalesAuditDialogState extends State<_SalesAuditDialog> {
  String _range = 'financial-year';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _filterMode = 'all';
  String? _csvExportError;
  bool _isCsvExporting = false;
  bool _isExcelExporting = false;
  String? _excelExportError;
  Map<String, dynamic>? _reconciliationSummary;
  bool _isLoadingSummary = false;
  final TextEditingController _invoiceQueryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController(text: 'Delhi');
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _sampleEmailController = TextEditingController(text: 'rajesh.khola@gmail.com');
  bool _isSendingSample = false;
  String? _sampleStatus;
  bool _isDataToolRunning = false;
  String? _dataToolStatus;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  bool get _isGstMode => widget.mode != 'orders';

  String get _dialogTitle => _isGstMode ? 'GST Report (GSTR-1 Ready)' : 'Sales & Orders Report';

  String get _dialogPurpose => _isGstMode
      ? 'Tax filing export for your CA / the GST portal. Columns: Invoice Number, Invoice Date, Customer Name, Customer GSTIN, Place of Supply, Taxable Value, IGST, CGST, SGST, Total Invoice Value, Transaction Type (B2B / B2C / SEZ with Payment of IGST).'
      : 'Internal business operations, accounting and order reconciliation. Columns: Order/Payment Ref, Invoice Number, Order Date, Customer Name, Email, Phone, Plan/Item, Gross Amount, Discount/Coupon, Net Paid, Gateway Status, Access Duration.';

  String get _exportPath => _isGstMode
      ? '/api/admin/gst-report/export'
      : '/api/admin/sales-orders-report/export';

  String get _exportFilePrefix => _isGstMode ? 'GSTR1_Report' : 'Sales_Orders_Report';

  @override
  void initState() {
    super.initState();
    if (_isGstMode) {
      _loadReconciliationSummary();
    }
  }

  String get _filterLabel {
    switch (_filterMode) {
      case 'b2b':
        return 'B2B';
      case 'b2c':
        return 'B2C';
      case 'sez':
        return 'SEZ';
      case 'state':
        return 'State';
      default:
        return 'All';
    }
  }

  Future<void> _pickDate(bool isFromDate) async {
    final chosenDate = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (chosenDate == null) {
      return;
    }
    setState(() {
      if (isFromDate) {
        _fromDate = chosenDate;
      } else {
        _toDate = chosenDate;
      }
    });
  }

  Map<String, String> _buildExportQueryParams() {
    final fromDate = _fromDate?.toIso8601String().split('T').first;
    final toDate = _toDate?.toIso8601String().split('T').first;
    final hasCustomWindow = (fromDate != null && fromDate.isNotEmpty) || (toDate != null && toDate.isNotEmpty);

    final params = <String, String>{
      // Only switch to 'custom' when a real window is picked, otherwise the
      // selected filing period chip is what should drive the export.
      'range': hasCustomWindow ? 'custom' : _range,
      'format': 'csv',
      'filter': _filterLabel,
    };

    if (fromDate != null && fromDate.isNotEmpty) {
      params['from'] = fromDate;
      params['fromDate'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      params['to'] = toDate;
      params['toDate'] = toDate;
    }

    switch (_filterMode) {
      case 'b2b':
        params['filter'] = 'B2B';
        params['transactionType'] = 'B2B';
        break;
      case 'b2c':
        params['filter'] = 'B2C';
        params['transactionType'] = 'B2C';
        break;
      case 'sez':
        params['filter'] = 'SEZ';
        params['sezStatus'] = 'YES';
        break;
      case 'state':
        params['filter'] = 'State';
        final state = _stateController.text.trim();
        if (state.isNotEmpty) {
          params['state'] = state;
        }
        break;
      default:
        params['filter'] = 'All';
        break;
    }

    // The state box is only a filter when 'State' mode is chosen; otherwise its
    // default value would silently exclude every other state from the export.
    final gstin = _gstinController.text.trim();
    if (gstin.isNotEmpty && _filterMode == 'b2b') {
      params['gstin'] = gstin;
    }

    return params;
  }

  Future<void> _loadReconciliationSummary() async {
    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final queryParams = Map<String, String>.from(_buildExportQueryParams())..['format'] = 'json';
      final response = await _authedRequest('GET', '/api/admin/gst-report/export', queryParams: queryParams);
      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        setState(() {
          _isLoadingSummary = false;
        });
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final report = (decoded['report'] as Map?) ?? {};
      setState(() {
        _isLoadingSummary = false;
        _reconciliationSummary = (report['summary'] as Map?)?.cast<String, dynamic>();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _runTransactionDiagnostics() async {
    setState(() {
      _isDataToolRunning = true;
      _dataToolStatus = null;
    });
    try {
      final response = await _authedRequest('GET', '/api/admin/transactions/diagnostics', queryParams: _buildExportQueryParams());
      if (!mounted) return;
      if (response == null) {
        setState(() {
          _isDataToolRunning = false;
          _dataToolStatus = 'Admin session is required.';
        });
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final d = (decoded['diagnostics'] as Map?) ?? {};
      setState(() {
        _isDataToolRunning = false;
        _dataToolStatus = 'Total: ${d['totalTransactions']} | Completed: ${d['completedTransactions']} | '
            'In selected range: ${d['rowsInSelectedRange']}\n'
            'Placeholder invoice numbers: ${d['placeholderInvoiceNumbers']} | Dummy GSTINs: ${d['dummyGstins']}\n'
            'Range: ${d['earliestTransaction']} to ${d['latestTransaction']}\n'
            'Persistent disk configured: ${d['persistentDiskConfigured']} | Store file exists: ${d['storageFileExists']}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDataToolRunning = false;
        _dataToolStatus = 'Diagnostics failed. ${error.toString()}';
      });
    }
  }

  Future<void> _sanitizeLegacyRows({required bool apply}) async {
    setState(() {
      _isDataToolRunning = true;
      _dataToolStatus = null;
    });
    try {
      final response = await _authedRequest(
        'POST',
        '/api/admin/transactions/sanitize',
        queryParams: {'apply': apply ? 'true' : 'false'},
      );
      if (!mounted) return;
      if (response == null) {
        setState(() {
          _isDataToolRunning = false;
          _dataToolStatus = 'Admin session is required.';
        });
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final r = (decoded['result'] as Map?) ?? {};
      final changes = (r['changes'] as List?) ?? [];
      final preview = changes.take(5).map((c) {
        final fixes = ((c as Map)['fixes'] as List?) ?? [];
        return '  ${c['transactionId']}: ${fixes.map((f) => '${(f as Map)['field']} "${f['from']}" -> "${f['to']}"').join('; ')}';
      }).join('\n');
      setState(() {
        _isDataToolRunning = false;
        _dataToolStatus = '${apply ? 'APPLIED' : 'PREVIEW (nothing written)'} - '
            'total ${r['totalTransactions']}, affected ${r['affectedTransactions']}'
            '${changes.isEmpty ? '' : '\n$preview'}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDataToolRunning = false;
        _dataToolStatus = 'Sanitize failed. ${error.toString()}';
      });
    }
  }

  Future<String?> _promptAdminOtp() async {
    final otpController = TextEditingController();
    String? otpError;
    bool isVerifying = false;
    bool isResending = false;

    final token = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Enter admin OTP'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A 6-digit OTP was sent to ${AdminRemoteAuthService.deliveryEmail.isNotEmpty ? AdminRemoteAuthService.deliveryEmail : 'your admin email'}. It is valid for 5 minutes.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: '6-digit OTP',
                        errorText: otpError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isResending || isVerifying
                      ? null
                      : () async {
                          setDialogState(() => isResending = true);
                          final sent = await AdminRemoteAuthService.resendOtp();
                          setDialogState(() {
                            isResending = false;
                            otpError = sent ? null : 'Could not resend the OTP. Please sign in again.';
                          });
                        },
                  child: Text(isResending ? 'Resending...' : 'Resend OTP'),
                ),
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = otpController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() => otpError = 'Enter the OTP that was emailed to you.');
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            otpError = null;
                          });
                          final verifiedToken = await AdminRemoteAuthService.verify(code);
                          if (verifiedToken == null || verifiedToken.isEmpty) {
                            setDialogState(() {
                              isVerifying = false;
                              otpError = 'Invalid or expired OTP. Try again or resend.';
                            });
                            return;
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(verifiedToken);
                          }
                        },
                  child: Text(isVerifying ? 'Verifying...' : 'Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    otpController.dispose();
    return token;
  }

  Future<bool> _refreshExpiredAdminSession() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool passwordVisible = false;

    final credentials = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Admin session expired'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your admin session expired. Sign in again to continue.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Admin email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: !passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: passwordVisible ? 'Hide password' : 'Show password',
                          onPressed: () => setDialogState(() => passwordVisible = !passwordVisible),
                          icon: Icon(
                            passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: const Color(0xFF64748B),
                          ),
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
                  onPressed: () {
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();
                    if (email.isEmpty || password.isEmpty) {
                      return;
                    }
                    Navigator.of(dialogContext).pop({'email': email, 'password': password});
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (credentials == null) {
      return false;
    }

    final result = await AdminRemoteAuthService.login(credentials['email'] ?? '', credentials['password'] ?? '');
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Admin authentication failed. Please try again.')),
        );
      }
      return false;
    }

    // Login succeeds with an empty token when 2FA is on; the OTP step issues the real token.
    var authToken = result.authToken;
    if (authToken.isEmpty && AdminRemoteAuthService.hasPendingChallenge && mounted) {
      authToken = await _promptAdminOtp() ?? '';
    }

    if (authToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin verification was not completed.')),
        );
      }
      return false;
    }

    await AuthRouterService.markAdminAuthenticated(authToken: authToken);
    return true;
  }

  Future<void> _downloadCsvReport({bool retryAfterRefresh = false}) async {
    setState(() {
      _csvExportError = null;
      _isCsvExporting = true;
    });

    final params = _buildExportQueryParams();
    final fromDate = params['fromDate'] ?? params['from'];
    final toDate = params['toDate'] ?? params['to'];
    final normalizedFilter = params['filter'] ?? 'All';

    final exportParams = <String, String>{
      'range': 'custom',
      'format': 'csv',
      'filter': normalizedFilter,
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
    };

    final typeFilter = params['transactionType'];
    if (typeFilter != null && typeFilter.isNotEmpty) {
      exportParams['transactionType'] = typeFilter;
    }

    final stateFilter = params['state'];
    if (stateFilter != null && stateFilter.isNotEmpty) {
      exportParams['state'] = stateFilter;
    }

    final gstinFilter = params['gstin'];
    if (gstinFilter != null && gstinFilter.isNotEmpty) {
      exportParams['gstin'] = gstinFilter;
    }

    final sezFilter = params['sezStatus'];
    if (sezFilter != null && sezFilter.isNotEmpty) {
      exportParams['sezStatus'] = sezFilter;
    }

    final uri = Uri.https(
      'jobready-india.onrender.com',
      _exportPath,
      exportParams,
    );

    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _isCsvExporting = false;
        _csvExportError = 'Admin session is required to export the sales CSV.';
      });
      return;
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $adminToken',
          'Accept': 'text/csv,text/plain,*/*',
          'Content-Type': 'application/json',
        },
      );

      final bodyText = response.body;
      final isExpiredTokenResponse = response.statusCode == 401 || bodyText.contains('Token expired');
      if (isExpiredTokenResponse && !retryAfterRefresh) {
        final refreshed = await _refreshExpiredAdminSession();
        if (refreshed) {
          await _downloadCsvReport(retryAfterRefresh: true);
          return;
        }
        throw Exception('Admin session expired. Please sign in again to export.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Export request failed with status ${response.statusCode}. Response: $bodyText');
      }

      final csvData = response.body;
      if (csvData.trim().isEmpty) {
        setState(() {
          _isCsvExporting = false;
          _csvExportError = 'The CSV export is empty.';
        });
        return;
      }

      final csvBytes = response.bodyBytes.isNotEmpty ? response.bodyBytes : utf8.encode(csvData);
      final blob = html.Blob([csvBytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${_exportFilePrefix}_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      setState(() {
        _isCsvExporting = false;
      });
    } catch (error) {
      setState(() {
        _isCsvExporting = false;
        _csvExportError = 'Unable to download the CSV export. Please retry. ${error.toString()}';
      });
    }
  }

  Future<void> _downloadExcelReport({bool retryAfterRefresh = false}) async {
    setState(() {
      _excelExportError = null;
      _isExcelExporting = true;
    });

    final params = _buildExportQueryParams();
    final fromDate = params['fromDate'] ?? params['from'];
    final toDate = params['toDate'] ?? params['to'];
    final normalizedFilter = params['filter'] ?? 'All';

    final exportParams = <String, String>{
      'range': 'custom',
      'filter': normalizedFilter,
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
    };

    final typeFilter = params['transactionType'];
    if (typeFilter != null && typeFilter.isNotEmpty) {
      exportParams['transactionType'] = typeFilter;
    }

    final stateFilter = params['state'];
    if (stateFilter != null && stateFilter.isNotEmpty) {
      exportParams['state'] = stateFilter;
    }

    final gstinFilter = params['gstin'];
    if (gstinFilter != null && gstinFilter.isNotEmpty) {
      exportParams['gstin'] = gstinFilter;
    }

    final sezFilter = params['sezStatus'];
    if (sezFilter != null && sezFilter.isNotEmpty) {
      exportParams['sezStatus'] = sezFilter;
    }

    final uri = Uri.https(
      'jobready-india.onrender.com',
      '/api/admin/gst-report/export-excel',
      exportParams,
    );

    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _isExcelExporting = false;
        _excelExportError = 'Admin session is required to export the GSTR-1 Excel workbook.';
      });
      return;
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $adminToken',
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,*/*',
        },
      );

      final isExpiredTokenResponse = response.statusCode == 401 || response.body.contains('Token expired');
      if (isExpiredTokenResponse && !retryAfterRefresh) {
        final refreshed = await _refreshExpiredAdminSession();
        if (refreshed) {
          await _downloadExcelReport(retryAfterRefresh: true);
          return;
        }
        throw Exception('Admin session expired. Please sign in again to export.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Export request failed with status ${response.statusCode}.');
      }

      if (response.bodyBytes.isEmpty) {
        setState(() {
          _isExcelExporting = false;
          _excelExportError = 'The Excel export is empty.';
        });
        return;
      }

      final blob = html.Blob(
        [response.bodyBytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'GSTR1_MultiTab_${DateTime.now().millisecondsSinceEpoch}.xlsx')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      setState(() {
        _isExcelExporting = false;
      });
    } catch (error) {
      setState(() {
        _isExcelExporting = false;
        _excelExportError = 'Unable to download the Excel export. Please retry. ${error.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _invoiceQueryController.dispose();
    _stateController.dispose();
    _gstinController.dispose();
    _sampleEmailController.dispose();
    super.dispose();
  }

  Future<void> _sendSampleInvoiceEmail() async {
    final recipient = _sampleEmailController.text.trim();
    if (recipient.isEmpty) {
      setState(() => _sampleStatus = 'Enter a recipient email address first.');
      return;
    }

    setState(() {
      _isSendingSample = true;
      _sampleStatus = null;
    });

    try {
      final response = await _authedRequest(
        'POST',
        '/api/admin/email/send-sample-invoice',
        body: {'to': recipient, 'name': 'Rajesh Kumar Yadav'},
      );
      if (!mounted) {
        return;
      }
      if (response == null) {
        setState(() {
          _isSendingSample = false;
          _sampleStatus = 'Admin session is required to send the sample invoice.';
        });
        return;
      }
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      setState(() {
        _isSendingSample = false;
        _sampleStatus = ok
            ? 'Sample welcome email + invoice PDF sent to $recipient.'
            : 'Send failed (${response.statusCode}). ${response.body}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSendingSample = false;
        _sampleStatus = 'Send failed. ${error.toString()}';
      });
    }
  }

  Future<http.Response?> _authedRequest(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = false,
  }) async {
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      // No token yet: re-authenticate first, then run the request once.
      if (!retryAfterRefresh) {
        final refreshed = await _refreshExpiredAdminSession();
        if (refreshed) {
          return _authedRequest(method, path, queryParams: queryParams, body: body, retryAfterRefresh: true);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin session is required for this action.')),
        );
      }
      return null;
    }

    final uri = Uri.https('jobready-india.onrender.com', path, queryParams);
    final headers = {
      'Authorization': 'Bearer $adminToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      default:
        response = await http.get(uri, headers: headers);
    }

    final isExpiredTokenResponse = response.statusCode == 401 || response.body.contains('Token expired');
    if (isExpiredTokenResponse && !retryAfterRefresh) {
      final refreshed = await _refreshExpiredAdminSession();
      if (refreshed) {
        return _authedRequest(method, path, queryParams: queryParams, body: body, retryAfterRefresh: true);
      }
    }

    return response;
  }

  Future<void> _searchInvoices() async {
    final query = _invoiceQueryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = 'Enter an invoice number or transaction ID to search.';
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final response = await _authedRequest('GET', '/api/admin/invoices/search', queryParams: {'query': query});
      if (response == null) {
        setState(() => _isSearching = false);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Search failed with status ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final invoices = ((decoded['invoices'] as List?) ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _searchResults = invoices;
        _isSearching = false;
      });
    } catch (error) {
      setState(() {
        _isSearching = false;
        _searchError = 'Unable to search invoices. ${error.toString()}';
      });
    }
  }

  Future<void> _showAmendDialog(Map<String, dynamic> invoice) async {
    final nameController = TextEditingController(text: invoice['customerName']?.toString() ?? '');
    final companyController = TextEditingController(text: invoice['companyName']?.toString() ?? '');
    final gstinController = TextEditingController(text: invoice['gstin']?.toString() ?? '');
    final stateController = TextEditingController(text: invoice['state']?.toString() ?? '');
    final emailController = TextEditingController(text: invoice['email']?.toString() ?? '');
    final mobileController = TextEditingController();
    bool isSez = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Amend Invoice (Non-Tax Fields)'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice: ${invoice['invoiceNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Customer / Business Legal Name')),
                    const SizedBox(height: 8),
                    TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Company Name')),
                    const SizedBox(height: 8),
                    TextField(controller: gstinController, decoration: const InputDecoration(labelText: 'Customer GSTIN')),
                    const SizedBox(height: 8),
                    TextField(controller: stateController, decoration: const InputDecoration(labelText: 'Billing Address / Place of Supply (State)')),
                    const SizedBox(height: 8),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Billing Email')),
                    const SizedBox(height: 8),
                    TextField(controller: mobileController, decoration: const InputDecoration(labelText: 'Billing Mobile')),
                    CheckboxListTile(
                      value: isSez,
                      onChanged: (value) => setDialogState(() => isSez = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('SEZ Status (Yes)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save Amendment')),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await _authedRequest(
        'PATCH',
        '/api/admin/invoices/${invoice['transactionId']}/amend',
        body: {
          'customerName': nameController.text.trim(),
          'companyName': companyController.text.trim(),
          'gstin': gstinController.text.trim(),
          'state': stateController.text.trim(),
          'email': emailController.text.trim(),
          'mobile': mobileController.text.trim(),
          'sez': isSez ? 'YES' : 'NO',
        },
      );
      if (response == null) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Amend failed with status ${response.statusCode}.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice amended successfully.')));
      }
      await _searchInvoices();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amend failed: $error')));
      }
    }
  }

  Future<void> _showCreditOrDebitNoteDialog(Map<String, dynamic> invoice, {required bool isCreditNote}) async {
    final reasonController = TextEditingController();
    final taxableController = TextEditingController();
    final cgstController = TextEditingController();
    final sgstController = TextEditingController();
    final igstController = TextEditingController();
    final netController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isCreditNote ? 'Issue Credit Note' : 'Issue Debit Note'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original Invoice: ${invoice['invoiceNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
                const SizedBox(height: 8),
                TextField(
                  controller: taxableController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: isCreditNote ? 'Credited Taxable Value' : 'Differential Taxable Value'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cgstController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'CGST'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sgstController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'SGST'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: igstController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'IGST'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: netController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: isCreditNote ? 'Net Refund Amount' : 'Net Additional Amount'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isCreditNote ? 'Issue Credit Note' : 'Issue Debit Note'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    double? parseOrNull(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }

    final taxableValue = parseOrNull(taxableController.text);
    final cgstValue = parseOrNull(cgstController.text);
    final sgstValue = parseOrNull(sgstController.text);
    final igstValue = parseOrNull(igstController.text);
    final netValue = parseOrNull(netController.text);

    final body = <String, dynamic>{
      'reason': reasonController.text.trim(),
      if (taxableValue != null) (isCreditNote ? 'creditedTaxableValue' : 'differentialTaxableValue'): taxableValue,
      if (cgstValue != null) 'cgstAmount': cgstValue,
      if (sgstValue != null) 'sgstAmount': sgstValue,
      if (igstValue != null) 'igstAmount': igstValue,
      if (netValue != null) (isCreditNote ? 'netRefundAmount' : 'netAdditionalAmount'): netValue,
    };

    try {
      final response = await _authedRequest(
        'POST',
        '/api/admin/invoices/${invoice['transactionId']}/${isCreditNote ? 'credit-note' : 'debit-note'}',
        body: body,
      );
      if (response == null) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Request failed with status ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final noteKey = isCreditNote ? 'creditNote' : 'debitNote';
      final documentNumber = (decoded[noteKey] as Map<String, dynamic>?)?['documentNumber']?.toString() ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isCreditNote ? 'Credit' : 'Debit'} Note issued: $documentNumber')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to issue note: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = <Map<String, String>>[
      {'label': 'Range', 'value': _range},
      {'label': 'B2B', 'value': '0'},
      {'label': 'B2C', 'value': '0'},
      {'label': 'Revenue', 'value': '₹0.00'},
    ];

    return AlertDialog(
      title: Text(_dialogTitle),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _dialogPurpose,
                  style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('This Month'), selected: _range == 'this-month', onSelected: (_) => setState(() => _range = 'this-month')),
                  ChoiceChip(label: const Text('Quarterly'), selected: _range == 'quarterly', onSelected: (_) => setState(() => _range = 'quarterly')),
                  ChoiceChip(label: const Text('FY'), selected: _range == 'financial-year', onSelected: (_) => setState(() => _range = 'financial-year')),
                  ChoiceChip(label: const Text('Previous Year'), selected: _range == 'previous-year', onSelected: (_) => setState(() => _range = 'previous-year')),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: stats.map((item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['label'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(item['value'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ],
                  ),
                )).toList(),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Custom export filters', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'From'),
                        child: Text(_fromDate == null ? 'Select date' : _fromDate!.toLocal().toString().split(' ').first),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'To'),
                        child: Text(_toDate == null ? 'Select date' : _toDate!.toLocal().toString().split(' ').first),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isGstMode) ...[
                DropdownButtonFormField<String>(
                  value: _filterMode,
                  decoration: const InputDecoration(labelText: 'Filter'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'b2b', child: Text('B2B')),
                    DropdownMenuItem(value: 'b2c', child: Text('B2C')),
                    DropdownMenuItem(value: 'sez', child: Text('SEZ')),
                    DropdownMenuItem(value: 'state', child: Text('State')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _filterMode = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _gstinController, decoration: const InputDecoration(labelText: 'GSTIN'))),
                  ],
                ),
                const SizedBox(height: 12),
                _ReconciliationSummaryCard(
                  isLoading: _isLoadingSummary,
                  summary: _reconciliationSummary,
                  onRefresh: _isLoadingSummary ? null : _loadReconciliationSummary,
                ),
                const SizedBox(height: 12),
                const Text('Invoice search & amendment', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _invoiceQueryController,
                  decoration: const InputDecoration(labelText: 'Search by invoice number or transaction ID'),
                ),
              ],
              const SizedBox(height: 12),
              if (_csvExportError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Text(
                    _csvExportError!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (_excelExportError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Text(
                    _excelExportError!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isCsvExporting ? null : _downloadCsvReport,
                    icon: _isCsvExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: Text(_isCsvExporting ? 'Exporting...' : (_isGstMode ? 'Export GST CSV' : 'Export Orders CSV')),
                  ),
                  if (_isGstMode) ...[
                    OutlinedButton.icon(
                      onPressed: _isExcelExporting ? null : _downloadExcelReport,
                      icon: _isExcelExporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.grid_on_outlined),
                      label: Text(_isExcelExporting ? 'Exporting...' : 'Export GSTR-1 Excel (Multi-Tab)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSearching ? null : _searchInvoices,
                      icon: _isSearching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_outlined),
                      label: Text(_isSearching ? 'Searching...' : 'Search Invoice'),
                    ),
                  ],
                ],
              ),
              if (_isGstMode) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Data health & legacy cleanup', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Preview shows what would change without writing. Clean Now backs up the store first, then fixes placeholder invoice numbers (plink-...) and dummy GSTINs.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isDataToolRunning ? null : _runTransactionDiagnostics,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Check Data Health'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isDataToolRunning ? null : () => _sanitizeLegacyRows(apply: false),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview Cleanup'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isDataToolRunning ? null : () => _sanitizeLegacyRows(apply: true),
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                      label: const Text('Clean Now'),
                    ),
                  ],
                ),
                if (_isDataToolRunning) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (_dataToolStatus != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: SelectableText(
                      _dataToolStatus!,
                      style: const TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
              if (!_isGstMode) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Send sample welcome email + invoice PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Sends the exact production template to any address for review. No sale is recorded and no live invoice number is used.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sampleEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Recipient email'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSendingSample ? null : _sendSampleInvoiceEmail,
                    icon: _isSendingSample
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.mark_email_read_outlined),
                    label: Text(_isSendingSample ? 'Sending...' : 'Send Sample Invoice Email'),
                  ),
                ),
                if (_sampleStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sampleStatus!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                  ),
                ],
              ],
              if (_searchError != null) ...[
                const SizedBox(height: 8),
                Text(_searchError!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._searchResults.map((invoice) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice['invoiceNumber']?.toString() ?? invoice['transactionId']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${invoice['customerName'] ?? 'Customer'} • ${invoice['gstin']?.toString().isNotEmpty == true ? invoice['gstin'] : 'No GSTIN'} • ${invoice['state'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showAmendDialog(invoice),
                                child: const Text('Amend'),
                              ),
                              OutlinedButton(
                                onPressed: () => _showCreditOrDebitNoteDialog(invoice, isCreditNote: true),
                                child: const Text('Credit Note'),
                              ),
                              OutlinedButton(
                                onPressed: () => _showCreditOrDebitNoteDialog(invoice, isCreditNote: false),
                                child: const Text('Debit Note'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice actions', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('• amend billing address / GSTIN / customer details', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const Text('• cancel and log credit note', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const Text('• resend PDF to customer', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    Text('Active filter: $_filterLabel', style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

/// Simple GST reconciliation overview for the selected filing period: total
/// taxable sales, the output CGST/SGST/IGST breakdown, and a reminder to
/// cross-check against GSTR-2B (auto-drafted ITC statement, usually available
/// on the GST portal by the 14th of each month) before filing GSTR-3B.
class _ReconciliationSummaryCard extends StatelessWidget {
  const _ReconciliationSummaryCard({
    required this.isLoading,
    required this.summary,
    required this.onRefresh,
  });

  final bool isLoading;
  final Map<String, dynamic>? summary;
  final VoidCallback? onRefresh;

  String _money(dynamic value) {
    final amount = (value is num) ? value.toDouble() : double.tryParse('$value') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final taxableValue = summary?['netTaxableValue'] ?? summary?['totalTaxableValue'] ?? 0;
    final cgst = summary?['netCgstAmount'] ?? summary?['totalCgstAmount'] ?? 0;
    final sgst = summary?['netSgstAmount'] ?? summary?['totalSgstAmount'] ?? 0;
    final igst = summary?['netIgstAmount'] ?? summary?['totalIgstAmount'] ?? 0;
    final totalOutputGst = (cgst is num ? cgst : 0) + (sgst is num ? sgst : 0) + (igst is num ? igst : 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF166534)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Reconciliation & ITC Helper',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh summary for the selected filters',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ] else if (summary == null) ...[
            const SizedBox(height: 6),
            const Text(
              'Tap refresh to load the reconciliation summary for the selected filters.',
              style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Total Taxable Sales: ${_money(taxableValue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(
              'Output GST: CGST ${_money(cgst)} + SGST ${_money(sgst)} + IGST ${_money(igst)} = ${_money(totalOutputGst)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reminder: cross-check this Output GST against your GSTR-2B (auto-drafted ITC statement) before filing GSTR-3B - it is usually available on the GST portal by the 14th of each month.',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromoDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const _PromoDialog({required this.onSaved});

  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _valueController = TextEditingController(text: '10');
  final TextEditingController _usageLimitController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _discountType = 'percent';
  DateTime? _expiryDate;
  bool _active = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _statusMessage;
  bool _statusIsError = false;
  List<Map<String, dynamic>> _promos = <Map<String, dynamic>>[];
  final Set<String> _selectedPlans = <String>{};

  static const List<String> _planOptions = <String>['7Days', 'Monthly', 'Yearly', 'Lifetime'];
  static const Map<String, String> _planLabels = <String, String>{
    '7Days': '7 Days',
    'Monthly': 'Monthly',
    'Yearly': 'Yearly',
    'Lifetime': 'Lifetime',
  };

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _usageLimitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    final adminToken = AuthRouterService.authToken;
    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/promos');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $adminToken',
        'Accept': 'application/json',
      });
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final promos = (decoded['promos'] as List?) ?? const [];
        setState(() {
          _promos = promos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _statusIsError = true;
        _statusMessage = 'Could not load promo codes (${response.statusCode}).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusIsError = true;
        _statusMessage = 'Could not load promo codes. ${error.toString()}';
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _submit(Map<String, dynamic> payload) async {
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Admin session is required to save promo codes.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/promos');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $adminToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isSaving = false;
          _statusIsError = true;
          _statusMessage = 'Save failed (${response.statusCode}).';
        });
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final promos = (decoded['promos'] as List?) ?? const [];
      setState(() {
        _promos = promos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _isSaving = false;
        _statusIsError = false;
        _statusMessage = 'Saved.';
      });
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _statusIsError = true;
        _statusMessage = 'Save failed. ${error.toString()}';
      });
    }
  }

  Future<void> _createOrUpdate() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Promo code is required.';
      });
      return;
    }
    final value = double.tryParse(_valueController.text.trim()) ?? 0;
    if (value <= 0) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Enter a discount value greater than 0.';
      });
      return;
    }
    final usageLimit = int.tryParse(_usageLimitController.text.trim()) ?? 0;

    await _submit({
      'code': code,
      'description': _descriptionController.text.trim(),
      'discountPercent': _discountType == 'percent' ? value : 0,
      'discountFlat': _discountType == 'flat' ? value : 0,
      'validUntil': _expiryDate == null ? '' : _formatDate(_expiryDate!),
      'usageLimit': usageLimit,
      'active': _active,
      'applicablePlans': _selectedPlans.toList(),
    });

    if (mounted && (_statusMessage == 'Saved.')) {
      _codeController.clear();
      _valueController.text = '10';
      _usageLimitController.clear();
      _descriptionController.clear();
      setState(() {
        _expiryDate = null;
        _active = true;
        _selectedPlans.clear();
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> promo) async {
    await _submit({
      'code': promo['code'],
      'active': !(promo['active'] == true),
    });
  }

  Future<void> _delete(String code) async {
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      return;
    }
    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/promos/${Uri.encodeComponent(code)}');
      final response = await http.delete(uri, headers: {'Authorization': 'Bearer $adminToken'});
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final promos = (decoded['promos'] as List?) ?? const [];
        setState(() {
          _promos = promos.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _statusIsError = false;
          _statusMessage = 'Deleted $code.';
        });
        widget.onSaved();
      }
    } catch (_) {}
  }

  String _discountLabel(Map<String, dynamic> promo) {
    final percent = (promo['discountPercent'] as num?)?.toDouble() ?? 0;
    final flat = (promo['discountFlat'] as num?)?.toDouble() ?? 0;
    if (percent > 0) return '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}% off';
    if (flat > 0) return '₹${flat.toStringAsFixed(flat.truncateToDouble() == flat ? 0 : 2)} off';
    return 'No discount set';
  }

  String _applicablePlansLabel(Map<String, dynamic> promo) {
    final plans = (promo['applicablePlans'] as List?)?.map((item) => item.toString()).toList() ?? const <String>[];
    if (plans.isEmpty) return 'All Plans';
    return plans.map((plan) => _planLabels[plan] ?? plan).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Promo codes'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backend-persisted discount codes, synced live to the checkout "Available Offers" list.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (_isLoading) const LinearProgressIndicator(),
              if (_statusMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusIsError ? const Color(0xFFFFF1F2) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusIsError ? const Color(0xFFDC2626) : const Color(0xFF0EA5E9)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusIsError ? const Color(0xFFDC2626) : const Color(0xFF0369A1),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Promo code (e.g. NEWYEAR10)', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (shown in Available Offers)', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _discountType,
                      decoration: const InputDecoration(labelText: 'Discount type', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('Percent (%)')),
                        DropdownMenuItem(value: 'flat', child: Text('Flat amount (₹)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _discountType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: _discountType == 'percent' ? 'Value (%)' : 'Value (₹)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickExpiryDate,
                      child: Text(_expiryDate == null ? 'No expiry (pick date)' : 'Expires ${_formatDate(_expiryDate!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _usageLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Usage limit (0 = unlimited)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 8),
              const Text('Applicable plans', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF16324D))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('All Plans'),
                    selected: _selectedPlans.isEmpty,
                    onSelected: (_) => setState(() => _selectedPlans.clear()),
                  ),
                  ..._planOptions.map((plan) {
                    final selected = _selectedPlans.contains(plan);
                    return FilterChip(
                      label: Text(_planLabels[plan] ?? plan),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedPlans.add(plan);
                          } else {
                            _selectedPlans.remove(plan);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Leave "All Plans" selected to allow this code everywhere, or pick specific plans to restrict it (e.g. exclude Lifetime).',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createOrUpdate,
                  child: Text(_isSaving ? 'Saving...' : 'Create / update promo code'),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Existing promo codes', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const _PromoUsageReportDialog(),
                      );
                    },
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('Usage & Sales Report', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_isLoading && _promos.isEmpty)
                const Text('No promo codes yet.')
              else
                ..._promos.map((promo) {
                  final active = promo['active'] == true;
                  final used = (promo['usedCount'] as num?)?.toInt() ?? 0;
                  final limit = (promo['usageLimit'] as num?)?.toInt() ?? 0;
                  final expiry = (promo['validUntil'] ?? '').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${promo['code']} • ${_discountLabel(promo)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                              Text(
                                'Used: $used${limit > 0 ? '/$limit' : ''}${expiry.isNotEmpty ? ' • Expires: $expiry' : ' • No expiry'}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Text(
                                'Plans: ${_applicablePlansLabel(promo)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(value: active, onChanged: (_) => _toggleActive(promo)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => _delete(promo['code'].toString()),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _PromoUsageReportDialog extends StatefulWidget {
  const _PromoUsageReportDialog();

  @override
  State<_PromoUsageReportDialog> createState() => _PromoUsageReportDialogState();
}

class _PromoUsageReportDialogState extends State<_PromoUsageReportDialog> {
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _errorMessage;
  Map<String, dynamic> _totals = const <String, dynamic>{};
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  final Set<String> _expandedCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Admin session is required to view the usage report.';
      });
      return;
    }
    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/promos/usage-report');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $adminToken',
        'Accept': 'application/json',
      });
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load usage report (${response.statusCode}).';
        });
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final report = (decoded['report'] as List?) ?? const [];
      setState(() {
        _rows = report.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _totals = Map<String, dynamic>.from((decoded['totals'] as Map?) ?? const {});
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load usage report. ${error.toString()}';
      });
    }
  }

  Future<void> _downloadCsv() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });
    final adminToken = AuthRouterService.authToken;
    if (adminToken.isEmpty) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Admin session is required to export the report.';
      });
      return;
    }
    try {
      final uri = Uri.https('jobready-india.onrender.com', '/api/admin/promos/usage-report', {'format': 'csv'});
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $adminToken',
        'Accept': 'text/csv,text/plain,*/*',
      });
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Export failed (${response.statusCode}).';
        });
        return;
      }
      final csvBytes = response.bodyBytes.isNotEmpty ? response.bodyBytes : utf8.encode(response.body);
      final blob = html.Blob([csvBytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'promo_usage_report_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      setState(() {
        _isDownloading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Export failed. ${error.toString()}';
      });
    }
  }

  String _money(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return '₹${number.toStringAsFixed(2)}';
  }

  String _plansLabel(Map<String, dynamic> row) {
    final plans = (row['applicablePlans'] as List?)?.map((item) => item.toString()).toList() ?? const <String>[];
    return plans.isEmpty ? 'All Plans' : plans.join(', ');
  }

  String _plansSoldLabel(Map<String, dynamic> row) {
    final plansSold = Map<String, dynamic>.from((row['plansSold'] as Map?) ?? const {});
    if (plansSold.isEmpty) return 'No sales yet';
    return plansSold.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Promo usage & sales report'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!_isLoading && _rows.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(label: 'Total redemptions', value: '${_totals['totalRedemptions'] ?? 0}'),
                  _SummaryChip(label: 'Gross revenue', value: _money(_totals['totalGrossRevenue'])),
                  _SummaryChip(label: 'Discount given', value: _money(_totals['totalDiscountGiven'])),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: _isLoading
                  ? const SizedBox.shrink()
                  : (_rows.isEmpty
                      ? const Center(child: Text('No promo code activity yet.'))
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final code = row['code']?.toString() ?? '';
                            final expanded = _expandedCodes.contains(code);
                            final dateBreakdown = (row['dateBreakdown'] as List?) ?? const [];
                            final statusSuffix = row['deleted'] == true
                                ? ' (deleted)'
                                : (row['active'] == true ? '' : ' (inactive)');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$code$statusSuffix',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ),
                                      Text('${row['redemptions'] ?? 0} redemptions', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Plans eligible: ${_plansLabel(row)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text('Plans sold: ${_plansSoldLabel(row)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    'Gross revenue: ${_money(row['grossRevenue'])} • Discount given: ${_money(row['discountGiven'])}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  if (dateBreakdown.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (expanded) {
                                            _expandedCodes.remove(code);
                                          } else {
                                            _expandedCodes.add(code);
                                          }
                                        });
                                      },
                                      child: Text(
                                        expanded ? 'Hide date breakdown' : 'Show date breakdown (${dateBreakdown.length} days)',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    if (expanded)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: dateBreakdown.map((entry) {
                                            final map = Map<String, dynamic>.from(entry as Map);
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                                              child: Text(
                                                '${map['date']}: ${map['redemptions']} used • ${_money(map['grossRevenue'])} gross • ${_money(map['discountGiven'])} discount',
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isDownloading ? null : _downloadCsv,
          icon: _isDownloading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 16),
          label: Text(_isDownloading ? 'Exporting...' : 'Download CSV'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
