import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../Widgets/download_result_dialog.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/quota_gate.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Widgets/tool_workspace_shell.dart';
import '../Services/csv_to_excel_service.dart';
import '../Services/device_fingerprint_service.dart';
import '../Services/document_history_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/upload_context_service.dart';
import '../Services/usage_quota_service.dart';
import '../Services/voice_command_service.dart';
import '../Services/wasm_document_service.dart';

/// CSV to Excel Tool Page - parses an uploaded .csv file and downloads a
/// real Microsoft Excel (.xlsx) workbook built from its rows.
class CsvToExcelPage extends StatefulWidget {
  const CsvToExcelPage({super.key});

  @override
  State<CsvToExcelPage> createState() => _CsvToExcelPageState();
}

class _CsvToExcelPageState extends State<CsvToExcelPage> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  int _selectedFileSize = 0;
  int _rowCount = 0;
  int _columnCount = 0;
  bool _isConverting = false;
  String _statusMessage = 'Ready to convert';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
    _applyVoiceCommand();
  }

  void _applyVoiceCommand() {
    final params = VoiceCommandService.consumePendingParameters();
    if (params.isEmpty) {
      return;
    }
    final autoExecute = params[VoiceCommandService.autoExecuteFlagKey] == true;
    if (autoExecute && _selectedFileBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startConvert(autoExecute: true));
    }
  }

  void _hydrateFromHomeUpload() {
    final files = UploadContextService.getCompatibleFiles(['csv']);
    if (files.isEmpty) {
      return;
    }

    final cached = files.first;
    _applySelectedFile(cached.name, cached.bytes);
    _statusMessage = '✓ ${cached.name} loaded from workspace ($_rowCount rows × $_columnCount columns)';
  }

  void _applySelectedFile(String name, Uint8List bytes) {
    final rows = CsvToExcelService.parseCsv(utf8.decode(bytes, allowMalformed: true));
    _selectedFileName = name;
    _selectedFileBytes = bytes;
    _selectedFileSize = bytes.length;
    _rowCount = rows.length;
    _columnCount = rows.isEmpty ? 0 : rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _selectFile() async {
    try {
      final file = await FilePickerService.pickFileData(allowedExtensions: ['csv']);
      if (!mounted) return;
      if (file == null) {
        final report = FilePickerService.lastSelectionReport;
        setState(() {
          _statusMessage = report.cancelled
              ? 'File selection cancelled'
              : 'No usable file selected. ${report.buildSummaryMessage()}';
        });
        return;
      }

      setState(() {
        _applySelectedFile(file.name, file.bytes);
        _statusMessage = '✓ ${file.name} selected ($_rowCount rows × $_columnCount columns)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '✗ Unable to open file picker. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open file picker. Please check permissions and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
      _selectedFileSize = 0;
      _rowCount = 0;
      _columnCount = 0;
      _statusMessage = 'Ready to convert';
    });
  }

  String _outputFileName(String inputName) {
    final dotIndex = inputName.lastIndexOf('.');
    final base = dotIndex > 0 ? inputName.substring(0, dotIndex) : inputName;
    return '$base.xlsx';
  }

  Future<void> _startConvert({bool autoExecute = false}) async {
    final bytes = _selectedFileBytes;
    final name = _selectedFileName;
    if (bytes == null || name == null) {
      setState(() {
        _statusMessage = '✗ Select a CSV file first';
      });
      return;
    }

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'convert',
    );
    if (!allowed) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Converting $name to Excel...';
    });

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final rows = CsvToExcelService.parseCsv(utf8.decode(bytes, allowMalformed: true));
      if (rows.isEmpty) {
        throw Exception('No readable rows found in this CSV file.');
      }

      final xlsxBytes = CsvToExcelService.buildXlsxBytes(rows);
      final outputName = _outputFileName(name);

      if (!mounted) return;

      setState(() {
        _isConverting = false;
        _statusMessage = '✓ Converted $_rowCount row(s) × $_columnCount column(s) — ready for download';
      });

      if (autoExecute) {
        WasmDocumentService.triggerBrowserDownload(
          bytes: xlsxBytes,
          fileName: outputName,
          mimeType: 'application/octet-stream',
        );
        DocumentHistoryService.addEntry(
          fileName: outputName,
          outputFormat: 'Excel (.xlsx)',
          fileSizeBytes: xlsxBytes.length,
        );
        UsageQuotaService.recordAction('Excel (.xlsx)');
        DeviceFingerprintService.recordFileConsumed();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice command complete. File converted and downloaded automatically.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Excel (.xlsx)',
          fileName: outputName,
          outputBytes: xlsxBytes,
          originalFileSizeBytes: _selectedFileSize,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = '✗ Conversion failed. Please use a valid CSV file and try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversion failed. Please use a valid CSV file and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV to Excel'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushNamedAndRemoveUntil('/home', (route) => false);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToolWorkspaceShell(
                      title: 'CSV to Excel',
                      subtitle: 'Convert CSV data sheets into clean Microsoft Excel (.xlsx) files.',
                      icon: Icons.table_chart_rounded,
                      accentColor: const Color(0xFF0E3A66),
                      statusText: _statusMessage,
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                    // Step 1: Select File
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _stepHeader(1, 'Choose CSV File'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isConverting ? null : _selectFile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0E3A66),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Choose CSV File'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFileName == null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFB8D0ED)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.table_chart_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No file selected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Select a .csv file to convert to Excel',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          else
                            _buildFileCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Step 2: Convert
                    if (_selectedFileName != null) ...[
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stepHeader(2, 'Create Excel File'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isConverting ? null : _startConvert,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E3A66),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: Icon(_isConverting ? Icons.hourglass_top_rounded : Icons.table_chart_rounded),
                                label: Text(_isConverting ? 'Converting...' : 'Convert to Excel (.xlsx)'),
                              ),
                            ),
                            if (_isConverting) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(
                                backgroundColor: Color(0xFFD8E5F5),
                                color: Color(0xFF0E3A66),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const ToolGuidancePanel(
                              title: 'About CSV to Excel',
                              summary: 'Convert plain CSV data sheets into a clean, real Microsoft Excel (.xlsx) workbook.',
                              supportedFormats: ['CSV'],
                              howToUse: [
                                'Choose a .csv file.',
                                'Review the detected row and column count.',
                                'Convert and download the .xlsx workbook.',
                              ],
                              faqs: [
                                'Are quoted fields with commas or line breaks supported? Yes.',
                                'Will leading zeros in IDs or zip codes be preserved? Yes, they stay as text.',
                              ],
                              tips: [
                                'Use UTF-8 encoded CSV files for best results.',
                                'Keep a header row for clearer spreadsheets.',
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _StatusRow(message: _statusMessage, type: _getStatusType()),
                    const SizedBox(height: 16),
                    const ProductionFooter(compact: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF0E3A66),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }

  Widget _buildFileCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              color: Color(0xFF15803D),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(_selectedFileSize)} • $_rowCount rows × $_columnCount columns',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isConverting ? null : _clearFile,
            icon: const Icon(Icons.close_rounded),
            iconSize: 18,
            color: const Color(0xFF94A3B8),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  _StatusType _getStatusType() {
    if (_statusMessage.startsWith('✓')) return _StatusType.success;
    if (_statusMessage.startsWith('✗')) return _StatusType.error;
    if (_statusMessage.startsWith('Converting')) return _StatusType.processing;
    return _StatusType.idle;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

enum _StatusType { idle, processing, success, error }

class _StatusRow extends StatelessWidget {
  final String message;
  final _StatusType type;

  const _StatusRow({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, Color bg) = switch (type) {
      _StatusType.processing => (
          Icons.sync_rounded,
          const Color(0xFF0E3A66),
          const Color(0xFFEAF2FF),
        ),
      _StatusType.success => (
          Icons.check_circle_outline_rounded,
          const Color(0xFF166534),
          const Color(0xFFDCFCE7),
        ),
      _StatusType.error => (
          Icons.error_outline_rounded,
          const Color(0xFF9F1239),
          const Color(0xFFFFE4E6),
        ),
      _StatusType.idle => (
          Icons.info_outline_rounded,
          const Color(0xFF475569),
          const Color(0xFFF8FBFF),
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
