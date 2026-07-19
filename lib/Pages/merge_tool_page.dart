import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../Widgets/download_result_dialog.dart';
import '../Widgets/quota_gate.dart';
import '../Services/file_picker_service.dart';
import '../Services/pdf_merge_service.dart';
import '../Services/upload_context_service.dart';

/// Merge Tool Page - Combine multiple PDFs into one
/// User selects multiple files → Sets merge order → Merges
class MergeToolPage extends StatefulWidget {
  const MergeToolPage({super.key});

  @override
  State<MergeToolPage> createState() => _MergeToolPageState();
}

class _MergeToolPageState extends State<MergeToolPage> {
  final PdfMergeService _mergeService = const PdfMergeService();
  List<String> _selectedFiles = [];
  List<Uint8List> _selectedFileBytes = [];
  List<int> _selectedFileSizes = [];
  bool _isMerging = false;
  String _statusMessage = 'Ready to merge';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _hydrateFromHomeUpload() {
    final files = UploadContextService.getCompatibleFiles(['pdf']);
    if (files.isEmpty) {
      return;
    }

    _selectedFiles = files.map((f) => f.name).toList();
    _selectedFileBytes = files.map((f) => f.bytes).toList();
    _selectedFileSizes = files.map((f) => f.size).toList();
    _statusMessage = '✓ ${files.length} PDF file(s) loaded from workspace';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
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
                    _panel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.call_merge,
                              color: Color(0xFF0E3A66),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Merge PDFs',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Combine multiple PDFs into a single file in your chosen order.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Step 1: Select Files
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E3A66),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Choose Files',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isMerging ? null : _selectFiles,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0E3A66),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              icon: const Icon(Icons.add_circle_rounded),
                              label: const Text('Choose PDF Files'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFiles.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFB8D0ED)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No files selected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Select 2 or more PDFs to merge',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          else
                            _buildFileList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Step 2: Merge Order
                    if (_selectedFiles.isNotEmpty) ...[
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E3A66),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Merge Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Files will merge from top to bottom.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildOrderList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Step 3: Merge
                    if (_selectedFiles.isNotEmpty) ...[
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E3A66),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Create Merged PDF',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isMerging ? null : _startMerge,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E3A66),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                icon: Icon(_isMerging
                                    ? Icons.hourglass_top_rounded
                                    : Icons.call_merge),
                                label: Text(_isMerging
                                    ? 'Merging...'
                                    : 'Start Merge (${_selectedFiles.length} files)'),
                              ),
                            ),
                            if (_isMerging) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(
                                backgroundColor: Color(0xFFD8E5F5),
                                color: Color(0xFF0E3A66),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Status
                    _StatusRow(message: _statusMessage, type: _getStatusType()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildFileList() {
    return Column(
      children: List.generate(
        _selectedFiles.length,
        (index) {
          return Padding(
            padding: index < _selectedFiles.length - 1
                ? const EdgeInsets.only(bottom: 8)
                : EdgeInsets.zero,
            child: Container(
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
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFiles[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatBytes(_selectedFileSizes[index]),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isMerging
                        ? null
                        : () {
                            setState(() {
                              _selectedFiles.removeAt(index);
                              _selectedFileBytes.removeAt(index);
                              _selectedFileSizes.removeAt(index);
                              if (_selectedFiles.isEmpty) {
                                _statusMessage = 'Files cleared.';
                              }
                            });
                          },
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 18,
                    color: const Color(0xFF94A3B8),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList() {
    return Column(
      children: List.generate(
        _selectedFiles.length,
        (index) {
          return Padding(
            padding: index < _selectedFiles.length - 1
                ? const EdgeInsets.only(bottom: 8)
                : EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E5F5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E3A66),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFiles[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatBytes(_selectedFileSizes[index]),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.drag_handle_rounded,
                    color: Color(0xFFB8D0ED),
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectFiles() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: ['pdf'],
      );

      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles = files.map((f) => f.name).toList();
          _selectedFileBytes = files.map((f) => f.bytes).toList();
          _selectedFileSizes = files.map((f) => f.size).toList();
          _statusMessage = '✓ ${files.length} PDF file(s) selected';
        });
      } else {
        setState(() {
          _statusMessage = 'File selection cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error selecting files: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startMerge() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _statusMessage = '✗ Select at least 1 PDF to merge';
      });
      return;
    }

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'merge',
    );
    if (!allowed) return;

    setState(() {
      _isMerging = true;
      _statusMessage = 'Merging ${_selectedFiles.length} files...';
    });

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final pickedFiles = [
        for (var index = 0; index < _selectedFiles.length; index++)
          PickedFileData(
            name: _selectedFiles[index],
            size: _selectedFileSizes[index],
            bytes: _selectedFileBytes[index],
          ),
      ];

      final mergedPdf = await _mergeService.mergePdfs(pickedFiles);

      if (!mounted) return;

      setState(() {
        _isMerging = false;
        _statusMessage = '✓ Merge completed — ${_formatBytes(mergedPdf.length)} ready for download';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merge completed. Download is ready.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Merged PDF',
          fileName: 'jobready_merged.pdf',
          outputBytes: mergedPdf,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMerging = false;
        _statusMessage = '✗ Merge failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  _StatusType _getStatusType() {
    if (_statusMessage.startsWith('✓')) return _StatusType.success;
    if (_statusMessage.startsWith('✗')) return _StatusType.error;
    if (_statusMessage.startsWith('Merging')) return _StatusType.processing;
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
