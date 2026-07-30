import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../Widgets/target_size_selector.dart';
import '../Widgets/download_result_dialog.dart';
import '../Widgets/apple_button.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/quota_gate.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Widgets/tool_workspace_shell.dart';
import '../Services/compression_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/remote_compression_service.dart';
import '../Services/upload_context_service.dart';
import 'dart:typed_data';

class _CompressionOutcome {
  final Uint8List bytes;
  final bool aggressiveUsed;
  final double reductionPercent;
  final bool targetMet;
  final String note;

  const _CompressionOutcome({
    required this.bytes,
    required this.aggressiveUsed,
    required this.reductionPercent,
    required this.targetMet,
    required this.note,
  });
}

/// Compression Tool Page - Main UI for file compression
/// User uploads file → Sets target size → Compresses → Downloads result
class CompressionToolPage extends StatefulWidget {
  const CompressionToolPage({super.key});

  @override
  State<CompressionToolPage> createState() => _CompressionToolPageState();
}

class _CompressionToolPageState extends State<CompressionToolPage> {
  final _compressionService = const CompressionService();
  final _remoteCompressionService = const RemoteCompressionService();

  int? _targetSizeBytes;
  String? _selectedUnit;
  PdfCompressionMode _selectedCompressionMode = PdfCompressionMode.recommended;
  CompressionPipelineMode _pipelineMode = CompressionPipelineMode.standard;
  bool _isCompressing = false;
  String _statusMessage = 'Ready to compress';

  List<PickedFileData> _selectedFiles = [];
  Uint8List? _selectedFile;
  String? _selectedFileName;

  // Compression result
  int? _originalFileSize;
  int? _compressedFileSize;
  double? _compressionRatio;
  Uint8List? _lastOutputBytes;
  String? _lastOutputName;
  List<String> _filesAboveTarget = [];
  List<String> _qualityImpactNotes = [];

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _applyDefaultTargetSize(int sourceBytes) {
    final ratio = _pipelineMode == CompressionPipelineMode.highCompressionImageOnly
        ? 0.18
        : switch (_selectedCompressionMode) {
      PdfCompressionMode.smallSize => 0.35,
      PdfCompressionMode.recommended => 0.55,
      PdfCompressionMode.highQuality => 0.72,
      PdfCompressionMode.targetSize => 0.7,
    };
    final defaultTarget = (sourceBytes * ratio).round();
    _targetSizeBytes = defaultTarget > 0 ? defaultTarget : sourceBytes;
    _selectedUnit = (_targetSizeBytes ?? 0) < (1024 * 1024) ? 'KB' : 'MB';
  }

  void _hydrateFromHomeUpload() {
    final files = UploadContextService.getCompatibleFiles([
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'bmp',
    ]);

    if (files.isEmpty) {
      return;
    }

    final first = files.first;
    setState(() {
      _selectedFiles = files;
      _selectedFile = first.bytes;
      _selectedFileName = first.name;
      _originalFileSize = first.size;
      _compressedFileSize = null;
        _filesAboveTarget = [];
        _qualityImpactNotes = [];
      _applyDefaultTargetSize(first.size);
      _statusMessage = files.length == 1
          ? '✓ ${first.name} loaded from Home upload. Ready to compress.'
          : '✓ ${files.length} file(s) loaded from Home upload. Ready to compress.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
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
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 30,
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Colors.white),
          ),
        ],
        title: const Text(
          'Compress File',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            ToolWorkspaceShell(
              title: 'Compress File',
              subtitle: 'Reduce file size while keeping your document quality and structure intact.',
              icon: Icons.compress_rounded,
              accentColor: const Color(0xFF0E3A66),
              statusText: _statusMessage,
              child: const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            // Step 1: Upload File
            _buildStepCard(
              step: 1,
              title: 'Choose File',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedFile == null)
                    AppleButton(
                      label: 'Choose File(s)',
                      icon: Icons.upload_file,
                      onPressed: _selectFile,
                      isPrimary: true,
                      isFullWidth: true,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFiles.length > 1
                                          ? '${_selectedFiles.length} file(s) selected'
                                          : (_selectedFileName ?? 'File selected'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedFiles.length > 1
                                          ? 'Total size: ${_formatBytes(_selectedFiles.fold<int>(0, (sum, file) => sum + file.size))}'
                                          : 'Size: ${_formatBytes(_selectedFile!.length)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppleButton(
                                label: 'Change',
                                onPressed: _selectFile,
                                isPrimary: false,
                                height: 36,
                              ),
                            ],
                          ),
                          if (_selectedFiles.length > 1) ...[
                            const SizedBox(height: 10),
                            ..._selectedFiles.take(4).map(
                              (file) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${file.name} • ${_formatBytes(file.size)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ),
                            if (_selectedFiles.length > 4)
                              Text(
                                '+${_selectedFiles.length - 4} more file(s)',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: Set Target Size
            if (_selectedFile != null)
              _buildStepCard(
                step: 2,
                title: 'Set Target Size',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compression Engine',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<CompressionPipelineMode>(
                      segments: const [
                        ButtonSegment<CompressionPipelineMode>(
                          value: CompressionPipelineMode.standard,
                          label: Text('Standard'),
                          icon: Icon(Icons.tune_rounded),
                        ),
                        ButtonSegment<CompressionPipelineMode>(
                          value: CompressionPipelineMode.highCompressionImageOnly,
                          label: Text('High Compression (Image-Only)'),
                          icon: Icon(Icons.image_search_rounded),
                        ),
                      ],
                      selected: {_pipelineMode},
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        setState(() {
                          _pipelineMode = next;
                          final sourceBytes = _selectedFiles.isNotEmpty
                              ? _selectedFiles.first.size
                              : (_selectedFile?.length ?? 0);
                          if (sourceBytes > 0) {
                            _applyDefaultTargetSize(sourceBytes);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        _pipelineMode == CompressionPipelineMode.standard
                            ? 'Standard mode keeps text clarity and applies resource optimization first.'
                            : 'High mode uses PDF → Image → PDF at around 150 DPI and quality around 55 for aggressive size reduction on image-heavy files.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C2D12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TargetSizeSelector(
                      onTargetSet: (targetBytes, unit) {
                        setState(() {
                          _targetSizeBytes = targetBytes;
                          _selectedUnit = unit;
                        });
                      },
                      onModeChanged: (mode) {
                        setState(() {
                          _selectedCompressionMode = mode;
                        });
                      },
                      sourceBytes: _selectedFiles.isNotEmpty
                          ? _selectedFiles.first.size
                          : (_selectedFile?.length ?? 0),
                      initialValue: _targetSizeBytes != null
                          ? (_selectedUnit == 'KB'
                              ? _targetSizeBytes! ~/ 1024
                              : _targetSizeBytes! ~/ (1024 * 1024))
                          : null,
                      initialUnit: _selectedUnit ?? 'MB',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Step 3: Compress
            if (_selectedFile != null && _targetSizeBytes != null)
              _buildStepCard(
                step: 3,
                title: 'Compress File',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompactTargetSizeDisplay(
                      targetBytes: _targetSizeBytes!,
                      unit: _selectedUnit ?? 'MB',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart compression picks adaptive strategies. If exact target is unsafe for readability, the tool returns the best optimized output with a warning.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppleButton(
                        label: _isCompressing
                          ? 'Compressing...'
                          : 'Start Compression',
                      icon: _isCompressing ? Icons.hourglass_empty : Icons.compress,
                      onPressed: _isCompressing ? null : _startCompression,
                      isPrimary: true,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getStatusColor(),
                ),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(),
                ),
              ),
            ),
            if (_isCompressing) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.35)),
                ),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Compression in progress... please wait.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Results
            if (_compressedFileSize != null)
              _buildResultsCard(),
            const SizedBox(height: 20),
            const ToolGuidancePanel(
              title: 'About Compress File',
              summary: 'Use this tool to reduce file size while balancing usability and output quality.',
              supportedFormats: ['PDF', 'JPG', 'JPEG', 'PNG', 'WEBP', 'BMP'],
              howToUse: ['Choose a supported file.', 'Set your target size.', 'Start compression and review the result.'],
              faqs: ['Can every file hit the exact target size? Not always.', 'Will quality change? It depends on the source and target.'],
              tips: ['Choose realistic targets.', 'Keep the original file.', 'Review output quality before sharing.'],
            ),
            const SizedBox(height: 16),
            const ProductionFooter(compact: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0051BA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final originalMB = _originalFileSize! / (1024 * 1024);
    final compressedMB = _compressedFileSize! / (1024 * 1024);
    final reduction =
        ((_originalFileSize! - _compressedFileSize!) / _originalFileSize!) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Compression Complete!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Original Size',
            '${originalMB.toStringAsFixed(2)} MB',
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Compressed Size',
            '${compressedMB.toStringAsFixed(2)} MB',
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            _selectedFiles.length > 1 ? 'Target (per file)' : 'Target Size',
            _targetSizeBytes == null ? '-' : _formatBytes(_targetSizeBytes!),
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Size Reduction',
            '${reduction.toStringAsFixed(1)}%',
            isHighlight: true,
          ),
          if (_filesAboveTarget.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.35)),
              ),
              child: Text(
                'Above target: ${_filesAboveTarget.take(3).join(', ')}${_filesAboveTarget.length > 3 ? ' +${_filesAboveTarget.length - 3} more' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
          if (_qualityImpactNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.35)),
              ),
              child: Text(
                'Quality impact: ${_qualityImpactNotes.take(2).join(' | ')}${_qualityImpactNotes.length > 2 ? ' +${_qualityImpactNotes.length - 2} more' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A6200),
                ),
              ),
            ),
          ],
          if (_lastOutputBytes != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB6DDF7)),
              ),
              child: Text(
                _selectedFiles.length > 1
                    ? 'ZIP ready: ${_formatBytes(_lastOutputBytes!.length)}'
                    : 'Final file size: ${_formatBytes(_lastOutputBytes!.length)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B4F7D),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppleButton(
            label: 'Download Compressed File',
            icon: Icons.download,
            onPressed: _downloadCompressed,
            isPrimary: true,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF007AFF) : Colors.black,
          ),
        ),
      ],
    );
  }

  void _selectFile() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      if (!mounted) return;
      final report = FilePickerService.lastSelectionReport;

      if (files.isEmpty) {
        setState(() {
          _statusMessage = report.cancelled
              ? 'File selection cancelled'
              : 'No usable files selected. ${report.buildSummaryMessage()}';
        });
        if (!report.cancelled && mounted && report.hasFilteredFiles) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(report.buildSummaryMessage()),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFiles = files;
        _selectedFile = files.first.bytes;
        _selectedFileName = files.first.name;
        _statusMessage = files.length == 1
            ? '✓ File selected: ${files.first.name}. Ready to compress.'
            : '✓ ${files.length} files selected. Ready to compress.';
        _originalFileSize = files.first.size;
        _applyDefaultTargetSize(files.first.size);
        _compressedFileSize = null; // Reset previous results
        _filesAboveTarget = [];
        _qualityImpactNotes = [];
      });
      if (report.hasFilteredFiles && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.buildSummaryMessage()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open file picker. Please check permissions and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startCompression() async {
    if (_selectedFile == null || _targetSizeBytes == null || _selectedFiles.isEmpty) return;

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'compress',
    );
    if (!allowed) return;

    setState(() {
      _isCompressing = true;
      _statusMessage = _selectedFiles.length > 1
          ? 'Compressing ${_selectedFiles.length} files...'
          : 'Compressing file...';
    });

            // Allow the loading state to render before compression starts.
            await _yieldToUi(60);

    try {
      if (_selectedFiles.length == 1) {
        final selected = _selectedFiles.first;
        var outcome = await _compressSingleFile(selected);
        var compressed = outcome.bytes;

        if (compressed.length > _targetSizeBytes!) {
          final allowForce = await _confirmForceQualityReduction(
            fileName: selected.name,
            targetBytes: _targetSizeBytes!,
            currentBytes: compressed.length,
          );

          if (allowForce) {
            final forced = await _forceCompressSingleFile(selected, compressed);
            if (forced.length < compressed.length) {
              compressed = forced;
              outcome = _CompressionOutcome(
                bytes: forced,
                aggressiveUsed: true,
                reductionPercent: _reductionPercent(selected.size, forced.length),
                targetMet: forced.length <= _targetSizeBytes!,
                note: forced.length <= _targetSizeBytes!
                    ? 'Target achieved after force compression.'
                    : 'Requested target could not be reached without unacceptable quality loss. Returning best possible output.',
              );
            }
          }
        }

        if (!mounted) return;

        setState(() {
          _compressedFileSize = compressed.length;
          _originalFileSize = selected.size;
          _compressionRatio = compressed.length / selected.size;
          _lastOutputBytes = compressed;
          _lastOutputName = selected.name;
          _filesAboveTarget = compressed.length <= _targetSizeBytes!
              ? const []
              : ['${selected.name}: max reduced to ${_formatBytes(compressed.length)} only'];
          _qualityImpactNotes = outcome.aggressiveUsed && compressed.length <= _targetSizeBytes!
              ? ['${selected.name}: quality may reduce by about ${outcome.reductionPercent.toStringAsFixed(0)}% to reach ${_formatBytes(_targetSizeBytes!)}']
              : const [];
          _isCompressing = false;
          _statusMessage = compressed.length <= _targetSizeBytes!
              ? (outcome.aggressiveUsed
                  ? '✓ Compressed to ${_formatBytes(compressed.length)} (target met with quality reduction)'
                  : '✓ Compressed to ${_formatBytes(compressed.length)} (target met)')
              : '⚠ ${outcome.note}';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File completed. Download link is ready.'),
            backgroundColor: Colors.green,
          ),
        );

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: 'Compressed File Completed',
            fileName: selected.name,
            outputBytes: Uint8List.fromList(compressed.toList()),
            originalFileSizeBytes: selected.size,
          ),
        );
        return;
      }

      final archive = Archive();
      int totalOriginal = 0;
      int totalCompressed = 0;
      final aboveTarget = <String>[];
      final qualityNotes = <String>[];
      final compressedByName = <String, Uint8List>{};
      final originalByName = <String, PickedFileData>{};
      var currentIndex = 0;

      for (final file in _selectedFiles) {
        currentIndex += 1;
        if (mounted) {
          setState(() {
            _statusMessage = 'Compressing file $currentIndex/${_selectedFiles.length}: ${file.name}';
          });
        }
        await _yieldToUi();

        final outcome = await _compressSingleFile(file);
        final compressed = outcome.bytes;
        compressedByName[file.name] = compressed;
        originalByName[file.name] = file;
        totalOriginal += file.size;
        totalCompressed += compressed.length;
        if (compressed.length > _targetSizeBytes!) {
          aboveTarget.add('${file.name}: max reduced to ${_formatBytes(compressed.length)} only');
        } else if (outcome.aggressiveUsed) {
          qualityNotes.add('${file.name}: quality may reduce by about ${outcome.reductionPercent.toStringAsFixed(0)}% to reach ${_formatBytes(_targetSizeBytes!)}');
        }
      }

      if (aboveTarget.isNotEmpty) {
        final allowForce = await _confirmForceQualityReductionForBatch(
          targetBytes: _targetSizeBytes!,
          aboveTargetCount: aboveTarget.length,
        );

        if (allowForce) {
          aboveTarget.clear();
          qualityNotes.clear();
          totalOriginal = 0;
          totalCompressed = 0;
          currentIndex = 0;

          for (final file in _selectedFiles) {
            currentIndex += 1;
            if (mounted) {
              setState(() {
                _statusMessage =
                    'Force pass $currentIndex/${_selectedFiles.length}: ${file.name}';
              });
            }
            await _yieldToUi();

            final current = compressedByName[file.name] ?? file.bytes;
            final forced = await _forceCompressSingleFile(file, current);
            final best = forced.length < current.length ? forced : current;
            compressedByName[file.name] = best;

            totalOriginal += file.size;
            totalCompressed += best.length;

            if (best.length > _targetSizeBytes!) {
              aboveTarget.add('${file.name}: max reduced to ${_formatBytes(best.length)} only');
            } else {
              qualityNotes.add('${file.name}: quality reduced to reach ${_formatBytes(_targetSizeBytes!)}');
            }
          }
        }
      }

      for (final file in _selectedFiles) {
        final bytes = compressedByName[file.name] ?? file.bytes;
        archive.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Unable to build ZIP download.');
      }

      if (!mounted) return;

      setState(() {
        _compressedFileSize = totalCompressed;
        _originalFileSize = totalOriginal;
        _compressionRatio = totalCompressed / totalOriginal;
        _lastOutputBytes = Uint8List.fromList(zipBytes);
        _lastOutputName = 'jobready_compressed_files.zip';
        _filesAboveTarget = aboveTarget;
        _qualityImpactNotes = qualityNotes;
        _isCompressing = false;
        _statusMessage = aboveTarget.isNotEmpty
          ? '⚠ Best effort only: one or more files could not be reduced to the requested size in the browser.'
          : (qualityNotes.isNotEmpty
            ? '✓ ${_selectedFiles.length} files compressed (target met, quality reduced for ${qualityNotes.length} file(s))'
            : '✓ ${_selectedFiles.length} files compressed (each met ${_formatBytes(_targetSizeBytes!)})');
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch completed. Download link is ready.'),
          backgroundColor: Colors.green,
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Compressed ZIP Completed',
          fileName: 'jobready_compressed_files.zip',
          outputBytes: Uint8List.fromList(zipBytes.toList()),
          originalFileSizeBytes: totalOriginal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString();
      setState(() {
        _isCompressing = false;
        _statusMessage = '✗ Compression failed: $errorMessage';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compression failed: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<_CompressionOutcome> _compressSingleFile(PickedFileData file) async {
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.pdf')) {
      if (kIsWeb) {
        await _yieldToUi();
        final remote = await _remoteCompressionService.compressPdf(
          bytes: file.bytes,
          fileName: file.name,
          targetBytes: _targetSizeBytes!,
          mode: _selectedCompressionMode,
          pipelineMode: _pipelineMode,
        );

        return _CompressionOutcome(
          bytes: remote.bytes,
          aggressiveUsed: _pipelineMode == CompressionPipelineMode.highCompressionImageOnly,
          reductionPercent: _reductionPercent(file.size, remote.bytes.length),
          targetMet: remote.targetMet,
          note: remote.message,
        );
      }

      final smart = await _compressionService.compressPdfSmart(
        file.bytes,
        _targetSizeBytes!,
        file.name,
        mode: _selectedCompressionMode,
        pipelineMode: _pipelineMode,
      );

      if (smart.targetMet) {
        return _CompressionOutcome(
          bytes: smart.bytes,
          aggressiveUsed: false,
          reductionPercent: _reductionPercent(file.size, smart.bytes.length),
          targetMet: true,
          note: smart.message,
        );
      }

      final aggressive = await _compressionService.forceCompressPdfToTarget(
        smart.bytes,
        _targetSizeBytes!,
        file.name,
        pipelineMode: _pipelineMode,
      );
      final best = aggressive.length < smart.bytes.length ? aggressive : smart.bytes;
      return _CompressionOutcome(
        bytes: best,
        aggressiveUsed: true,
        reductionPercent: _reductionPercent(file.size, best.length),
        targetMet: best.length <= _targetSizeBytes!,
        note: best.length <= _targetSizeBytes!
            ? 'Target achieved after force compression.'
            : 'Requested target could not be reached without unacceptable quality loss. Returning best possible output.',
      );
    }

    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png')) {
      await _yieldToUi();
      final primary = _compressionService.compressImage(file.bytes, _targetSizeBytes!, file.name);
      if (primary.length <= _targetSizeBytes!) {
        return _CompressionOutcome(
          bytes: primary,
          aggressiveUsed: false,
          reductionPercent: _reductionPercent(file.size, primary.length),
          targetMet: true,
          note: 'Target achieved.',
        );
      }

      final aggressiveTarget = (_targetSizeBytes! / 2).round().clamp(1, _targetSizeBytes!);
      await _yieldToUi();
      final aggressive = _compressionService.compressImage(primary, aggressiveTarget, file.name);
      final best = aggressive.length < primary.length ? aggressive : primary;
      return _CompressionOutcome(
        bytes: best,
        aggressiveUsed: true,
        reductionPercent: _reductionPercent(file.size, best.length),
        targetMet: best.length <= _targetSizeBytes!,
        note: best.length <= _targetSizeBytes!
            ? 'Target achieved after additional pass.'
            : 'Requested target could not be reached without unacceptable quality loss. Returning best possible output.',
      );
    }

    if (lowerName.endsWith('.webp') || lowerName.endsWith('.bmp')) {
      await _yieldToUi();
      final primary = _compressionService.compressImage(file.bytes, _targetSizeBytes!, file.name);
      if (primary.length <= _targetSizeBytes!) {
        return _CompressionOutcome(
          bytes: primary,
          aggressiveUsed: false,
          reductionPercent: _reductionPercent(file.size, primary.length),
          targetMet: true,
          note: 'Target achieved.',
        );
      }

      final aggressiveTarget = (_targetSizeBytes! / 2).round().clamp(1, _targetSizeBytes!);
      await _yieldToUi();
      final aggressive = _compressionService.compressImage(primary, aggressiveTarget, file.name);
      final best = aggressive.length < primary.length ? aggressive : primary;
      return _CompressionOutcome(
        bytes: best,
        aggressiveUsed: true,
        reductionPercent: _reductionPercent(file.size, best.length),
        targetMet: best.length <= _targetSizeBytes!,
        note: best.length <= _targetSizeBytes!
            ? 'Target achieved after additional pass.'
            : 'Requested target could not be reached without unacceptable quality loss. Returning best possible output.',
      );
    }

    throw Exception('Unsupported file for compression: ${file.name}');
  }

  Future<Uint8List> _forceCompressSingleFile(PickedFileData file, Uint8List currentBytes) async {
    final lowerName = file.name.toLowerCase();

    if (lowerName.endsWith('.pdf')) {
      if (kIsWeb) {
        final remote = await _remoteCompressionService.compressPdf(
          bytes: currentBytes,
          fileName: file.name,
          targetBytes: _targetSizeBytes!,
          mode: PdfCompressionMode.targetSize,
          pipelineMode: CompressionPipelineMode.highCompressionImageOnly,
        );
        if (remote.bytes.length < currentBytes.length) {
          return remote.bytes;
        }
      }

      return _compressionService.forceCompressPdfToTarget(
        currentBytes,
        _targetSizeBytes!,
        file.name,
        pipelineMode: _pipelineMode,
      );
    }

    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') || lowerName.endsWith('.bmp')) {
      final tighterTarget = (_targetSizeBytes! * 0.35).round().clamp(1, _targetSizeBytes!);
      await _yieldToUi();
      final pass1 = _compressionService.compressImage(currentBytes, tighterTarget, file.name);
      await _yieldToUi();
      final pass2 = _compressionService.compressImage(pass1, tighterTarget, file.name);
      return pass2.length < pass1.length ? pass2 : pass1;
    }

    return currentBytes;
  }

  Future<void> _yieldToUi([int ms = 16]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  Future<bool> _confirmForceQualityReduction({
    required String fileName,
    required int targetBytes,
    required int currentBytes,
  }) async {
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Force 100% Target?'),
        content: Text(
          '$fileName is currently at ${_formatBytes(currentBytes)}.\n\nWe can try to convert to ${_formatBytes(targetBytes)}, but document quality will reduce.\n\nDo you want to continue? Press YES to process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YES'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<bool> _confirmForceQualityReductionForBatch({
    required int targetBytes,
    required int aboveTargetCount,
  }) async {
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Force Target For Remaining Files?'),
        content: Text(
          '$aboveTargetCount file(s) are above ${_formatBytes(targetBytes)}.\n\nWe can try to convert them to ${_formatBytes(targetBytes)}, but document quality will reduce.\n\nDo you want to continue? Press YES to process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YES'),
          ),
        ],
      ),
    );

    return result == true;
  }

  void _downloadCompressed() {
    if (_lastOutputBytes == null || _lastOutputName == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (_) => DownloadResultDialog(
        outputFormat: 'Compressed File',
        fileName: _lastOutputName!,
        outputBytes: Uint8List.fromList(_lastOutputBytes!.toList()),
        originalFileSizeBytes: _originalFileSize,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  double _reductionPercent(int originalBytes, int compressedBytes) {
    if (originalBytes <= 0) {
      return 0;
    }
    final reduced = originalBytes - compressedBytes;
    return ((reduced / originalBytes) * 100).clamp(0, 100).toDouble();
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Compressing')) return Colors.blue;
    return Colors.grey;
  }
}
