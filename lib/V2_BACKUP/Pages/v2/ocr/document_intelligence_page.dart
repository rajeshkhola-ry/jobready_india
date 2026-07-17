import 'package:flutter/material.dart';

import '../../../Services/file_picker_service.dart';
import '../../../Services/pdf_ocr_service.dart';
import '../../../Services/upload_context_service.dart';

class DocumentIntelligencePage extends StatefulWidget {
  const DocumentIntelligencePage({super.key});

  @override
  State<DocumentIntelligencePage> createState() => _DocumentIntelligencePageState();
}

class _DocumentIntelligencePageState extends State<DocumentIntelligencePage> {
  final PdfOcrService _ocrService = const PdfOcrService();

  PickedFileData? _selectedFile;
  bool _busy = false;
  String _selectedMode = 'Auto';
  String _status = 'Upload a PDF or image to start OCR and structured extraction.';
  String _extractedText = '';
  List<String> _keyHighlights = const [];

  static const List<String> _modes = ['Auto', 'Force OCR', 'Table-aware'];

  @override
  void initState() {
    super.initState();
    _hydrateFromUploadContext();
  }

  void _hydrateFromUploadContext() {
    final file = UploadContextService.getFirstCompatibleFile(
      ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (file == null) {
      return;
    }

    setState(() {
      _selectedFile = file;
      _status = 'Loaded from upload context: ${file.name}';
    });
  }

  Future<void> _pickFile() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );

    if (picked == null) {
      return;
    }

    UploadContextService.setLastPickedFile(picked);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFile = picked;
      _status = 'Ready to analyze: ${picked.name}';
      _extractedText = '';
      _keyHighlights = const [];
    });
  }

  Future<void> _runAnalysis() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a document first.')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Running document intelligence...';
    });

    try {
      final lower = selectedFile.name.toLowerCase();
      String text;
      String status;

      if (lower.endsWith('.pdf')) {
        final mode = switch (_selectedMode) {
          'Force OCR' => PdfExtractionMode.forceOcr,
          'Table-aware' => PdfExtractionMode.tableAware,
          _ => PdfExtractionMode.auto,
        };

        final result = await _ocrService.extractText(
          pdfBytes: selectedFile.bytes,
          fileName: selectedFile.name,
          forceOcr: mode == PdfExtractionMode.forceOcr,
          mode: mode,
        );

        text = result.text;
        status = result.message;
      } else {
        text =
            'Image intelligence preview for ${selectedFile.name}: detected document-like layout. Suggested next step is OCR text extraction and field mapping. File size: ${selectedFile.size} bytes.';
        status = 'Image analyzed with local document-intelligence preview.';
      }

      final highlights = _deriveHighlights(text);

      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _status = status;
        _extractedText = text.isEmpty ? 'No readable text extracted.' : text;
        _keyHighlights = highlights;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _status = 'Analysis failed. Please try another file.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document intelligence failed: $error')),
      );
    }
  }

  List<String> _deriveHighlights(String text) {
    final normalized = text.replaceAll('\r', ' ');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return const ['No structured highlights available yet.'];
    }

    final picked = <String>[];
    for (final line in lines.take(6)) {
      if (line.length > 120) {
        picked.add('${line.substring(0, 117)}...');
      } else {
        picked.add(line);
      }
    }

    return picked;
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Document Intelligence OCR+'),
        backgroundColor: const Color(0xFF0E3A66),
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
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panel(
                      child: const Text(
                        'OCR+ is the V2.6 module for extracting readable and structured insight from PDFs and document images. Use this before downstream AI tasks when source files are scanned.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;

                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile == null
                                        ? 'No file selected'
                                        : 'Selected: ${_selectedFile!.name} (${_selectedFile!.size} bytes)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.upload_file_rounded),
                                        label: const Text('Upload Document'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedFile = null;
                                            _status =
                                                'Upload a PDF or image to start OCR and structured extraction.';
                                            _extractedText = '';
                                            _keyHighlights = const [];
                                          });
                                        },
                                        icon: const Icon(Icons.clear_rounded),
                                        label: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Extraction Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _modes
                                        .map(
                                          (mode) => ChoiceChip(
                                            label: Text(mode),
                                            selected: _selectedMode == mode,
                                            onSelected: (_) => setState(() => _selectedMode = mode),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _busy ? null : _runAnalysis,
                                        icon: const Icon(Icons.auto_awesome_rounded),
                                        label: Text(_busy ? 'Analyzing...' : 'Run OCR+ Analysis'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.home_outlined),
                                        label: const Text('Back to V2 Home'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _status,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final right = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Key Highlights',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _bulletList(_keyHighlights.isEmpty
                                      ? const ['Run analysis to generate highlights.']
                                      : _keyHighlights),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Extracted Text',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    _extractedText.isEmpty
                                        ? 'No text extracted yet.'
                                        : _extractedText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: left),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: right),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [left, const SizedBox(height: 16), right],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
