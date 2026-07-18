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

  final Map<String, bool> _qaChecks = {
    'chrome': false,
    'edge': false,
    'mobile': false,
    'desktop': false,
    'navigation': false,
    'theme': false,
  };

  int _enabledIntegrationApps = 0;

  @override
  void initState() {
    super.initState();
    _loadQaChecks();
    _loadIntegrationStats();
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API and Payment Readiness',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _statusChip(
                label: 'Environment: ${ApiConfig.environment.name.toUpperCase()}',
                color: const Color(0xFF1D4ED8),
              ),
              _statusChip(
                label: 'Gateway: $gatewayLabel',
                color: gatewayColor,
              ),
              _statusChip(
                label: 'Supported gateways: ${gateways.length}',
                color: gateways.isEmpty ? const Color(0xFFB45309) : const Color(0xFF166534),
              ),
              _statusChip(
                label: 'Enabled integrations: $_enabledIntegrationApps',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browser and Responsive QA Checklist ($done/$total)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            color: progress == 1.0 ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
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
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        title: const Text(
          'System Check',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Text(
              'Use these checks one by one to validate the active V1 merged build paths.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          _readinessCard(),
          const SizedBox(height: 10),
          _qaChecklistCard(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick V1 Checks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1. Convert: PDF to JPG/PNG exports page-by-page ZIP.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '2. Convert: multiple images to PDF produces one combined PDF.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '3. Convert: Word (.docx) to PDF uses structured page output.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '4. Compress / Merge / Split / Extract: quota gate dialog appears when daily limit is reached.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '5. Extract: Tables / Forms option returns column-separated text output.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '6. PDF Edit: Load Text, Run OCR, and Tables buttons all return text.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '7. Home V1: Daily Usage, Recent Documents, Account/Privacy sections visible.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '8. File upload: files above 500 MB are skipped with a clear message.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _toolButton(
            context: context,
            title: '1) Compression Tool',
            subtitle: 'Upload file and run compression flow.',
            icon: Icons.compress,
            color: Colors.teal,
            onTap: () => _openCompression(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '2) Convert Tool',
            subtitle: 'Run format conversion path.',
            icon: Icons.swap_horiz,
            color: const Color(0xFF0051BA),
            onTap: () => _openConvert(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '3) Merge Tool',
            subtitle: 'Add multiple files and merge.',
            icon: Icons.merge_type,
            color: Colors.green,
            onTap: () => _openMerge(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '4) Split Tool',
            subtitle: 'Check page split modes.',
            icon: Icons.content_cut,
            color: Colors.purple,
            onTap: () => _openSplit(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '5) Extract Tool',
            subtitle: 'Check extraction workflow.',
            icon: Icons.description,
            color: Colors.orange,
            onTap: () => _openExtract(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '6) PDF Toolkit',
            subtitle: 'Validate PDF-specific flows.',
            icon: Icons.picture_as_pdf,
            color: Colors.red,
            onTap: () => _openPdf(context),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return ElevatedButton(
      onPressed: () {
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    );
  }
}
