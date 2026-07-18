import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/api_config.dart';
import '../Services/integration_hub_service.dart';

import 'compression_tool_page.dart' deferred as compression_page;
import 'convert_tool_page.dart' deferred as convert_page;
import 'extract_tool_page.dart' deferred as extract_page;
import 'merge_tool_page.dart' deferred as merge_page;
import 'pdf_tools_page.dart' deferred as pdf_page;
import 'split_tool_page.dart' deferred as split_page;

class SystemCheckPage extends StatefulWidget {
  const SystemCheckPage({super.key});

  @override
  State<SystemCheckPage> createState() => _SystemCheckPageState();
}

class _SystemCheckPageState extends State<SystemCheckPage> {
  static const String _qaStorageKey = 'jobready_v11_qa_checklist';
  static const String _qaSignOffStorageKey = 'jobready_v11_qa_signoff_at';

  final Map<String, bool> _qaChecks = {
    'chrome': false,
    'edge': false,
    'mobile': false,
    'desktop': false,
    'navigation': false,
    'theme': false,
  };

  int _enabledIntegrationApps = 0;
  String? _qaSignedOffAt;

  @override
  void initState() {
    super.initState();
    _loadQaChecks();
    _loadQaSignOff();
    _loadIntegrationStats();
  }

  void _loadQaSignOff() {
    final raw = html.window.localStorage[_qaSignOffStorageKey];
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    _qaSignedOffAt = raw;
  }

  void _loadQaChecks() {
    final raw = html.window.localStorage[_qaStorageKey];
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decodedRaw = jsonDecode(raw);
      if (decodedRaw is! Map) {
        return;
      }
      final decoded = Map<String, dynamic>.from(decodedRaw);
      for (final key in _qaChecks.keys) {
        _qaChecks[key] = decoded[key] == true;
      }
    } catch (_) {
      // Ignore malformed local data.
    }
  }

  void _saveQaChecks() {
    final jsonMap = _qaChecks.map((key, value) => MapEntry(key, value));
    html.window.localStorage[_qaStorageKey] = jsonEncode(jsonMap);
  }

  Future<void> _loadIntegrationStats() async {
    try {
      final apps = await IntegrationHubService.getEnabledApps();
      if (!mounted) {
        return;
      }
      setState(() {
        _enabledIntegrationApps = apps.length;
      });
    } catch (_) {
      // Keep fallback display on failure.
    }
  }

  void _setQaCheck(String key, bool value) {
    setState(() {
      _qaChecks[key] = value;
    });
    _saveQaChecks();
  }

  double _qaProgress() {
    final total = _qaChecks.length;
    final done = _qaChecks.values.where((value) => value).length;
    if (total == 0) {
      return 0;
    }
    return done / total;
  }

  bool _canSignOffQa() {
    return _qaChecks.values.every((value) => value);
  }

  String _formattedSignOff() {
    final raw = _qaSignedOffAt;
    if (raw == null || raw.trim().isEmpty) {
      return 'Not signed off yet';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  void _markQaSignOff() {
    if (!_canSignOffQa()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all QA checklist items before sign-off.')),
      );
      return;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    setState(() {
      _qaSignedOffAt = nowIso;
    });
    html.window.localStorage[_qaSignOffStorageKey] = nowIso;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QA smoke matrix signed off locally.')),
    );
  }

  Widget _qaSignOffCard() {
    final signOffReady = _canSignOffQa();
    final signedOff = _qaSignedOffAt != null && _qaSignedOffAt!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Release Smoke Sign-off',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _statusChip(
                label: signOffReady ? '✓ Matrix: READY' : '◯ Matrix: PENDING',
                color: signOffReady ? const Color(0xFF166534) : const Color(0xFFB45309),
              ),
              _statusChip(
                label: signedOff ? '✓ Sign-off: RECORDED' : '◯ Sign-off: NOT RECORDED',
                color: signedOff ? const Color(0xFF0E3A66) : const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last sign-off: ${_formattedSignOff()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _markQaSignOff,
              icon: const Icon(Icons.verified_user_rounded),
              label: const Text('Mark QA Matrix Sign-off'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E3A66),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTool(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openCompression(BuildContext context) async {
    await compression_page.loadLibrary();
    _openTool(context, compression_page.CompressionToolPage());
  }

  Future<void> _openConvert(BuildContext context) async {
    await convert_page.loadLibrary();
    _openTool(context, convert_page.ConvertToolPage());
  }

  Future<void> _openMerge(BuildContext context) async {
    await merge_page.loadLibrary();
    _openTool(context, merge_page.MergeToolPage());
  }

  Future<void> _openSplit(BuildContext context) async {
    await split_page.loadLibrary();
    _openTool(context, split_page.SplitToolPage());
  }

  Future<void> _openExtract(BuildContext context) async {
    await extract_page.loadLibrary();
    _openTool(context, extract_page.ExtractToolPage());
  }

  Future<void> _openPdf(BuildContext context) async {
    await pdf_page.loadLibrary();
    _openTool(context, pdf_page.PdfToolsPage());
  }

  Widget _readinessCard() {
    final activeGateway = ApiService.getActivePaymentGateway();
    final gateways = ApiService.getSupportedPaymentGateways();

    final gatewayLabel = activeGateway.isEmpty ? 'NOT FINALIZED' : activeGateway.toUpperCase();
    final gatewayColor = activeGateway.isEmpty ? const Color(0xFFB45309) : const Color(0xFF166534);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API and Payment Readiness',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _statusChip(
                label: 'Environment: ${ApiConfig.environment.name.toUpperCase()}',
                color: const Color(0xFF0E3A66),
              ),
              _statusChip(
                label: 'Gateway: $gatewayLabel',
                color: gatewayColor,
              ),
              _statusChip(
                label: 'Gateways: ${gateways.length}',
                color: gateways.isEmpty ? const Color(0xFFB45309) : const Color(0xFF166534),
              ),
              _statusChip(
                label: 'Integrations: $_enabledIntegrationApps',
                color: _enabledIntegrationApps > 0 ? const Color(0xFF166534) : const Color(0xFFB45309),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _qaChecklistCard() {
    final progress = _qaProgress();
    final done = _qaChecks.values.where((value) => value).length;
    final total = _qaChecks.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browser and Responsive QA ($done/$total)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE0E7FF),
            valueColor: AlwaysStoppedAnimation(
              progress == 1.0 ? const Color(0xFF166534) : const Color(0xFF0E3A66),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          _qaTile('chrome', 'Chrome flow validated'),
          _qaTile('edge', 'Edge flow validated'),
          _qaTile('mobile', 'Mobile layout validated'),
          _qaTile('desktop', 'Desktop layout validated'),
          _qaTile('navigation', 'Navigation smoke validated'),
          _qaTile('theme', 'Theme consistency validated'),
        ],
      ),
    );
  }

  Widget _qaTile(String key, String label) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        value: _qaChecks[key] == true,
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          _setQaCheck(key, value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A66),
        elevation: 0,
        title: const Text(
          'System Check',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Production header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8E5F5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Color(0xFF0E3A66),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'System Check',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Validate app configuration and diagnostics',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Guidance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD8E5F5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF0E3A66),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use these checks to validate app configuration, integrations, and diagnostics.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // API and Payment Readiness
                  _readinessCard(),
                  const SizedBox(height: 16),

                  // QA Checklist
                  _qaChecklistCard(),
                  const SizedBox(height: 16),

                  // Release Smoke Sign-off
                  _qaSignOffCard(),
                  const SizedBox(height: 24),

                  // Quick Checks section header
                  Text(
                    'Quick Reference Checklist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick checks card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8E5F5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Convert: PDF to JPG/PNG exports page-by-page ZIP.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '2. Convert: Multiple images to PDF produces one combined PDF.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '3. Convert: Word (.docx) to PDF uses structured page output.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '4. Compress / Merge / Split / Extract: Quota gate appears at daily limit.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '5. Extract: Tables / Forms option returns column-separated text.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '6. PDF Edit: Load Text, Run OCR, Tables buttons return text.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '7. File upload: Files above 500 MB are skipped with message.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tool Access section header
                  Text(
                    'Tool Validation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tool buttons
                  _toolButton(
                    context: context,
                    title: 'Compression Tool',
                    subtitle: 'Upload file and run compression flow.',
                    icon: Icons.compress_rounded,
                    onTap: () => _openCompression(context),
                  ),
                  const SizedBox(height: 10),

                  _toolButton(
                    context: context,
                    title: 'Convert Tool',
                    subtitle: 'Run format conversion path.',
                    icon: Icons.swap_horiz_rounded,
                    onTap: () => _openConvert(context),
                  ),
                  const SizedBox(height: 10),

                  _toolButton(
                    context: context,
                    title: 'Merge Tool',
                    subtitle: 'Add multiple files and merge.',
                    icon: Icons.merge_type_rounded,
                    onTap: () => _openMerge(context),
                  ),
                  const SizedBox(height: 10),

                  _toolButton(
                    context: context,
                    title: 'Split Tool',
                    subtitle: 'Check page split modes.',
                    icon: Icons.content_cut_rounded,
                    onTap: () => _openSplit(context),
                  ),
                  const SizedBox(height: 10),

                  _toolButton(
                    context: context,
                    title: 'Extract Tool',
                    subtitle: 'Check extraction workflow.',
                    icon: Icons.file_download_rounded,
                    onTap: () => _openExtract(context),
                  ),
                  const SizedBox(height: 10),

                  _toolButton(
                    context: context,
                    title: 'PDF Toolkit',
                    subtitle: 'Validate PDF-specific flows.',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: () => _openPdf(context),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8E5F5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF0E3A66),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFFD8E5F5),
            ),
          ],
        ),
      ),
    );
  }
}
