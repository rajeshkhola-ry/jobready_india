import 'dart:convert';

import 'package:flutter/material.dart';

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
  late Map<String, List<String>> _enabledToolsByPlan;

  @override
  void initState() {
    super.initState();
    _selectedPlan = 'Monthly';
    _hydrateFromConfig(widget.initialConfig);
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
    _enabledToolsByPlan = {
      for (final plan in _plans) plan: List<String>.from(config.enabledToolsByPlan[plan] ?? const <String>[])
    };
  }

  void _save() {
    final defaults = PlanCatalogConfig.defaults();
    final quotas = <String, String>{};
    for (final plan in _plans) {
      final raw = _quotaControllers[plan]!.text.trim();
      quotas[plan] = raw.isEmpty ? (defaults.userQuotasByPlan[plan] ?? '2') : raw;
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
    );
    PlanCatalogService.save(config);
    widget.onSave(config);
    Navigator.of(context).pop();
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
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
  final TextEditingController _codeController = TextEditingController(text: 'NEWYEAR10');
  final TextEditingController _discountController = TextEditingController(text: '20');
  String _validity = '30';

  @override
  void dispose() {
    _codeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _save() {
    final discount = int.tryParse(_discountController.text.trim()) ?? 20;
    if (discount < 1 || discount > 100) {
      return;
    }
    CouponService.upsertCoupon(
      code: _codeController.text.trim(),
      discountPercent: discount,
      validFor: Duration(days: int.tryParse(_validity) ?? 30),
    );
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final coupons = CouponService.getAllCoupons().take(6).toList();
    return AlertDialog(
      title: const Text('Promo codes'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Coupon code'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount %'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _validity,
              decoration: const InputDecoration(labelText: 'Validity (days)'),
              items: const [
                DropdownMenuItem(value: '7', child: Text('7 days')),
                DropdownMenuItem(value: '30', child: Text('30 days')),
                DropdownMenuItem(value: '90', child: Text('90 days')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _validity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const Text('Recent coupons', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (coupons.isEmpty)
              const Text('No coupons yet.')
            else
              ...coupons.map((coupon) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${coupon.code} • ${coupon.discountPercent}%'),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save coupon')),
      ],
    );
  }
}
