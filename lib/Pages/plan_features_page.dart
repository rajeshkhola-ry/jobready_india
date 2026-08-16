import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Services/plan_catalog_service.dart';

class PlanFeaturesPage extends StatefulWidget {
  const PlanFeaturesPage({super.key});

  @override
  State<PlanFeaturesPage> createState() => _PlanFeaturesPageState();
}

class _PlanFeaturesPageState extends State<PlanFeaturesPage> {
  late final PlanCatalogConfig _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _config = PlanCatalogService.load();
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
