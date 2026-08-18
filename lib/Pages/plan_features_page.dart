import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Services/api_config.dart';
import '../Services/app_tools_registry.dart';
import '../Services/plan_catalog_service.dart';

class PlanFeaturesPage extends StatefulWidget {
  const PlanFeaturesPage({super.key});

  @override
  State<PlanFeaturesPage> createState() => _PlanFeaturesPageState();
}

class _PlanFeaturesPageState extends State<PlanFeaturesPage> {
  @override
  Widget build(BuildContext context) {
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
      body: const Padding(
        padding: EdgeInsets.all(14),
        child: PlanComparisonMatrix(),
      ),
    );
  }
}

/// Full plan feature/quota comparison table. Used both as the standalone
/// "Plan Function List" page body and embedded directly elsewhere (via
/// [embeddedMaxHeight], which swaps the full-height Scaffold-driven layout
/// for a fixed-height self-contained scroll region).
class PlanComparisonMatrix extends StatefulWidget {
  final double? embeddedMaxHeight;

  const PlanComparisonMatrix({super.key, this.embeddedMaxHeight});

  @override
  State<PlanComparisonMatrix> createState() => _PlanComparisonMatrixState();
}

class _PlanComparisonMatrixState extends State<PlanComparisonMatrix> {
  late final PlanCatalogConfig _config;

  static const double _nameColumnWidth = 320;
  static const double _planColumnWidth = 120;

  // Registry names for the few rows below that stay live-configurable via
  // the admin panel's per-plan tool toggles (see _toolEnabledForPlan).
  static const String _govtResizerToolName = AppToolsRegistry.govtVerifier;
  static const String _resumeCanvasToolName = 'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)';
  static const String _posterStudioToolName = 'Poster Studio (Canvas-based poster, banner, flyer, and local print)';

  bool _toolEnabledForPlan(String toolName, String planKey) {
    return _config.enabledToolsByPlan[planKey]?.contains(toolName) ?? false;
  }

  // Header stays fixed while the body scrolls; the header's horizontal
  // position is mirrored from the body's controller (see _syncHeaderScroll)
  // so both stay perfectly aligned during horizontal scrolling.
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();
  bool _isSyncingHeaderScroll = false;

  @override
  void initState() {
    super.initState();
    _config = PlanCatalogService.load();
    _bodyHorizontalController.addListener(_syncHeaderScroll);
  }

  void _syncHeaderScroll() {
    if (_isSyncingHeaderScroll || !_headerHorizontalController.hasClients) {
      return;
    }
    _isSyncingHeaderScroll = true;
    _headerHorizontalController.jumpTo(_bodyHorizontalController.offset);
    _isSyncingHeaderScroll = false;
  }

  @override
  void dispose() {
    _bodyHorizontalController.removeListener(_syncHeaderScroll);
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadComparisonData() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/public/plan-catalog');
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

  // Server plan keys ('Free'/'7Days'/...) map to the display labels used by the
  // quota value maps below ('FREE'/'7 DAYS'/...). The admin-saved backend
  // config is authoritative once fetched successfully, so it overrides the
  // locally-cached config unconditionally (not just when empty) - this is
  // what makes an admin update on one device/browser show up immediately for
  // every visitor, instead of only ever showing the browser's own cached copy.
  static const Map<String, String> _planKeyToLabel = {
    'Free': 'FREE',
    '7Days': '7 DAYS',
    'Monthly': 'MONTHLY',
    'Yearly': 'YEARLY',
    'Lifetime': 'LIFETIME',
  };

  static void _applyServerQuotaMap(Object? serverMap, Map<String, String> target) {
    if (serverMap is! Map) {
      return;
    }
    _planKeyToLabel.forEach((planKey, label) {
      final value = serverMap[planKey];
      if (value != null && value.toString().trim().isNotEmpty) {
        target[label] = value.toString().trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
        final ocrQuotaValues = <String, String>{
          'FREE': _config.ocrQuotasByPlan['Free'] ?? '',
          '7 DAYS': _config.ocrQuotasByPlan['7Days'] ?? '',
          'MONTHLY': _config.ocrQuotasByPlan['Monthly'] ?? '',
          'YEARLY': _config.ocrQuotasByPlan['Yearly'] ?? '',
          'LIFETIME': _config.ocrQuotasByPlan['Lifetime'] ?? '',
        };
        if (snapshot.hasData && snapshot.data != null) {
          final catalog = snapshot.data!['catalog'];
          if (catalog is Map<String, dynamic>) {
            _applyServerQuotaMap(catalog['user_quotas_by_plan'], quotaValues);
            _applyServerQuotaMap(catalog['voice_quotas_by_plan'], voiceQuotaValues);
            _applyServerQuotaMap(catalog['ocr_quotas_by_plan'], ocrQuotaValues);
          }
        }

        // Single canonical, deduplicated feature list - each tool/limit
        // appears exactly once, grouped under one of 5 fixed categories.
        final combinedRows = <_PlanFeature>[
          _PlanFeature.categoryHeader('Quota & System Limits'),
          _PlanFeature(
            name: 'Daily Usage Quota',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: quotaValues['FREE']?.isNotEmpty == true ? quotaValues['FREE'] : '7',
            sevenDayValue: quotaValues['7 DAYS']?.isNotEmpty == true ? quotaValues['7 DAYS'] : '50',
            monthlyValue: quotaValues['MONTHLY']?.isNotEmpty == true ? quotaValues['MONTHLY'] : '1200',
            yearlyValue: quotaValues['YEARLY']?.isNotEmpty == true ? quotaValues['YEARLY'] : '2000',
            lifetimeValue: quotaValues['LIFETIME']?.isNotEmpty == true ? quotaValues['LIFETIME'] : '10000',
          ),
          _PlanFeature(
            name: 'Voice Commands Quota',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: voiceQuotaValues['FREE']?.isNotEmpty == true ? voiceQuotaValues['FREE'] : '0',
            sevenDayValue: voiceQuotaValues['7 DAYS']?.isNotEmpty == true ? voiceQuotaValues['7 DAYS'] : '50',
            monthlyValue: voiceQuotaValues['MONTHLY']?.isNotEmpty == true ? voiceQuotaValues['MONTHLY'] : '200',
            yearlyValue: voiceQuotaValues['YEARLY']?.isNotEmpty == true ? voiceQuotaValues['YEARLY'] : '1000',
            lifetimeValue: voiceQuotaValues['LIFETIME']?.isNotEmpty == true ? voiceQuotaValues['LIFETIME'] : '10000',
          ),
          _PlanFeature(
            name: 'AI OCR Quota (Pages)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: ocrQuotaValues['FREE']?.isNotEmpty == true ? ocrQuotaValues['FREE'] : '0',
            sevenDayValue: ocrQuotaValues['7 DAYS']?.isNotEmpty == true ? ocrQuotaValues['7 DAYS'] : '50',
            monthlyValue: ocrQuotaValues['MONTHLY']?.isNotEmpty == true ? ocrQuotaValues['MONTHLY'] : '200',
            yearlyValue: ocrQuotaValues['YEARLY']?.isNotEmpty == true ? ocrQuotaValues['YEARLY'] : '300',
            lifetimeValue: ocrQuotaValues['LIFETIME']?.isNotEmpty == true ? ocrQuotaValues['LIFETIME'] : '300',
          ),
          const _PlanFeature(
            name: 'Max Single File Size Limit',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            freeValue: '25 MB',
            sevenDayValue: '50 MB',
            monthlyValue: '50 MB',
            yearlyValue: '100 MB',
            lifetimeValue: '100 MB',
          ),
          const _PlanFeature(
            name: 'Priority Processing Queue',
            free: false,
            sevenDay: false,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          _PlanFeature.categoryHeader('Core Conversion & Office Tools'),
          const _PlanFeature(
            name: 'All-in-One File Converter (PDF, Word, Excel, CSV, PPT, Images)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Excel & CSV Multi-Sheet Converter (XLSX <-> CSV, CSV -> PDF/JSON)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'High-Fidelity PDF to Word (.docx)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          _PlanFeature.categoryHeader('Core PDF Workflow Tools'),
          const _PlanFeature(
            name: 'PDF Single File Target Compression (Set exact KB / MB)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Batch File Compression (Multiple files in one go)',
            free: false,
            sevenDay: false,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Merge & Split PDFs',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'PDF Content Extractor (Text, Images & Pages)',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'PDF Editor & Annotator',
            free: false,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Optical Character Recognition (OCR) Engine',
            free: false,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          _PlanFeature(
            name: 'AI OCR Engine (Scanned PDF to Word & Searchable PDF)*',
            free: false,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
            sevenDayValue: '${ocrQuotaValues['7 DAYS']?.isNotEmpty == true ? ocrQuotaValues['7 DAYS'] : '50'} Pages/month',
            monthlyValue: '${ocrQuotaValues['MONTHLY']?.isNotEmpty == true ? ocrQuotaValues['MONTHLY'] : '200'} Pages/month',
            yearlyValue: '${ocrQuotaValues['YEARLY']?.isNotEmpty == true ? ocrQuotaValues['YEARLY'] : '300'} Pages/month',
            lifetimeValue: '${ocrQuotaValues['LIFETIME']?.isNotEmpty == true ? ocrQuotaValues['LIFETIME'] : '300'} Pages/month',
          ),
          _PlanFeature.categoryHeader('AI & Resume Studio'),
          const _PlanFeature(
            name: 'AI Resume Builder',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          _PlanFeature(
            name: 'AI Voice Command Assistant',
            free: _toolEnabledForPlan('AI Voice Command', 'Free'),
            sevenDay: _toolEnabledForPlan('AI Voice Command', '7Days'),
            monthly: _toolEnabledForPlan('AI Voice Command', 'Monthly'),
            yearly: _toolEnabledForPlan('AI Voice Command', 'Yearly'),
            lifetime: _toolEnabledForPlan('AI Voice Command', 'Lifetime'),
          ),
          const _PlanFeature(
            name: 'HD Photo Studio & Background Remover',
            free: true,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          _PlanFeature(
            name: 'Smart Location / Navigation QR Generator',
            free: _toolEnabledForPlan(AppToolsRegistry.qrLocationGenerator, 'Free'),
            sevenDay: _toolEnabledForPlan(AppToolsRegistry.qrLocationGenerator, '7Days'),
            monthly: _toolEnabledForPlan(AppToolsRegistry.qrLocationGenerator, 'Monthly'),
            yearly: _toolEnabledForPlan(AppToolsRegistry.qrLocationGenerator, 'Yearly'),
            lifetime: _toolEnabledForPlan(AppToolsRegistry.qrLocationGenerator, 'Lifetime'),
          ),
          _PlanFeature(
            name: 'Govt-Rule Auto-Verifier & Redactor (Exact KB, 4x6 Sheet, B&W Clean)',
            free: _toolEnabledForPlan(_govtResizerToolName, 'Free'),
            sevenDay: _toolEnabledForPlan(_govtResizerToolName, '7Days'),
            monthly: _toolEnabledForPlan(_govtResizerToolName, 'Monthly'),
            yearly: _toolEnabledForPlan(_govtResizerToolName, 'Yearly'),
            lifetime: _toolEnabledForPlan(_govtResizerToolName, 'Lifetime'),
          ),
          _PlanFeature(
            name: 'Resume & Poster Canvas Studio',
            free: _toolEnabledForPlan(_resumeCanvasToolName, 'Free') || _toolEnabledForPlan(_posterStudioToolName, 'Free'),
            sevenDay: _toolEnabledForPlan(_resumeCanvasToolName, '7Days') || _toolEnabledForPlan(_posterStudioToolName, '7Days'),
            monthly: _toolEnabledForPlan(_resumeCanvasToolName, 'Monthly') || _toolEnabledForPlan(_posterStudioToolName, 'Monthly'),
            yearly: _toolEnabledForPlan(_resumeCanvasToolName, 'Yearly') || _toolEnabledForPlan(_posterStudioToolName, 'Yearly'),
            lifetime: _toolEnabledForPlan(_resumeCanvasToolName, 'Lifetime') || _toolEnabledForPlan(_posterStudioToolName, 'Lifetime'),
          ),
          _PlanFeature.categoryHeader('Support & Enterprise'),
          _PlanFeature(
            name: 'Conversion History & Download Vault',
            free: _toolEnabledForPlan('History', 'Free'),
            sevenDay: _toolEnabledForPlan('History', '7Days'),
            monthly: _toolEnabledForPlan('History', 'Monthly'),
            yearly: _toolEnabledForPlan('History', 'Yearly'),
            lifetime: _toolEnabledForPlan('History', 'Lifetime'),
          ),
          const _PlanFeature(
            name: 'Priority Support & Query Ticket System',
            free: false,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Multi-Currency Payment Display (INR + Top 20 Global Currencies)',
            free: false,
            sevenDay: true,
            monthly: true,
            yearly: true,
            lifetime: true,
          ),
          const _PlanFeature(
            name: 'Enterprise Security & Privacy Compliance',
            free: false,
            sevenDay: false,
            monthly: false,
            yearly: true,
            lifetime: true,
          ),
        ];

        final infoBox = Container(
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
        );

        final tableCard = Container(
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _headerHorizontalController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildHeaderRow(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _bodyHorizontalController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in combinedRows.asMap().entries)
                          _buildBodyRow(entry.value, entry.key),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final embeddedMaxHeight = widget.embeddedMaxHeight;

        final ocrNote = Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '*Note: OCR quota is a combined pool usable across both Scanned PDF to Word and PDF to Searchable PDF tools.',
            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoBox,
            const SizedBox(height: 12),
            embeddedMaxHeight != null
                ? SizedBox(height: embeddedMaxHeight, child: tableCard)
                : Expanded(child: tableCard),
            ocrNote,
          ],
        );
      },
    );
  }

  static Widget _buildHeaderRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: _nameColumnWidth,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Function Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
          ),
        ),
        SizedBox(width: _planColumnWidth, child: Center(child: _LegendChip(label: 'FREE', color: Color(0xFF6B7280)))),
        SizedBox(width: _planColumnWidth, child: Center(child: _LegendChip(label: '7 DAYS', color: Color(0xFFC97A3C)))),
        SizedBox(width: _planColumnWidth, child: Center(child: _LegendChip(label: 'MONTHLY', color: Color(0xFF0F766E)))),
        SizedBox(width: _planColumnWidth, child: Center(child: _LegendChip(label: 'YEARLY', color: Color(0xFF1D4ED8)))),
        SizedBox(width: _planColumnWidth, child: Center(child: _LegendChip(label: 'LIFETIME', color: Color(0xFF7C3AED)))),
      ],
    );
  }

  static Widget _buildBodyRow(_PlanFeature feature, int index) {
    if (feature.isCategoryHeader) {
      return Container(
        width: _nameColumnWidth + _planColumnWidth * 5,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF4FF),
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _nameColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            const SizedBox(width: _planColumnWidth * 5),
          ],
        ),
      );
    }

    return Container(
      width: _nameColumnWidth + _planColumnWidth * 5,
      decoration: BoxDecoration(
        color: index.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFAFCFF),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _nameColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                feature.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
            ),
          ),
          SizedBox(height: 52, width: _planColumnWidth, child: _buildAvailabilityCell(feature.free, feature.freeValue)),
          SizedBox(height: 52, width: _planColumnWidth, child: _buildAvailabilityCell(feature.sevenDay, feature.sevenDayValue)),
          SizedBox(height: 52, width: _planColumnWidth, child: _buildAvailabilityCell(feature.monthly, feature.monthlyValue)),
          SizedBox(height: 52, width: _planColumnWidth, child: _buildAvailabilityCell(feature.yearly, feature.yearlyValue)),
          SizedBox(height: 52, width: _planColumnWidth, child: _buildAvailabilityCell(feature.lifetime, feature.lifetimeValue)),
        ],
      ),
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
