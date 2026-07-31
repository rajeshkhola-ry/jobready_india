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
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['plan'] != null && args['plan'].toString().trim().isNotEmpty && session != null) {
      await _purchasePlan(args['plan'].toString());
    }
  }

  Future<void> _purchasePlan(String planName) async {
    if (_session == null) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

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
      _isBusy = false;
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

  int _creditsForPlan(String planName) {
    switch (planName) {
      case '7Days':
        return 10;
      case 'Monthly':
        return 60;
      case 'Yearly':
        return 180;
      case 'Lifetime':
        return 500;
      default:
        return 3;
    }
  }

  double _priceForPlan(String planName) {
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
    final credits = _profile.remainingCredits > 0 ? _profile.remainingCredits : _creditsForPlan(activePlan);
    final convertedFiles = _profile.convertedFilesCount > 0 ? _profile.convertedFilesCount : _history.length;

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
            tooltip: 'Sign out',
            onPressed: () async {
              await UserAuthService.signOut();
              if (!mounted) {
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
                              childAspectRatio: 2.3,
                              children: [
                                _dashboardMetric('Active Plan', activePlan, Icons.workspace_premium_rounded, const Color(0xFF2563EB)),
                                _dashboardMetric('Remaining Credits', credits.toString(), Icons.stars_rounded, const Color(0xFF7C3AED)),
                                _dashboardMetric('Converted Files', convertedFiles.toString(), Icons.file_download_done_rounded, const Color(0xFF0F766E)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Available Plans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
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
                        childAspectRatio: 1.05,
                        children: [
                          _planCard('7Days', '7-day access', PlanCatalogService.formatPlanPriceLine('7Days', currencyCode: 'USD'), () => _purchasePlan('7Days')),
                          _planCard('Monthly', 'Monthly value', PlanCatalogService.formatPlanPriceLine('Monthly', currencyCode: 'USD'), () => _purchasePlan('Monthly')),
                          _planCard('Yearly', 'Yearly value', PlanCatalogService.formatPlanPriceLine('Yearly', currencyCode: 'USD'), () => _purchasePlan('Yearly')),
                        ],
                      );
                    },
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

  Widget _planCard(String planName, String subtitle, String price, VoidCallback onBuy) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(planName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : onBuy,
              child: Text(_isBusy ? 'Processing...' : 'Buy now'),
            ),
          ),
        ],
      ),
    );
  }
}
