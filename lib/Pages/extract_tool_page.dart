import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import '../Widgets/apple_button.dart';
import '../Widgets/download_result_dialog.dart';
import '../Widgets/site_footer_link.dart';
import '../Services/conversion_service.dart';
import '../Services/pdf_editor_service.dart';
import '../Services/pdf_ocr_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/upload_context_service.dart';

/// Extract Tool Page - Extract text, images, or pages from PDF
/// User selects file → Chooses extraction type → Extracts
class ExtractToolPage extends StatefulWidget {
  const ExtractToolPage({super.key});

  @override
  State<ExtractToolPage> createState() => _ExtractToolPageState();
}

class _ExtractToolPageState extends State<ExtractToolPage> {
  final PdfEditorService _pdfEditorService = const PdfEditorService();
  final ConversionService _conversionService = const ConversionService();
  final PdfOcrService _ocrService = const PdfOcrService();
  List<PickedFileData> _selectedFiles = const [];
  String? _selectedFile;
  Uint8List? _selectedFileBytes;
  int? _selectedFileSize;
  int _activePdfPageCount = 1;
  String _extractType = 'text'; // 'text', 'images', 'pages'
  bool _isExtracting = false;
  String _statusMessage = 'Ready to extract';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _hydrateFromHomeUpload() {
    if (kIsWeb) {
      return;
    }

    final files = UploadContextService.getCompatibleFiles([
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'doc',
      'docx',
    ]);
    if (files.isEmpty) {
      return;
    }

    final file = files.first;
    final pageCount = file.name.toLowerCase().endsWith('.pdf')
        ? _resolvePdfPageCount(file.bytes)
        : 1;

    _selectedFiles = files;
    _selectedFile = file.name;
    _selectedFileBytes = file.bytes;
    _selectedFileSize = file.size;
    _activePdfPageCount = pageCount;
    _statusMessage = files.length == 1
        ? '✓ ${file.name} loaded from Home upload${file.name.toLowerCase().endsWith('.pdf') ? ' ($pageCount pages)' : ''}'
        : '✓ ${files.length} files loaded from Home upload';
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
          'Extract from PDF',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safeWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final safeHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFiles.length > 1
                                      ? '${_selectedFiles.length} files selected'
                                      : _selectedFile!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedFileSize != null)
                                  Text(
                                    _selectedFiles.length > 1
                                        ? 'Total: ${_formatBytes(_selectedFiles.fold<int>(0, (sum, f) => sum + f.size))}'
                                        : _formatBytes(_selectedFileSize!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: Choose Extraction Type
            if (_selectedFile != null)
              _buildStepCard(
                step: 2,
                title: 'Choose Extraction Type',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExtractionOption('text', 'Extract Text', Icons.text_fields),
                    const SizedBox(height: 8),
                    _buildExtractionOption('tables', 'Extract Tables / Forms', Icons.table_chart_outlined),
                    const SizedBox(height: 8),
                    _buildExtractionOption('images', 'Extract Images', Icons.image),
                    const SizedBox(height: 8),
                    _buildExtractionOption('pages', 'Extract as Images', Icons.photo),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Step 3: Extract
            if (_selectedFile != null)
              _buildStepCard(
                step: 3,
                title: 'Extract',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: Color(0xFF007AFF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getExtractionTypeLabel(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppleButton(
                      label: _isExtracting ? 'Extracting...' : 'Start Extract',
                      icon: _isExtracting ? Icons.hourglass_empty : Icons.download,
                      onPressed: _isExtracting ? null : _startExtract,
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
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const SiteFooterLink(),
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

  Widget _buildExtractionOption(String value, String label, IconData icon) {
    final isSelected = _extractType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _extractType = value;
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
            Icon(
              icon,
              color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade600,
              size: 22,
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
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF007AFF),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  void _selectFile() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (files.isEmpty) {
        setState(() {
          _statusMessage = 'File selection cancelled';
        });
        return;
      }

      final file = files.first;
      final pageCount = file.name.toLowerCase().endsWith('.pdf')
          ? _resolvePdfPageCount(file.bytes)
          : 1;

      setState(() {
        _selectedFiles = files;
        _selectedFile = file.name;
        _selectedFileBytes = file.bytes;
        _selectedFileSize = file.size;
        _activePdfPageCount = pageCount;
        _statusMessage = files.length == 1
            ? '✓ ${file.name} selected${file.name.toLowerCase().endsWith('.pdf') ? ' ($pageCount pages)' : ''}'
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

  Future<void> _startExtract() async {
    if (_selectedFiles.isEmpty || _selectedFileBytes == null || _selectedFile == null) return;

    setState(() {
      _isExtracting = true;
      _statusMessage = _selectedFiles.length > 1
          ? 'Extracting $_extractType from ${_selectedFiles.length} files...'
          : 'Extracting $_extractType from PDF...';
    });

    try {
      if (_extractType == 'tables') {
        final results = <ArchiveFile>[];
        for (final input in _selectedFiles) {
          if (!input.name.toLowerCase().endsWith('.pdf')) continue;
          final result = await _ocrService.extractText(
            pdfBytes: input.bytes,
            fileName: input.name,
            mode: PdfExtractionMode.tableAware,
          );
          final text = result.success && result.text.trim().isNotEmpty
              ? result.text
              : 'No table or form content found in ${input.name}.';
          final outName = input.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '_tables.txt');
          results.add(ArchiveFile(outName, text.codeUnits.length, text.codeUnits));
        }

        if (!mounted) return;
        setState(() {
          _isExtracting = false;
          _statusMessage = '✓ Table extraction completed';
        });

        if (results.length == 1) {
          final single = results.first;
          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Tables / Forms',
              fileName: single.name,
              outputBytes: Uint8List.fromList(List<int>.from(single.content as List)),
            ),
          );
        } else {
          final archive = Archive();
          for (final f in results) archive.addFile(f);
          final zipBytes = ZipEncoder().encode(archive);
          if (zipBytes == null) throw Exception('Unable to create table extraction ZIP.');
          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Tables / Forms Batch',
              fileName: 'jobready_tables_extracted.zip',
              outputBytes: Uint8List.fromList(zipBytes),
            ),
          );
        }
        return;
      }

      if (_extractType == 'text') {
        if (_selectedFiles.length == 1) {
          final result = await _conversionService.convert(
            inputBytes: _selectedFileBytes!,
            inputFileName: _selectedFile!,
            outputFormat: 'Text (.txt)',
          );

          if (!result.success || result.outputBytes == null || result.outputFileName == null) {
            throw Exception(result.message);
          }

          if (!mounted) return;
          setState(() {
            _isExtracting = false;
            _statusMessage = '✓ Extraction completed successfully';
          });

          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Extracted Text',
              fileName: result.outputFileName!,
              outputBytes: result.outputBytes!,
            ),
          );
          return;
        }

        final archive = Archive();
        for (final input in _selectedFiles) {
          final result = await _conversionService.convert(
            inputBytes: input.bytes,
            inputFileName: input.name,
            outputFormat: 'Text (.txt)',
          );

          if (!result.success || result.outputBytes == null || result.outputFileName == null) {
            throw Exception(result.message);
          }

          archive.addFile(
            ArchiveFile(result.outputFileName!, result.outputBytes!.length, result.outputBytes!),
          );
        }

        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) {
          throw Exception('Unable to create extraction ZIP output.');
        }

        if (!mounted) return;
        setState(() {
          _isExtracting = false;
          _statusMessage = '✓ Extraction completed successfully';
        });

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: 'Extracted Text Batch',
            fileName: 'jobready_extracted_text_files.zip',
            outputBytes: Uint8List.fromList(zipBytes),
          ),
        );
        return;
      }

      final pdfInputs = _selectedFiles.where((item) => item.name.toLowerCase().endsWith('.pdf')).toList(growable: false);
      if (pdfInputs.isEmpty) {
        throw Exception('Image/page extraction requires PDF files.');
      }

      final pages = _extractType == 'pages'
          ? _pageNumbersFromSelection()
          : [for (var page = 1; page <= 5; page++) page];

      final archive = Archive();
      for (final input in pdfInputs) {
        final files = await _pdfEditorService.extractPageImages(
          input.bytes,
          input.name,
          pages,
        );
        for (final file in files) {
          archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Unable to create extraction ZIP output.');
      }

      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _statusMessage = '✓ Extraction completed successfully';
      });

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Extracted Images',
          fileName: 'jobready_extracted_files.zip',
          outputBytes: Uint8List.fromList(zipBytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _statusMessage = '✗ Extraction failed: $e';
      });
    }
  }

  List<int> _pageNumbersFromSelection() {
    final maxPages = _activePdfPageCount > 0 ? _activePdfPageCount : 1;
    return [for (var page = 1; page <= maxPages; page++) page];
  }

  String _getExtractionTypeLabel() {
    switch (_extractType) {
      case 'text':
        return 'Extract text from PDF';
      case 'images':
        return 'Extract images from PDF';
      case 'pages':
        return 'Extract pages as images';
      default:
        return 'Extract from PDF';
    }
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Extracting')) return Colors.blue;
    return Colors.grey;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
