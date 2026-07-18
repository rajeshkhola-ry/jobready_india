import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../Widgets/download_result_dialog.dart';
import '../Widgets/quota_gate.dart';
import '../Services/file_picker_service.dart';
import '../Services/pdf_editor_service.dart';
import '../Services/upload_context_service.dart';

/// Split Tool Page - Extract pages from PDF or split into multiple files
/// User selects file → Sets page ranges → Splits
class SplitToolPage extends StatefulWidget {
  const SplitToolPage({super.key});

  @override
  State<SplitToolPage> createState() => _SplitToolPageState();
}

class _SplitToolPageState extends State<SplitToolPage> {
  final PdfEditorService _pdfEditorService = const PdfEditorService();
  List<PickedFileData> _selectedFiles = const [];
  String? _selectedFile;
  Uint8List? _selectedFileBytes;
  int _totalPages = 0;
  String _splitMethod = 'range'; // 'range' or 'extract'
  List<String> _pageRanges = ['1-5']; // e.g., ['1-5', '10-15']
  TextEditingController _pageRangeController = TextEditingController();
  bool _isSplitting = false;
  String _statusMessage = 'Ready to split';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  Future<void> _hydrateFromHomeUpload() async {
    final cachedFiles = UploadContextService.getCompatibleFiles(['pdf']);
    if (cachedFiles.isEmpty) {
      return;
    }

    final cached = cachedFiles.first;
    final totalPages = _resolvePdfPageCount(cached.bytes);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFiles = cachedFiles;
      _selectedFile = cached.name;
      _selectedFileBytes = cached.bytes;
      _totalPages = totalPages;
      _statusMessage = '✓ ${cached.name} loaded from workspace (${totalPages} pages)';
    });
  }

  int _resolvePdfPageCount(Uint8List bytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        return document.pages.count;
      } finally {
        document.dispose();
      }
    } catch (_) {
      return 1;
    }
  }

  @override
  void dispose() {
    _pageRangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A66),
        elevation: 0,
        title: const Text(
          'Split PDF',
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
                                Icons.content_cut_rounded,
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
                                    'Split PDF',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Extract pages or divide into multiple files',
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

                  // Step 1: Select File
                  _panel(
                    number: 1,
                    title: 'Choose File',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E3A66),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _selectFile,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.upload_file_rounded),
                              const SizedBox(width: 8),
                              Text(
                                _selectedFile == null ? 'Choose PDF' : 'Change File',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD8E5F5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF166534),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedFile!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Total pages: $_totalPages',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step 2: Split Method
                  if (_selectedFile != null)
                    _panel(
                      number: 2,
                      title: 'Split Method',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMethodButton('range', 'By Page Range'),
                          const SizedBox(height: 8),
                          _buildMethodButton('extract', 'Extract Specific Pages'),
                        ],
                      ),
                    ),
                  if (_selectedFile != null) const SizedBox(height: 20),

                  // Step 3: Configure Split
                  if (_selectedFile != null)
                    _panel(
                      number: 3,
                      title: 'Configure Split',
                      child: _splitMethod == 'range'
                          ? _buildRangeInput()
                          : _buildExtractInput(),
                    ),
                  if (_selectedFile != null) const SizedBox(height: 20),

                  // Step 4: Create Split PDF
                  if (_selectedFile != null && _pageRanges.isNotEmpty)
                    _panel(
                      number: 4,
                      title: 'Create Split PDF',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E3A66),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isSplitting ? null : _startSplit,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSplitting)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.content_cut_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  _isSplitting ? 'Splitting...' : 'Start Split (${_pageRanges.length} part${_pageRanges.length > 1 ? 's' : ''})',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          if (_isSplitting) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: const Color(0xFFE0E7FF),
                              valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_selectedFile != null && _pageRanges.isNotEmpty) const SizedBox(height: 20),

                  // Status
                  _StatusRow(
                    message: _statusMessage,
                    type: _getStatusType(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({
    required int number,
    required String title,
    required Widget child,
  }) {
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFF0E3A66),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMethodButton(String value, String label) {
    final isSelected = _splitMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _splitMethod = value;
          _pageRanges = value == 'range' ? ['1-5'] : [];
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0E3A66) : const Color(0xFFD8E5F5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0E3A66) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF0E3A66),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF0E3A66) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Page ranges (e.g., 1-5, 10-15)',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pageRangeController,
          decoration: InputDecoration(
            hintText: 'Enter page range',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD8E5F5)),
            ),
            suffix: GestureDetector(
              onTap: _addPageRange,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.add_circle_rounded, color: Color(0xFF0E3A66)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_pageRanges.isNotEmpty)
          Wrap(
            spacing: 8,
            children: _pageRanges
                .map(
                  (range) => Chip(
                    label: Text(range),
                    backgroundColor: const Color(0xFFEAF2FF),
                    labelStyle: const TextStyle(
                      color: Color(0xFF0E3A66),
                      fontWeight: FontWeight.w600,
                    ),
                    onDeleted: () {
                      setState(() => _pageRanges.remove(range));
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildExtractInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select pages to extract ($_totalPages total)',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8E5F5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            separatorBuilder: (_, __) => Divider(height: 1, color: const Color(0xFFE0E7FF)),
            itemBuilder: (context, index) {
              final pageNum = index + 1;
              final isSelected = _pageRanges.contains('$pageNum');
              return Container(
                color: isSelected ? const Color(0xFFEAF2FF).withValues(alpha: 0.5) : Colors.transparent,
                child: CheckboxListTile(
                  title: Text('Page $pageNum'),
                  value: isSelected,
                  activeColor: const Color(0xFF0E3A66),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _pageRanges.add('$pageNum');
                      } else {
                        _pageRanges.remove('$pageNum');
                      }
                    });
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addPageRange() {
    final range = _pageRangeController.text.trim();
    if (range.isNotEmpty) {
      setState(() {
        _pageRanges.add(range);
        _pageRangeController.clear();
      });
    }
  }

  void _selectFile() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) {
        setState(() {
          _statusMessage = 'File selection cancelled';
        });
        return;
      }

      final file = files.first;
      final totalPages = _resolvePdfPageCount(file.bytes);

      setState(() {
        _selectedFiles = files;
        _selectedFile = file.name;
        _selectedFileBytes = file.bytes;
        _totalPages = totalPages;
        _statusMessage = files.length == 1
            ? '✓ ${file.name} selected (${totalPages} pages)'
            : '✓ ${files.length} files selected';
      });
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

  Future<void> _startSplit() async {
    if (_selectedFiles.isEmpty || _selectedFileBytes == null || _selectedFile == null) {
      setState(() {
        _statusMessage = '✗ Select a file to split';
      });
      return;
    }

    if (_pageRanges.isEmpty) {
      setState(() {
        _statusMessage = '✗ Select at least 1 page range';
      });
      return;
    }

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'split',
    );
    if (!allowed) return;

    setState(() {
      _isSplitting = true;
      _statusMessage = 'Splitting into ${_pageRanges.length} part(s)...';
    });

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final archive = Archive();
      for (final input in _selectedFiles) {
        final files = await _pdfEditorService.splitPdfByRanges(
          input.bytes,
          input.name,
          _pageRanges,
        );

        for (final file in files) {
          archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Unable to create split ZIP output');
      }

      if (!mounted) return;
      setState(() {
        _isSplitting = false;
        _statusMessage = '✓ Split completed — ${_formatBytes(zipBytes.length)} ready for download';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split completed. Download is ready.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Split PDF Package',
          fileName: 'jobready_split_files.zip',
          outputBytes: Uint8List.fromList(zipBytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSplitting = false;
        _statusMessage = '✗ Split failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  _StatusType _getStatusType() {
    if (_statusMessage.startsWith('✓')) return _StatusType.success;
    if (_statusMessage.startsWith('✗')) return _StatusType.error;
    if (_statusMessage.startsWith('Splitting')) return _StatusType.processing;
    return _StatusType.idle;
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
