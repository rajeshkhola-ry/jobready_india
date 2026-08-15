import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/document_history_service.dart';
import '../Services/plan_catalog_service.dart';
import '../Services/user_account_service.dart';
import '../Services/user_auth_service.dart';
import '../Widgets/user_auth_dialog.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  UserAuthSession? _session;
  UserAccountProfile _profile = UserAccountProfile.initial();
  List<DocumentHistoryEntry> _history = const <DocumentHistoryEntry>[];
  List<Map<String, dynamic>> _purchaseTransactions = const <Map<String, dynamic>>[];
  bool _hasProcessedRouteArgs = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasProcessedRouteArgs) {
      return;
    }
    _hasProcessedRouteArgs = true;
    _handleInitialRouteArgs();
  }

  Future<void> _loadDashboard() async {
    final session = UserAuthService.getSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _profile = UserAccountService.getProfile();
      _history = DocumentHistoryService.getEntries();
    });
    final email = (_session?.email ?? _profile.email).trim();
    if (email.isNotEmpty) {
      await _syncProfileFromServer(email);
    }
    await _loadPurchaseHistory();
  }

  Future<void> _syncProfileFromServer(String email) async {
    try {
      final requestUrl = '/api/user/account?email=${Uri.encodeComponent(email)}';
      final response = await html.HttpRequest.request(
        requestUrl,
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      final raw = response.responseText ?? '{}';
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = (jsonDecode(raw) as Map?) ?? const <String, dynamic>{};
      final user = decoded['user'];
      if (user is! Map) {
        return;
      }

      final serverPlanName = (user['planName'] ?? user['plan_name'] ?? user['activePlan'] ?? user['active_plan'] ?? _profile.activePlan).toString();
      final normalizedPlanName = serverPlanName.trim().isNotEmpty ? serverPlanName : _profile.activePlan;
      final planPrice = _planPriceForLabel(normalizedPlanName);
      final quotaIsUnlimited = user['quotaIsUnlimited'] == true || user['quotaTotal']?.toString() == 'unlimited';
      final quotaRemaining = quotaIsUnlimited
          ? -1
          : int.tryParse(user['quotaRemaining']?.toString() ?? '') ?? _creditsForPlan(normalizedPlanName);
      final synchronizedProfile = _profile.copyWith(
        displayName: (user['name'] ?? _profile.displayName).toString(),
        email: (user['email'] ?? email).toString(),
        country: (user['billingCountry'] ?? user['country'] ?? _profile.country).toString(),
        activePlan: normalizedPlanName,
        planId: (user['planId'] ?? user['plan_id'] ?? _profile.planId).toString(),
        planName: normalizedPlanName,
        planStatus: (user['planStatus'] ?? user['plan_status'] ?? 'Active').toString(),
        remainingCredits: quotaRemaining,
        planCurrency: 'INR',
        planPrice: planPrice,
        planSummary: _planSummary(normalizedPlanName),
        gstin: (user['gstin'] ?? _profile.gstin).toString(),
        companyName: (user['company'] ?? _profile.companyName).toString(),
        billingState: (user['billingState'] ?? user['state'] ?? _profile.billingState).toString(),
        planExpiresAt: (user['accessExpiresAt'] ?? user['access_expires_at'] ?? _profile.planExpiresAt).toString(),
      );

      await UserAccountService.saveProfile(synchronizedProfile);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = synchronizedProfile;
      });
    } catch (_) {
      // Ignore server-sync failures; the dashboard keeps the last known local profile.
    }
  }

  double _planPriceForLabel(String planLabel) {
    switch (planLabel) {
      case '7 Days Access':
        return 99.0;
      case '1 Month Pro':
        return 499.0;
      case '1 Year Unlimited Access':
        return 999.0;
      case 'Lifetime Pro':
        return 2999.0;
      default:
        return _profile.planPrice > 0 ? _profile.planPrice : 0.0;
    }
  }

  Future<void> _loadPurchaseHistory() async {
    final email = (_session?.email ?? _profile.email).trim();
    if (email.isEmpty) {
      setState(() {
        _purchaseTransactions = const <Map<String, dynamic>>[];
      });
      return;
    }

    try {
      final requestUrl = '/api/user/transactions?email=${Uri.encodeComponent(email)}';
      final response = await html.HttpRequest.request(
        requestUrl,
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      final raw = response.responseText ?? '{}';
      if (raw.trim().isEmpty) {
        setState(() {
          _purchaseTransactions = const <Map<String, dynamic>>[];
        });
        return;
      }
      final decoded = (jsonDecode(raw) as Map?) ?? const <String, dynamic>{};
      final transactions = decoded['transactions'];
      final list = transactions is List ? transactions.cast<Map<dynamic, dynamic>>() : const <Map<dynamic, dynamic>>[];
      setState(() {
        _purchaseTransactions = list
            .map((entry) => Map<String, dynamic>.from(entry.map((key, value) => MapEntry(key.toString(), value))))
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _purchaseTransactions = const <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _handleInitialRouteArgs() async {
    final session = UserAuthService.getSession();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['plan'] != null && args['plan'].toString().trim().isNotEmpty && session != null) {
      await _purchasePlan(args['plan'].toString());
    }
  }

  Future<void> _purchasePlan(String planName) async {
    if (_session == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final profile = _profile.copyWith(
      activePlan: planName,
      planStatus: 'Active',
      remainingCredits: _creditsForPlan(planName),
      convertedFilesCount: _history.length,
      planCurrency: 'USD',
      planPrice: _priceForPlan(planName),
      planSummary: _planSummary(planName),
    );
    await UserAccountService.saveProfile(profile);

    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Your $planName plan is now active.')),
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final updated = await UserAuthService.updatePassword(
      currentController.text,
      newController.text,
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? 'Password updated successfully.' : 'Password update failed.')),
    );
  }

  void _downloadEntry(DocumentHistoryEntry entry) {
    final contents = 'File: ${entry.fileName}\nOutput: ${entry.outputFormat}\nCreated: ${entry.recordedAt.toIso8601String()}';
    final blob = html.Blob([contents], 'text/plain;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${entry.fileName}_${entry.outputFormat}.txt')
      ..click();
    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }

  void _downloadInvoice(String transactionId) {
    final url = '/api/user/invoice/$transactionId';
    html.window.open(url, '_blank');
  }

  int _creditsForPlan(String planName) {
    switch (planName) {
      case '7Days':
        return 10;
      case 'Monthly':
        return 60;
      case 'Yearly':
        return 180;
      case 'Lifetime':
        return -1; // sentinel: unlimited (see remainingCredits < 0 handling in build())
      default:
        return 3;
    }
  }

  double _priceForPlan(String planName) {
    final configured = PlanCatalogService.load().usdPrices[planName];
    if (configured != null) {
      return configured;
    }
    switch (planName) {
      case '7Days':
        return 0.99;
      case 'Monthly':
        return 1.99;
      case 'Yearly':
        return 14.99;
      case 'Lifetime':
        return 39.0;
      default:
        return 0.0;
    }
  }

  String _planSummary(String planName) {
    switch (planName) {
      case '7Days':
        return '7-day pass for frequent conversions';
      case 'Monthly':
        return 'Monthly access with higher quota';
      case 'Yearly':
        return 'Best value for regular use and higher quotas';
      case 'Lifetime':
        return 'Unlimited convenience for long-term use';
      default:
        return 'Free access to core tools';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePlan = _profile.activePlan.isNotEmpty ? _profile.activePlan : 'Free';
    final fallbackCredits = _profile.remainingCredits > 0 ? _profile.remainingCredits : _creditsForPlan(activePlan);
    final isUnlimitedQuota = _profile.remainingCredits < 0 || fallbackCredits < 0;
    final credits = isUnlimitedQuota ? 'Unlimited' : fallbackCredits.toString();
    final convertedFiles = _profile.convertedFilesCount > 0 ? _profile.convertedFilesCount : _history.length;
    final planExpiry = DateTime.tryParse(_profile.planExpiresAt);
    final expiryLabel = activePlan == 'Free'
        ? 'No expiry (Free plan)'
        : (planExpiry == null
            ? 'Not available'
            : '${planExpiry.toLocal().day.toString().padLeft(2, '0')}-${planExpiry.toLocal().month.toString().padLeft(2, '0')}-${planExpiry.toLocal().year}');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Text('User Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Go to home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await UserAuthService.signOut();
              if (!mounted || !context.mounted) {
                return;
              }
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _session == null
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFF2563EB)),
                    const SizedBox(height: 12),
                    const Text('Sign in to unlock your dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Your account, plan access, and download history stay available after login.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(context: context, builder: (_) => UserAuthDialog());
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Open login'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.account_circle_rounded, color: Color(0xFF2563EB), size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile.displayName.isNotEmpty ? _profile.displayName : _session!.displayName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _session!.email,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _changePassword,
                              icon: const Icon(Icons.password_rounded, size: 18),
                              label: const Text('Change Password'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            final crossAxisCount = availableWidth >= 920
                                ? 3
                                : availableWidth >= 640
                                    ? 2
                                    : 1;

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.2,
                              children: [
                                _dashboardMetric('Active Plan', activePlan, Icons.workspace_premium_rounded, const Color(0xFF2563EB)),
                                _dashboardMetric('Plan Expiry', expiryLabel, Icons.event_available_rounded, const Color(0xFFB45309)),
                                _dashboardMetric(
                                  'Current Balance',
                                  _profile.planPrice > 0
                                      ? '${_profile.planCurrency} ${_profile.planPrice.toStringAsFixed(2)}'
                                      : 'Free',
                                  Icons.account_balance_wallet_rounded,
                                  const Color(0xFF0F766E),
                                ),
                                _dashboardMetric('Remaining Quota', credits, Icons.stars_rounded, const Color(0xFF7C3AED)),
                                _dashboardMetric('Converted Files', convertedFiles.toString(), Icons.file_download_done_rounded, const Color(0xFF0F766E)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Conversion History & Downloads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _history.isEmpty
                        ? const Text('No converted files yet. Your history will show up here after the first successful conversion.', style: TextStyle(color: Color(0xFF64748B)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              dataTextStyle: const TextStyle(color: Color(0xFF334155)),
                              columns: const [
                                DataColumn(label: Text('File')),
                                DataColumn(label: Text('Format')),
                                DataColumn(label: Text('Recorded')),
                                DataColumn(label: Text('Download')),
                              ],
                              rows: _history
                                  .map(
                                    (entry) => DataRow(
                                      cells: [
                                        DataCell(Text(entry.fileName)),
                                        DataCell(Text(entry.outputFormat)),
                                        DataCell(Text(entry.recordedAt.toLocal().toString().split('.').first)),
                                        DataCell(
                                          TextButton.icon(
                                            onPressed: () => _downloadEntry(entry),
                                            icon: const Icon(Icons.download_rounded, size: 16),
                                            label: const Text('Download'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Purchase History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _purchaseTransactions.isEmpty
                        ? const Text('No purchases yet. Your invoices will appear here after payment.', style: TextStyle(color: Color(0xFF64748B)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              dataTextStyle: const TextStyle(color: Color(0xFF334155)),
                              columns: const [
                                DataColumn(label: Text('Invoice')),
                                DataColumn(label: Text('Plan')),
                                DataColumn(label: Text('Amount')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Download')),
                              ],
                              rows: _purchaseTransactions
                                  .map(
                                    (entry) => DataRow(
                                      cells: [
                                        DataCell(Text(entry['invoiceNumber']?.toString() ?? entry['transactionId']?.toString() ?? 'Invoice')),
                                        DataCell(Text(entry['planName']?.toString() ?? entry['planId']?.toString() ?? 'Plan')),
                                        DataCell(Text('${entry['totalAmount'] ?? entry['amount'] ?? 0} ${entry['currency'] ?? 'INR'}')),
                                        DataCell(Text((entry['paidAt'] ?? entry['createdAt'] ?? '').toString().split('T').first)),
                                        DataCell(
                                          TextButton.icon(
                                            onPressed: () => _downloadInvoice(entry['transactionId']?.toString() ?? ''),
                                            icon: const Icon(Icons.download_rounded, size: 16),
                                            label: const Text('Invoice'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dashboardMetric(String label, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
