import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop' as js_interop;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

import '../Services/plan_catalog_service.dart';
import '../Services/razorpay_service.dart';
import '../Services/user_account_service.dart';
import '../Services/voice_quota_service.dart';
import '../Services/voice_topup_service.dart';

class PlanFeaturesPage extends StatefulWidget {
  const PlanFeaturesPage({super.key});

  @override
  State<PlanFeaturesPage> createState() => _PlanFeaturesPageState();
}

class _PlanFeaturesPageState extends State<PlanFeaturesPage> {
  late final PlanCatalogConfig _config;
  bool _isLoading = true;
  late List<VoiceTopupPack> _topupPacks;
  String? _purchasingPackId;

  @override
  void initState() {
    super.initState();
    _config = PlanCatalogService.load();
    _topupPacks = VoiceTopupService.load();
    _isLoading = false;
  }

  Future<Map<String, dynamic>> _loadComparisonData() async {
    const defaultBaseUrl = 'https://getreadyjob.onrender.com';
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultBaseUrl);
    final uri = Uri.parse('$configuredBaseUrl/api/public/plan-matrix');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Unable to load plan comparison data.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid comparison payload.');
    }

    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    final features = <_PlanFeature>[
      const _PlanFeature(name: 'PDF Compress (Single File) - set exact KB or MB target', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Batch Compress (Multiple Files) - process many files in one session', free: false, sevenDay: false, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Convert PDF / Word / Image - core conversion workspace', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'PDF to Word - layout-first document export', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Merge PDFs - combine documents in one output file', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Split PDFs - divide pages by range or extract method', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Extract PDF Text & Images - pull readable content from documents', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'PDF to PDF Edit Tools - edit, save, and download updated PDF files', free: false, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'OCR (Optical Character Recognition) - read scanned PDF text where possible', free: false, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Issue / Suggestion / Query Ticket Number Support', free: true, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Multi-Currency Payment Display - top 20 currencies with INR rate card support', free: false, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Higher Daily Usage Limit', free: false, sevenDay: true, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Priority Processing Queue', free: false, sevenDay: false, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Advanced Quality Controls', free: false, sevenDay: false, monthly: true, yearly: true, lifetime: true),
      const _PlanFeature(name: 'AI-Assisted Document Workflows', free: false, sevenDay: false, monthly: false, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Enterprise Security & Compliance', free: false, sevenDay: false, monthly: false, yearly: true, lifetime: true),
      const _PlanFeature(name: 'Priority Support', free: false, sevenDay: true, monthly: true, yearly: true, lifetime: true),
    ];

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadComparisonData(),
      builder: (context, snapshot) {
        final quotaValues = <String, String>{
          'FREE': _config.userQuotasByPlan['Free'] ?? '',
          '7 DAYS': _config.userQuotasByPlan['7Days'] ?? '',
          'MONTHLY': _config.userQuotasByPlan['Monthly'] ?? '',
          'YEARLY': _config.userQuotasByPlan['Yearly'] ?? '',
          'LIFETIME': _config.userQuotasByPlan['Lifetime'] ?? '',
        };
        final voiceQuotaValues = <String, String>{
          'FREE': _config.voiceQuotasByPlan['Free'] ?? '',
          '7 DAYS': _config.voiceQuotasByPlan['7Days'] ?? '',
          'MONTHLY': _config.voiceQuotasByPlan['Monthly'] ?? '',
          'YEARLY': _config.voiceQuotasByPlan['Yearly'] ?? '',
          'LIFETIME': _config.voiceQuotasByPlan['Lifetime'] ?? '',
        };
        if (snapshot.hasData && snapshot.data != null) {
          final comparison = snapshot.data!['comparison'];
          if (comparison is Map<String, dynamic>) {
            final values = comparison['values'];
            if (values is List) {
              for (final entry in values) {
                if (entry is Map<String, dynamic>) {
                  final label = entry['label']?.toString() ?? '';
                  final value = entry['value']?.toString() ?? '';
                  final normalizedLabel = label.trim().toUpperCase();
                  if (normalizedLabel.isNotEmpty && (quotaValues[normalizedLabel] == null || quotaValues[normalizedLabel]!.isEmpty)) {
                    quotaValues[normalizedLabel] = value;
                  }
                }
              }
            }
          }
        }

        final tableRows = <_PlanFeature>[
          _PlanFeature(
            name: 'User Quota',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: quotaValues['FREE']?.isNotEmpty == true ? quotaValues['FREE'] : '2',
            sevenDayValue: quotaValues['7 DAYS']?.isNotEmpty == true ? quotaValues['7 DAYS'] : '50',
            monthlyValue: quotaValues['MONTHLY']?.isNotEmpty == true ? quotaValues['MONTHLY'] : '200',
            yearlyValue: quotaValues['YEARLY']?.isNotEmpty == true ? quotaValues['YEARLY'] : '1000',
            lifetimeValue: quotaValues['LIFETIME']?.isNotEmpty == true ? quotaValues['LIFETIME'] : 'Unlimited',
          ),
          _PlanFeature(
            name: 'Voice Commands Quota',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: voiceQuotaValues['FREE']?.isNotEmpty == true ? voiceQuotaValues['FREE'] : '5',
            sevenDayValue: voiceQuotaValues['7 DAYS']?.isNotEmpty == true ? voiceQuotaValues['7 DAYS'] : '50',
            monthlyValue: voiceQuotaValues['MONTHLY']?.isNotEmpty == true ? voiceQuotaValues['MONTHLY'] : '200',
            yearlyValue: voiceQuotaValues['YEARLY']?.isNotEmpty == true ? voiceQuotaValues['YEARLY'] : '1000',
            lifetimeValue: voiceQuotaValues['LIFETIME']?.isNotEmpty == true ? voiceQuotaValues['LIFETIME'] : 'Unlimited',
          ),
          const _PlanFeature(
            name: 'HD Photo Studio (1 time usage is free under Free plan)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'AI Resume Builder (1 time usage is free under Free plan)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          ...features,
        ];

        final toolNames = PlanCatalogConfig.registeredToolNames.toList()
          ..sort((a, b) => _toolCategory(a).compareTo(_toolCategory(b)));
        final matrixRows = <_PlanFeature>[];
        String? lastCategory;
        for (final toolName in toolNames) {
          final category = _toolCategory(toolName);
          if (category != lastCategory) {
            matrixRows.add(_PlanFeature.categoryHeader(category));
            lastCategory = category;
          }
          final free = _config.enabledToolsByPlan['Free']?.contains(toolName) ?? false;
          final sevenDay = _config.enabledToolsByPlan['7Days']?.contains(toolName) ?? false;
          final monthly = _config.enabledToolsByPlan['Monthly']?.contains(toolName) ?? false;
          final yearly = _config.enabledToolsByPlan['Yearly']?.contains(toolName) ?? false;
          final lifetime = _config.enabledToolsByPlan['Lifetime']?.contains(toolName) ?? false;
          matrixRows.add(_PlanFeature(
            name: toolName,
            free: free,
            sevenDay: sevenDay,
            monthly: monthly,
            yearly: yearly,
            lifetime: lifetime,
          ));
        }

        final combinedRows = <_PlanFeature>[
          ...tableRows,
          ...matrixRows.where((row) {
            final normalized = row.name.trim().toLowerCase();
            final isPriorityTool = normalized.contains('hd photo studio') || normalized.contains('ai resume builder');
            if (isPriorityTool) {
              return false;
            }
            return !tableRows.any((existing) => existing.name == row.name);
          }),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F2937),
            iconTheme: const IconThemeData(
              color: Colors.white,
              size: 30,
            ),
            title: const Text(
              'Plan Function List',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEEF6FF), Color(0xFFDCEBFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1.4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Plan Comparison Matrix',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tick means feature included in that plan. Cross means not included. OCR means Optical Character Recognition.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'User Quota values are loaded live from the admin quota rules.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _LegendChip(label: 'FREE', color: Color(0xFF6B7280)),
                    _LegendChip(label: '7 DAYS', color: Color(0xFFC97A3C)),
                    _LegendChip(label: 'MONTHLY', color: Color(0xFF0F766E)),
                    _LegendChip(label: 'YEARLY', color: Color(0xFF1D4ED8)),
                    _LegendChip(label: 'LIFETIME', color: Color(0xFF7C3AED)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
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
                        'Voice Command Top-Up Packs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'No Expiry \u2022 Instant AI Voice Credits \u2022 Works Across All Plans',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _topupPacks.map(_buildTopupCard).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFF)),
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 58,
                          headingTextStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                          columns: const [
                            DataColumn(label: Text('Function Name')),
                            DataColumn(label: Text('FREE')),
                            DataColumn(label: Text('7 DAYS')),
                            DataColumn(label: Text('MONTHLY')),
                            DataColumn(label: Text('YEARLY')),
                            DataColumn(label: Text('LIFETIME')),
                          ],
                          rows: combinedRows
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final feature = entry.value;

                            if (feature.isCategoryHeader) {
                              return DataRow(
                                color: WidgetStateProperty.all(const Color(0xFFEFF4FF)),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 320,
                                      child: Text(
                                        feature.name,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1D4ED8),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                ],
                              );
                            }

                            return DataRow(
                              color: WidgetStateProperty.all(
                                index.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFAFCFF),
                              ),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 320,
                                    child: Text(
                                      feature.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(_buildAvailabilityCell(feature.free, feature.freeValue)),
                                DataCell(_buildAvailabilityCell(feature.sevenDay, feature.sevenDayValue)),
                                DataCell(_buildAvailabilityCell(feature.monthly, feature.monthlyValue)),
                                DataCell(_buildAvailabilityCell(feature.yearly, feature.yearlyValue)),
                                DataCell(_buildAvailabilityCell(feature.lifetime, feature.lifetimeValue)),
                              ],
                            );
                          })
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopupCard(VoiceTopupPack pack) {
    final isBusy = _purchasingPackId == pack.id;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pack.isPopular ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pack.isPopular ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          width: pack.isPopular ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pack.isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(999)),
              child: const Text(
                'POPULAR',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          Text(
            pack.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            '${pack.credits} Voice Commands',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 8),
          Text(
            '\u20b9${pack.priceInr.toStringAsFixed(0)} / \$${pack.priceUsd.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : () => _purchaseTopup(pack),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Buy Now / Recharge', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseTopup(VoiceTopupPack pack) async {
    final profile = UserAccountService.getProfile();
    final email = profile.email.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your email in your account profile before purchasing a voice top-up.')),
      );
      return;
    }

    setState(() => _purchasingPackId = pack.id);

    const defaultBaseUrl = 'https://getreadyjob.onrender.com';
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultBaseUrl);

    try {
      final keyResponse = await http.get(Uri.parse('$configuredBaseUrl/api/config'));
      final keyDecoded = jsonDecode(keyResponse.body) as Map<String, dynamic>;
      final keyId = keyDecoded['key_id']?.toString().trim() ?? '';
      if (keyId.isEmpty) {
        throw Exception('Payment gateway is not configured. Please try again later.');
      }

      final billing = <String, dynamic>{
        'name': profile.displayName.trim().isNotEmpty ? profile.displayName.trim() : 'User',
        'email': email,
        'mobile': profile.mobileNumber.trim(),
        'country': profile.country.trim().isEmpty ? 'India' : profile.country.trim(),
      };

      final amountPaise = (pack.priceInr * 100).round();

      final orderResponse = await http.post(
        Uri.parse('$configuredBaseUrl/api/voice-topup/create-order'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'packId': pack.id,
          'packName': pack.name,
          'credits': pack.credits,
          'amount': amountPaise,
          'currency': 'INR',
          'billing': billing,
        }),
      );
      final orderDecoded = jsonDecode(orderResponse.body) as Map<String, dynamic>;
      if (orderDecoded['success'] != true) {
        throw Exception(orderDecoded['error']?.toString() ?? 'Unable to create top-up order.');
      }

      final orderId = orderDecoded['order_id']?.toString() ?? '';
      final orderAmountRaw = orderDecoded['amount'];
      final orderAmount = orderAmountRaw is int ? orderAmountRaw : int.tryParse(orderAmountRaw.toString()) ?? amountPaise;
      final orderCurrency = orderDecoded['currency']?.toString() ?? 'INR';

      final verifyResult = await _openTopupCheckoutAndVerify(
        keyId: keyId,
        orderId: orderId,
        amount: orderAmount,
        currency: orderCurrency,
        billing: billing,
        packName: pack.name,
      );

      final creditsAdded = int.tryParse(verifyResult['creditsAdded']?.toString() ?? '') ?? pack.credits;
      await VoiceQuotaService.addTopUp(
        credits: creditsAdded,
        packName: pack.name,
        amountPaid: pack.priceInr,
        currency: 'INR',
        invoiceUrl: verifyResult['invoiceUrl']?.toString(),
        transactionId: verifyResult['transactionId']?.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$creditsAdded voice command credits added! New balance: ${VoiceQuotaService.remainingLabel()}')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _purchasingPackId = null);
      }
    }
  }

  Future<Map<String, dynamic>> _openTopupCheckoutAndVerify({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    required Map<String, dynamic> billing,
    required String packName,
  }) async {
    final initialized = await RazorpayPaymentService.instance.initialize();
    if (!initialized) {
      throw Exception('Unable to load Razorpay checkout SDK.');
    }

    final completer = Completer<Map<String, String>>();
    final bridgeToken = 'rzp_topup_${DateTime.now().microsecondsSinceEpoch}';

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amount,
      'currency': currency,
      'name': 'GetReadyJob',
      'description': 'Voice Command Top-Up - $packName',
      'order_id': orderId,
      'prefill': {
        'name': billing['name']?.toString() ?? 'User',
        'email': billing['email']?.toString() ?? '',
        'contact': billing['mobile']?.toString() ?? '',
      },
      'theme': {'color': '#0F172A'},
    };

    final messageSubscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) {
        return;
      }
      final source = data['source']?.toString() ?? '';
      final token = data['token']?.toString() ?? '';
      if (source != 'jobready_razorpay_topup' || token != bridgeToken) {
        return;
      }

      final type = data['type']?.toString() ?? '';
      if (type == 'success') {
        final payloadRaw = data['payload'];
        if (payloadRaw is Map && !completer.isCompleted) {
          completer.complete({
            'order_id': payloadRaw['order_id']?.toString() ?? '',
            'payment_id': payloadRaw['payment_id']?.toString() ?? '',
            'signature': payloadRaw['signature']?.toString() ?? '',
          });
        }
      } else if (type == 'dismiss') {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Payment cancelled by user.'));
        }
      } else if (type == 'failed') {
        final payloadRaw = data['payload'];
        final message = payloadRaw is Map ? payloadRaw['message']?.toString().trim() : null;
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message?.isNotEmpty == true ? message : 'Razorpay checkout could not be opened.'),
          );
        }
      }
    });

    final optionsJson = jsonEncode(options);
    final script = '''
(function() {
  if (!window.Razorpay) {
    window.postMessage({ source: 'jobready_razorpay_topup', token: '$bridgeToken', type: 'dismiss' }, window.location.origin);
    return;
  }
  const opts = $optionsJson;
  opts.handler = function(response) {
    window.postMessage({
      source: 'jobready_razorpay_topup',
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
      window.postMessage({ source: 'jobready_razorpay_topup', token: '$bridgeToken', type: 'dismiss' }, window.location.origin);
    }
  };
  const checkout = new window.Razorpay(opts);
  if (checkout && typeof checkout.on === 'function') {
    checkout.on('payment.failed', function(response) {
      const message = response && response.error && response.error.description
        ? response.error.description
        : 'Razorpay payment failed before confirmation.';
      window.postMessage({
        source: 'jobready_razorpay_topup',
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
      source: 'jobready_razorpay_topup',
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
        source: 'jobready_razorpay_topup',
        token: '$bridgeToken',
        type: 'failed',
        payload: { message: 'Razorpay checkout did not open. Please allow popups/cookies and try again.' }
      }, window.location.origin);
    }
  }, 2200);
})();
''';

    js.context.callMethod('eval', [script]);

    late final Map<String, String> paymentResult;
    try {
      paymentResult = await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw TimeoutException('Payment confirmation timed out.'),
      );
    } finally {
      await messageSubscription.cancel();
    }

    const defaultBaseUrl = 'https://getreadyjob.onrender.com';
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultBaseUrl);
    final verifyResponse = await http.post(
      Uri.parse('$configuredBaseUrl/api/voice-topup/verify'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_id': paymentResult['order_id'],
        'payment_id': paymentResult['payment_id'],
        'signature': paymentResult['signature'],
      }),
    );
    final verifyDecoded = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
    if (verifyDecoded['success'] != true) {
      throw Exception(verifyDecoded['error']?.toString() ?? 'Payment verification failed.');
    }

    return verifyDecoded;
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

  static Widget _buildAvailabilityCell(bool enabled, String? displayValue) {
    if (displayValue != null) {
      return Center(
        child: Text(
          displayValue,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      );
    }

    return _buildAvailabilityIcon(enabled);
  }

  static Widget _buildAvailabilityIcon(bool enabled) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE9FBEF) : const Color(0xFFFEECEC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          enabled ? Icons.check_rounded : Icons.close_rounded,
          color: enabled ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          size: 16,
        ),
      ),
    );
  }

  static const Map<String, String> _toolCategories = <String, String>{
    'AI Voice Command': 'AI & Voice Tools',
    PlanCatalogConfig.resumeBuilderToolName: 'AI & Voice Tools',
    'Convert': 'Document Converters',
    'Govt Exam Photo & Signature Resizer (SSC, IBPS, Passport)': 'Govt Exam Tools',
    'CSV to Excel': 'Data Tools',
    'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)': 'Design & Media',
    'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)': 'Design & Media',
    'Poster Studio (Canvas-based poster, banner, flyer, and local print)': 'Design & Media',
    'HD Photo Studio': 'Design & Media',
  };

  static String _toolCategory(String toolName) => _toolCategories[toolName] ?? 'PDF Tools';
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PlanFeature {
  final String name;
  final bool free;
  final bool sevenDay;
  final bool monthly;
  final bool yearly;
  final bool lifetime;
  final String? freeValue;
  final String? sevenDayValue;
  final String? monthlyValue;
  final String? yearlyValue;
  final String? lifetimeValue;
  final bool isCategoryHeader;

  const _PlanFeature({
    required this.name,
    required this.free,
    required this.sevenDay,
    required this.monthly,
    required this.yearly,
    required this.lifetime,
    this.freeValue,
    this.sevenDayValue,
    this.monthlyValue,
    this.yearlyValue,
    this.lifetimeValue,
    this.isCategoryHeader = false,
  });

  factory _PlanFeature.categoryHeader(String category) => _PlanFeature(
        name: category,
        free: false,
        sevenDay: false,
        monthly: false,
        yearly: false,
        lifetime: false,
        isCategoryHeader: true,
      );
}
