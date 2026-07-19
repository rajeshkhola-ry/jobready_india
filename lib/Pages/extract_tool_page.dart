import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'dart:typed_data';

import '../Widgets/download_result_dialog.dart';
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
  String _extractType = 'text'; // 'text', 'images', 'pages', 'tables'
  bool _isExtracting = false;
  String _statusMessage = 'Ready to extract';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _hydrateFromHomeUpload() {
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

    setState(() {
      _selectedFiles = files;
      _selectedFile = file.name;
      _selectedFileBytes = file.bytes;
      _selectedFileSize = file.size;
      _activePdfPageCount = pageCount;
      _statusMessage = files.length == 1
          ? '✓ ${file.name} loaded from workspace${file.name.toLowerCase().endsWith('.pdf') ? ' (${pageCount} pages)' : ''}'
          : '✓ ${files.length} files loaded from workspace';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Extract from PDF',
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
                                Icons.file_download_rounded,
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
                                    'Extract from PDF',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Extract text, images, or pages',
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
                                _selectedFile == null ? 'Choose File' : 'Change File',
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
                                if (_selectedFileSize != null)
                                  Text(
                                    '${_formatBytes(_selectedFileSize!)}${_selectedFile!.toLowerCase().endsWith('.pdf') ? ' • $_activePdfPageCount pages' : ''}',
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

                  // Step 2: Choose Extraction Type
                  if (_selectedFile != null)
                    _panel(
                      number: 2,
                      title: 'Extraction Type',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExtractionOption('text', 'Extract Text', Icons.text_fields_rounded),
                          const SizedBox(height: 8),
                          _buildExtractionOption('images', 'Extract Images', Icons.image_rounded),
                          const SizedBox(height: 8),
                          _buildExtractionOption('pages', 'Extract as Pages', Icons.photo_rounded),
                          const SizedBox(height: 8),
                          _buildExtractionOption('tables', 'Extract Tables/Forms', Icons.table_chart_rounded),
                        ],
                      ),
                    ),
                  if (_selectedFile != null) const SizedBox(height: 20),

                  // Step 3: Extract
                  if (_selectedFile != null)
                    _panel(
                      number: 3,
                      title: 'Extract Content',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD8E5F5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF0E3A66),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getExtractionTypeLabel(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0E3A66),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E3A66),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isExtracting ? null : _startExtract,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isExtracting)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.file_download_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  _isExtracting ? 'Extracting...' : 'Start Extract',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          if (_isExtracting) ...[
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
                  if (_selectedFile != null) const SizedBox(height: 20),

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
          color: isSelected ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0E3A66) : const Color(0xFFD8E5F5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0E3A66) : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF0E3A66) : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0E3A66),
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
            ? '✓ ${file.name} selected${file.name.toLowerCase().endsWith('.pdf') ? ' (${pageCount} pages)' : ''}'
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

  Future<void> _startExtract() async {
    if (_selectedFiles.isEmpty || _selectedFileBytes == null || _selectedFile == null) {
      setState(() {
        _statusMessage = '✗ Select a file to extract from';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _statusMessage = 'Extracting $_extractType...';
    });

    await Future.delayed(const Duration(milliseconds: 60));

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
          _statusMessage = '✓ Table extraction completed — ${_formatBytes(results.fold<int>(0, (sum, f) => sum + (f.content as List).length))} ready';
        });

        if (results.length == 1) {
          final single = results.first;
          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Tables/Forms',
              fileName: single.name,
              outputBytes: Uint8List.fromList(List<int>.from(single.content as List)),
            ),
          );
        } else {
          final archive = Archive();
          for (final f in results) archive.addFile(f);
          final zipBytes = ZipEncoder().encode(archive);
          if (zipBytes == null) throw Exception('Unable to create table extraction ZIP');
          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Tables/Forms Batch',
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
            _statusMessage = '✓ Text extraction completed — ${_formatBytes(result.outputBytes!.length)} ready';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Extraction completed. Download is ready.'),
                backgroundColor: Color(0xFF166534),
              ),
            );
          }

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
          throw Exception('Unable to create extraction ZIP output');
        }

        if (!mounted) return;
        setState(() {
          _isExtracting = false;
          _statusMessage = '✓ Text extraction completed — ${_formatBytes(zipBytes.length)} ready';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Extraction completed. Download is ready.'),
              backgroundColor: Color(0xFF166534),
            ),
          );
        }

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
        throw Exception('Image/page extraction requires PDF files');
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
        throw Exception('Unable to create extraction ZIP output');
      }

      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _statusMessage = '✓ Image extraction completed — ${_formatBytes(zipBytes.length)} ready';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extraction completed. Download is ready.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<int> _pageNumbersFromSelection() {
    final maxPages = _activePdfPageCount > 0 ? _activePdfPageCount : 1;
    return [for (var page = 1; page <= maxPages; page++) page];
  }

  String _getExtractionTypeLabel() {
    switch (_extractType) {
      case 'text':
        return 'Extract text from PDF documents';
      case 'images':
        return 'Extract images embedded in PDF';
      case 'pages':
        return 'Extract all pages as images';
      case 'tables':
        return 'Extract tables and form data';
      default:
        return 'Extract from PDF';
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
    if (_statusMessage.startsWith('Extracting')) return _StatusType.processing;
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
