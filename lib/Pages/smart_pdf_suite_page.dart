import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../Services/file_picker_service.dart';
import '../Services/wasm_document_service.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/signature_pad_canvas.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Widgets/tool_workspace_shell.dart';

class SmartPdfSuitePage extends StatefulWidget {
  const SmartPdfSuitePage({super.key});

  @override
  State<SmartPdfSuitePage> createState() => _SmartPdfSuitePageState();
}

class _SmartPdfSuitePageState extends State<SmartPdfSuitePage> {
  final SignaturePadController _signatureController = SignaturePadController();
  final TextEditingController _pageSelectionController = TextEditingController(text: '1');
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _ownerPasswordController = TextEditingController();
  final TextEditingController _unlockPasswordController = TextEditingController();

  PickedFileData? _selectedPdf;
  PickedFileData? _uploadedSignature;
  bool _isBusy = false;
  String _statusMessage = 'Load a PDF to start Smart PDF Suite workflows.';
  String _ocrPreviewText = '';

  double _signLeft = 0.62;
  double _signTop = 0.82;
  double _signWidth = 0.28;
  double _signHeight = 0.1;

  @override
  void dispose() {
    _pageSelectionController.dispose();
    _userPasswordController.dispose();
    _ownerPasswordController.dispose();
    _unlockPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart PDF Suite'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
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
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToolWorkspaceShell(
                      title: 'Smart PDF Suite',
                      subtitle: 'E-Sign, smart compression, PDF lock/unlock, and OCR in browser-only local processing.',
                      icon: Icons.auto_fix_high_rounded,
                      accentColor: const Color(0xFF0E3A66),
                      statusText: _statusMessage,
                      showProgress: _isBusy,
                      progress: _isBusy ? nullSafeProgress(0.62) : 0,
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isBusy ? null : _pickPdf,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Select PDF'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isBusy ? null : _pickSignatureImage,
                              icon: const Icon(Icons.image_rounded),
                              label: const Text('Upload Signature'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedPdf != null)
                      _hint('PDF: ${_selectedPdf!.name} (${_formatBytes(_selectedPdf!.size)})'),
                    if (_uploadedSignature != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _hint('Signature image loaded: ${_uploadedSignature!.name}'),
                      ),
                    const SizedBox(height: 16),
                    _buildESignSection(),
                    const SizedBox(height: 14),
                    _buildCompressSection(),
                    const SizedBox(height: 14),
                    _buildProtectUnlockSection(),
                    const SizedBox(height: 14),
                    _buildOcrSection(),
                    const SizedBox(height: 20),
                    const ToolGuidancePanel(
                      title: 'How Smart PDF Suite Works',
                      summary: 'All actions run client-side in your browser. Files are not uploaded to external servers.',
                      supportedFormats: ['PDF for sign, compress, protect, unlock, and OCR workflows'],
                      howToUse: [
                        'Select one PDF.',
                        'Use the section matching your task.',
                        'Download starts immediately after processing.',
                      ],
                      faqs: [
                        'Is data uploaded? No, operations run locally in-browser.',
                        'Will OCR quality vary? Yes, based on scan quality and language complexity.',
                      ],
                      tips: [
                        'Use clean black signature strokes for best visibility.',
                        'For strong protection, set both user and owner passwords.',
                        'Run OCR on clear, high-contrast scans for better text output.',
                      ],
                    ),
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

  Widget _buildESignSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1) E-Sign & Fillable Signature Pad',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Draw your signature or upload a signature image, then burn it onto selected PDF pages.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          SignaturePadCanvas(controller: _signatureController),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () {
                        setState(() {
                          _signatureController.clear();
                        });
                      },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear Drawn Signature'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _pageSelectionController,
                  decoration: const InputDecoration(
                    labelText: 'Pages (example: 1,3-5)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRectSliders(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _applySignatureToPdf,
              icon: const Icon(Icons.border_color_rounded),
              label: const Text('Apply Signature To PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2) Smart PDF Compression',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adaptive local pipeline tries multiple passes to push size reduction up to about 80% when possible.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _runSmartCompression,
              icon: const Icon(Icons.compress_rounded),
              label: const Text('Compress Selected PDF (Local)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectUnlockSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3) PDF Protect & Unlock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _userPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'User password (required for protect)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ownerPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Owner password (optional)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _protectPdf,
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Protect PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _unlockPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Unlock password'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isBusy ? null : _unlockPdf,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4) PDF OCR (Scanned PDF to Searchable Text)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Runs local text extraction and browser-side OCR worker fallback for scanned pages.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _runPdfOcr,
                  icon: const Icon(Icons.text_snippet_rounded),
                  label: const Text('Run OCR Locally'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ocrPreviewText.trim().isEmpty ? null : _downloadOcrText,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download OCR Text'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6E3F3)),
            ),
            child: SingleChildScrollView(
              child: Text(
                _ocrPreviewText.trim().isEmpty ? 'OCR preview will appear here.' : _ocrPreviewText,
                style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF1F2937)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRectSliders() {
    return Column(
      children: [
        _sliderRow(
          label: 'Left',
          value: _signLeft,
          onChanged: (value) => setState(() => _signLeft = value),
        ),
        _sliderRow(
          label: 'Top',
          value: _signTop,
          onChanged: (value) => setState(() => _signTop = value),
        ),
        _sliderRow(
          label: 'Width',
          value: _signWidth,
          min: 0.08,
          max: 0.6,
          onChanged: (value) => setState(() => _signWidth = value),
        ),
        _sliderRow(
          label: 'Height',
          value: _signHeight,
          min: 0.05,
          max: 0.35,
          onChanged: (value) => setState(() => _signHeight = value),
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    double min = 0,
    double max = 1,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: _isBusy ? null : onChanged,
          ),
        ),
        SizedBox(
          width: 46,
          child: Text((value * 100).toStringAsFixed(0)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }

  Widget _hint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF166534)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534), fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final file = await FilePickerService.pickFileData(allowedExtensions: const ['pdf']);
    if (file == null) {
      return;
    }
    setState(() {
      _selectedPdf = file;
      _statusMessage = 'PDF selected. Choose a Smart PDF action.';
    });
  }

  Future<void> _pickSignatureImage() async {
    final file = await FilePickerService.pickFileData(allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp']);
    if (file == null) {
      return;
    }
    setState(() {
      _uploadedSignature = file;
      _statusMessage = 'Signature image loaded. Ready to burn into PDF.';
    });
  }

  Future<void> _applySignatureToPdf() async {
    final input = _selectedPdf;
    if (input == null) {
      _notify('Please select a PDF first.');
      return;
    }

    final pages = _parsePageSelection(_pageSelectionController.text);
    if (pages.isEmpty) {
      _notify('Please enter valid page numbers (example: 1,3-5).');
      return;
    }

    Uint8List signatureBytes;
    if (_uploadedSignature != null) {
      signatureBytes = _uploadedSignature!.bytes;
    } else if (_signatureController.hasSignature) {
      signatureBytes = await _signatureController.exportPng(width: 900, height: 320);
    } else {
      _notify('Draw or upload a signature first.');
      return;
    }

    await _guardedRun(() async {
      final output = await WasmDocumentService.burnSignatureToPdf(
        pdfBytes: input.bytes,
        signatureImageBytes: signatureBytes,
        pageNumbers: pages,
        leftRatio: _signLeft,
        topRatio: _signTop,
        widthRatio: _signWidth,
        heightRatio: _signHeight,
      );

      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_signed', 'pdf'),
        mimeType: 'application/pdf',
      );

      setState(() {
        _statusMessage = 'Signature applied successfully. Download started.';
      });
    });
  }

  Future<void> _runSmartCompression() async {
    final input = _selectedPdf;
    if (input == null) {
      _notify('Please select a PDF first.');
      return;
    }

    await _guardedRun(() async {
      final target = (input.size * 0.2).round();
      final output = await WasmDocumentService.compressPdfDocument(
        pdfBytes: input.bytes,
        targetBytes: target,
      );

      final reduced = input.size - output.length;
      final reduction = input.size == 0 ? 0 : (reduced / input.size) * 100;

      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_smart_compressed', 'pdf'),
        mimeType: 'application/pdf',
      );

      setState(() {
        _statusMessage = 'Compression done. Size: ${_formatBytes(input.size)} -> ${_formatBytes(output.length)} (${reduction.toStringAsFixed(1)}%).';
      });
    });
  }

  Future<void> _protectPdf() async {
    final input = _selectedPdf;
    if (input == null) {
      _notify('Please select a PDF first.');
      return;
    }

    final userPassword = _userPasswordController.text.trim();
    if (userPassword.isEmpty) {
      _notify('Please enter user password to protect PDF.');
      return;
    }

    await _guardedRun(() async {
      final output = await WasmDocumentService.protectPdfDocument(
        pdfBytes: input.bytes,
        userPassword: userPassword,
        ownerPassword: _ownerPasswordController.text.trim(),
      );

      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_protected', 'pdf'),
        mimeType: 'application/pdf',
      );

      setState(() {
        _statusMessage = 'PDF protection applied. Download started.';
      });
    });
  }

  Future<void> _unlockPdf() async {
    final input = _selectedPdf;
    if (input == null) {
      _notify('Please select a PDF first.');
      return;
    }

    final password = _unlockPasswordController.text;
    if (password.trim().isEmpty) {
      _notify('Please enter unlock password.');
      return;
    }

    await _guardedRun(() async {
      final output = await WasmDocumentService.unlockPdfDocument(
        pdfBytes: input.bytes,
        password: password,
      );

      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_unlocked', 'pdf'),
        mimeType: 'application/pdf',
      );

      setState(() {
        _statusMessage = 'PDF unlocked. Download started.';
      });
    });
  }

  Future<void> _runPdfOcr() async {
    final input = _selectedPdf;
    if (input == null) {
      _notify('Please select a PDF first.');
      return;
    }

    await _guardedRun(() async {
      final text = await WasmDocumentService.extractTextFromPdfLocally(pdfBytes: input.bytes);
      setState(() {
        _ocrPreviewText = text.trim().isEmpty
            ? 'No OCR text detected. Try a higher quality scan.'
            : text.trim();
        _statusMessage = 'OCR completed locally.';
      });
    });
  }

  void _downloadOcrText() {
    final input = _selectedPdf;
    if (input == null || _ocrPreviewText.trim().isEmpty) {
      return;
    }
    WasmDocumentService.triggerBrowserDownload(
      bytes: Uint8List.fromList(utf8.encode(_ocrPreviewText)),
      fileName: _withSuffix(input.name, '_ocr', 'txt'),
      mimeType: 'text/plain',
    );
  }

  List<int> _parsePageSelection(String value) {
    final output = <int>{};
    final chunks = value.split(',');
    for (final chunkRaw in chunks) {
      final chunk = chunkRaw.trim();
      if (chunk.isEmpty) {
        continue;
      }
      if (chunk.contains('-')) {
        final parts = chunk.split('-');
        if (parts.length != 2) {
          continue;
        }
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start == null || end == null) {
          continue;
        }
        final low = start < end ? start : end;
        final high = start < end ? end : start;
        for (var page = low; page <= high; page++) {
          if (page > 0) {
            output.add(page);
          }
        }
        continue;
      }
      final single = int.tryParse(chunk);
      if (single != null && single > 0) {
        output.add(single);
      }
    }
    return output.toList()..sort();
  }

  Future<void> _guardedRun(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } catch (error) {
      _notify('Failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _notify(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _withSuffix(String fileName, String suffix, String extension) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '${base}$suffix.$extension';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  double nullSafeProgress(double value) {
    if (!value.isFinite) {
      return 0.0;
    }
    if (value < 0) {
      return 0.0;
    }
    if (value > 1) {
      return 1.0;
    }
    return value;
  }
}
