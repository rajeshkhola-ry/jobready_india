import 'package:flutter/material.dart';

class PlanFeaturesPage extends StatelessWidget {
  const PlanFeaturesPage({super.key});

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
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
                      rows: features
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final feature = entry.value;

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
                            DataCell(_buildAvailabilityIcon(feature.free)),
                            DataCell(_buildAvailabilityIcon(feature.sevenDay)),
                            DataCell(_buildAvailabilityIcon(feature.monthly)),
                            DataCell(_buildAvailabilityIcon(feature.yearly)),
                            DataCell(_buildAvailabilityIcon(feature.lifetime)),
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

  const _PlanFeature({
    required this.name,
    required this.free,
    required this.sevenDay,
    required this.monthly,
    required this.yearly,
    required this.lifetime,
  });
}
