import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import '../Widgets/apple_button.dart';
import '../Widgets/download_result_dialog.dart';import '../Widgets/quota_gate.dart';import '../Services/file_picker_service.dart';
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
      _statusMessage = cachedFiles.length == 1
          ? '✓ ${cached.name} loaded from Home upload (${totalPages} pages)'
          : '✓ ${cachedFiles.length} files loaded from Home upload';
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
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Color(0xFFFFC72C)),
          ),
        ],
        title: const Text(
          'Split PDF',
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
            // Step 1: Select File
            _buildStepCard(
              step: 1,
              title: 'Choose File',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppleButton(
                    label: _selectedFiles.length > 1 ? 'Choose Files' : 'Choose File',
                    icon: Icons.upload_file,
                    onPressed: _selectFile,
                    isPrimary: _selectedFile == null,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedFile != null)
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
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedFiles.length > 1
                                      ? '${_selectedFiles.length} files selected'
                                      : _selectedFile!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFiles.length > 1
                                ? 'Ranges will apply to all selected files'
                                : 'Total pages: $_totalPages',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: Split Method
            if (_selectedFile != null)
              _buildStepCard(
                step: 2,
                title: 'Split Method',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMethodButton('range', 'By Page Range'),
                    const SizedBox(height: 8),
                    _buildMethodButton('extract', 'Extract Specific Pages'),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Step 3: Configure Split
            if (_selectedFile != null)
              _buildStepCard(
                step: 3,
                title: 'Configure Split',
                content: _splitMethod == 'range'
                    ? _buildRangeInput()
                    : _buildExtractInput(),
              ),
            const SizedBox(height: 20),

            // Step 4: Split
            if (_selectedFile != null && _pageRanges.isNotEmpty)
              _buildStepCard(
                step: 4,
                title: 'Split File',
                content: AppleButton(
                  label: _isSplitting ? 'Splitting...' : 'Start Split',
                  icon: _isSplitting ? Icons.hourglass_empty : Icons.content_cut,
                  onPressed: _isSplitting ? null : _startSplit,
                  isPrimary: true,
                  isFullWidth: true,
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
                border: Border.all(color: _getStatusColor()),
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
            if (_isSplitting) ...[
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
                        'Split is running... please wait.',
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
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text(
            'getreadyjob.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F4E79),
            ),
          ),
        ),
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
          color: isSelected ? const Color(0xFF007AFF).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade300,
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
                  color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade400,
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
                            color: Color(0xFF007AFF),
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
                color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade700,
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
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pageRangeController,
          decoration: InputDecoration(
            hintText: 'Enter page range',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            suffix: GestureDetector(
              onTap: _addPageRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Icon(Icons.add_circle, color: Color(0xFF007AFF)),
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
        const Text(
          'Select pages to extract',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              return CheckboxListTile(
                title: Text('Page ${index + 1}'),
                value: _pageRanges.contains('${index + 1}'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _pageRanges.add('${index + 1}');
                    } else {
                      _pageRanges.remove('${index + 1}');
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
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
        ? '✓ ${file.name} selected (${_totalPages} pages)'
            : '✓ ${files.length} files selected';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startSplit() async {
    if (_selectedFiles.isEmpty || _selectedFileBytes == null || _selectedFile == null) return;

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'split',
    );
    if (!allowed) return;

    setState(() {
      _isSplitting = true;
      _statusMessage = _selectedFiles.length > 1
          ? 'Splitting ${_selectedFiles.length} files...'
          : 'Splitting file into ${_pageRanges.length} part(s)...';
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
        throw Exception('Unable to create split ZIP output.');
      }

      if (!mounted) return;
      setState(() {
        _isSplitting = false;
        _statusMessage = _selectedFiles.length > 1
            ? '✓ Split completed for ${_selectedFiles.length} files'
            : '✓ Split completed successfully';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split completed. Download link is ready.'),
          backgroundColor: Colors.green,
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Split PDF Package Completed',
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
    }
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Splitting')) return Colors.blue;
    return Colors.grey;
  }
}
