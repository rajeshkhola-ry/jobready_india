import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../Services/file_picker_service.dart';
import '../Services/wasm_document_service.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Widgets/tool_workspace_shell.dart';

class MicroCanvaUtilitiesPage extends StatefulWidget {
  const MicroCanvaUtilitiesPage({super.key});

  @override
  State<MicroCanvaUtilitiesPage> createState() => _MicroCanvaUtilitiesPageState();
}

class _MicroCanvaUtilitiesPageState extends State<MicroCanvaUtilitiesPage> {
  PickedFileData? _selectedImage;
  bool _isProcessing = false;
  String _status = 'Select an image to start Micro-Canva utilities.';

  PassportBackgroundColor _passportBackground = PassportBackgroundColor.white;
  int _passportDpi = 300;
  double _upscaleFactor = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micro-Canva Utilities'),
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
                constraints: const BoxConstraints(maxWidth: 940),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToolWorkspaceShell(
                      title: 'Phase 3: Micro-Canva Utilities',
                      subtitle: 'Background remover, govt passport resizer, HD upscaling, and PNG to SVG conversion with local processing only.',
                      icon: Icons.auto_awesome_motion_rounded,
                      accentColor: const Color(0xFF0E3A66),
                      statusText: _status,
                      showProgress: _isProcessing,
                      progress: _isProcessing ? 0.65 : 0,
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isProcessing ? null : _pickImage,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Select Image'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedImage == null
                                  ? 'No file selected.'
                                  : '${_selectedImage!.name} (${_formatBytes(_selectedImage!.size)})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBackgroundRemoverSection(),
                    const SizedBox(height: 12),
                    _buildPassportSection(),
                    const SizedBox(height: 12),
                    _buildUpscaleVectorSection(),
                    const SizedBox(height: 18),
                    const ToolGuidancePanel(
                      title: 'Privacy Model',
                      summary: 'All image operations run on the client/browser. No external upload API is called by these actions.',
                      supportedFormats: ['JPG, PNG, WEBP, BMP as input', 'PNG/JPG/SVG as output'],
                      howToUse: [
                        'Select one image file.',
                        'Run the needed utility action.',
                        'Download starts immediately in browser.',
                      ],
                      faqs: [
                        'Is server upload required? No, these are local-only utilities.',
                        'Does ONNX hook need model file? Yes, a local/public model path is needed for best background removal.',
                      ],
                      tips: [
                        'Use clean background source photos for best removal quality.',
                        'Use 300 DPI for passport/visa workflows.',
                        'Use upscale first, then vector conversion for logos/icons.',
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

  Widget _buildBackgroundRemoverSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1) Instant Background Remover',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'ONNX WebGL hook is attempted first (if model path is available), then local fallback remover is used.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _removeBackground,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Remove Background (Client-Side)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2) AI Passport & Photo Resizer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Auto-crop + DPI sizing + background color presets for govt forms, visas, and passports.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PassportBackgroundColor>(
                  value: _passportBackground,
                  decoration: const InputDecoration(labelText: 'Background'),
                  items: const [
                    DropdownMenuItem(value: PassportBackgroundColor.white, child: Text('White')),
                    DropdownMenuItem(value: PassportBackgroundColor.blue, child: Text('Blue')),
                    DropdownMenuItem(value: PassportBackgroundColor.grey, child: Text('Grey')),
                  ],
                  onChanged: _isProcessing
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _passportBackground = value;
                          });
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _passportDpi,
                  decoration: const InputDecoration(labelText: 'DPI'),
                  items: const [
                    DropdownMenuItem(value: 300, child: Text('300 DPI')),
                    DropdownMenuItem(value: 600, child: Text('600 DPI')),
                    DropdownMenuItem(value: 150, child: Text('150 DPI')),
                  ],
                  onChanged: _isProcessing
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _passportDpi = value;
                          });
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _generatePassportImage,
              icon: const Icon(Icons.badge_rounded),
              label: const Text('Generate Govt Passport Photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpscaleVectorSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3) HD Upscaling & Vector Converter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sharpen + upscale utility and PNG to SVG conversion, fully local in browser.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Upscale factor',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Expanded(
                child: Slider(
                  value: _upscaleFactor,
                  min: 1,
                  max: 4,
                  divisions: 6,
                  label: '${_upscaleFactor.toStringAsFixed(1)}x',
                  onChanged: _isProcessing
                      ? null
                      : (value) {
                          setState(() {
                            _upscaleFactor = value;
                          });
                        },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _upscaleImage,
                  icon: const Icon(Icons.hd_rounded),
                  label: const Text('Upscale + Sharpen'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _convertToSvg,
                  icon: const Icon(Icons.polyline_rounded),
                  label: const Text('Convert PNG to SVG'),
                ),
              ),
            ],
          ),
        ],
      ),
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

  Future<void> _pickImage() async {
    final selected = await FilePickerService.pickFileData(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedImage = selected;
      _status = 'Image selected. Choose an action.';
    });
  }

  Future<void> _removeBackground() async {
    final input = _selectedImage;
    if (input == null) {
      _notify('Please select image first.');
      return;
    }

    await _runGuarded(() async {
      final output = await WasmDocumentService.removeImageBackgroundClientSide(
        imageBytes: input.bytes,
      );
      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_bg_removed', 'png'),
        mimeType: 'image/png',
      );
      setState(() {
        _status = 'Background removed locally. Download started.';
      });
    });
  }

  Future<void> _generatePassportImage() async {
    final input = _selectedImage;
    if (input == null) {
      _notify('Please select image first.');
      return;
    }

    await _runGuarded(() async {
      final output = await WasmDocumentService.buildGovtPassportPhoto(
        imageBytes: input.bytes,
        background: _passportBackground,
        dpi: _passportDpi,
      );
      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_passport_${_passportDpi}dpi', 'jpg'),
        mimeType: 'image/jpeg',
      );
      setState(() {
        _status = 'Passport photo generated with DPI/background presets. Download started.';
      });
    });
  }

  Future<void> _upscaleImage() async {
    final input = _selectedImage;
    if (input == null) {
      _notify('Please select image first.');
      return;
    }

    await _runGuarded(() async {
      final output = await WasmDocumentService.upscaleAndSharpenImage(
        imageBytes: input.bytes,
        scale: _upscaleFactor,
      );
      WasmDocumentService.triggerBrowserDownload(
        bytes: output,
        fileName: _withSuffix(input.name, '_upscaled_${_upscaleFactor.toStringAsFixed(1)}x', 'jpg'),
        mimeType: 'image/jpeg',
      );
      setState(() {
        _status = 'Upscaling complete. Download started.';
      });
    });
  }

  Future<void> _convertToSvg() async {
    final input = _selectedImage;
    if (input == null) {
      _notify('Please select image first.');
      return;
    }

    await _runGuarded(() async {
      final svg = await WasmDocumentService.convertPngToSimpleSvg(
        imageBytes: input.bytes,
      );
      WasmDocumentService.triggerBrowserDownload(
        bytes: Uint8List.fromList(utf8.encode(svg)),
        fileName: _withSuffix(input.name, '_vector', 'svg'),
        mimeType: 'image/svg+xml',
      );
      setState(() {
        _status = 'Vector conversion complete. Download started.';
      });
    });
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await action();
    } catch (error) {
      _notify('Failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _notify(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _withSuffix(String fileName, String suffix, String ext) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '${base}${suffix}.$ext';
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
}
