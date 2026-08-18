import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../Widgets/download_result_dialog.dart';
import '../Widgets/apple_button.dart';
import '../Widgets/advanced_conversion_result_dialog.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/quota_gate.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Widgets/tool_workspace_shell.dart';
import '../Services/conversion_service.dart';
import '../Services/document_history_service.dart';
import '../Services/error_message_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/ocr_quota_service.dart';
import '../Services/upload_context_service.dart';
import '../Services/usage_quota_service.dart';
import '../Services/voice_command_service.dart';
import '../Services/wasm_document_service.dart';
import 'compression_tool_page.dart';

/// Convert Tool Page - File format conversion (PDF, Word, Excel, Images, etc.)
/// User selects input format → Output format → Converts
/// NO size picker (conversion only, not compression)
class ConvertToolPage extends StatefulWidget {
  final String? initialInputFormat;
  final String? initialOutputFormat;

  const ConvertToolPage({super.key, this.initialInputFormat, this.initialOutputFormat});

  @override
  State<ConvertToolPage> createState() => _ConvertToolPageState();
}

class _ConvertToolPageState extends State<ConvertToolPage> {
  String? _selectedInputFormat;
  String? _selectedOutputFormat;
  bool _isConverting = false;
  String _statusMessage = 'Select input, output, and file to convert';
  bool _showIntentPopup = false;
  String? _pendingIntentFormat;
  Set<String> _selectedIntentActions = <String>{};
  List<PickedFileData> _selectedFiles = [];
  Uint8List? _selectedFile;
  String? _selectedFileName;
  final ConversionService _conversionService = const ConversionService();

  // Dynamic stepped loader shown while _isConverting is true - simulates
  // processing progress (no real granular server progress events exist for
  // a single HTTP request/response conversion call).
  Timer? _conversionStepTimer;
  int _conversionStepIndex = 0;
  static const List<String> _ocrConversionSteps = <String>[
    'Uploading file...',
    'Analyzing text with AI OCR...',
    'Generating editable Word document...',
  ];
  static const List<String> _genericConversionSteps = <String>[
    'Uploading file...',
    'Processing your file...',
    'Preparing your download...',
  ];

  List<String> get _activeConversionSteps {
    final isPdfToWord = (_selectedInputFormat ?? '').toUpperCase() == 'PDF' &&
        (_selectedOutputFormat ?? '').toLowerCase().contains('word');
    return isPdfToWord ? _ocrConversionSteps : _genericConversionSteps;
  }

  void _startConversionStepTimer() {
    _conversionStepIndex = 0;
    _conversionStepTimer?.cancel();
    _conversionStepTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted || !_isConverting) {
        timer.cancel();
        return;
      }
      final steps = _activeConversionSteps;
      if (_conversionStepIndex < steps.length - 1) {
        setState(() => _conversionStepIndex++);
      }
    });
  }

  @override
  void dispose() {
    _conversionStepTimer?.cancel();
    super.dispose();
  }

  // Available format conversions
  static const Map<String, List<String>> formatConversions = {
    'PDF': [
      'Word (.docx)',
      'Text (.txt)',
      'Compress PDF',
      'JPG Images',
      'PNG Images',
    ],
    'Word': ['PDF (.pdf)', 'Text (.txt)', 'PowerPoint (.pptx)'],
    'Excel': ['PDF (.pdf)', 'CSV (.csv)', 'PowerPoint (.pptx)'],
    'CSV': ['Excel (.xlsx)', 'PDF (.pdf)', 'JSON (.json)'],
    'Image': ['PDF (.pdf)', 'JPG Images', 'PNG Images', 'WebP (.webp)', 'PowerPoint (.pptx)'],
    'PowerPoint': ['PDF (.pdf)', 'Word (.docx)'],
  };

  static const Map<String, List<String>> inputExtensions = {
    'PDF': ['pdf'],
    'Word': ['doc', 'docx'],
    'Excel': ['xls', 'xlsx'],
    'CSV': ['csv'],
    'Image': ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    'PowerPoint': ['ppt', 'pptx'],
  };

  // Maps a Gemini-classified voice tool to the specific input/output format
  // pair it implies, so the correct destination format is auto-selected
  // instead of just the first default choice for the uploaded file's type.
  static const Map<String, String> _voiceToolInputFormat = {
    'pdf_to_word': 'PDF',
    'word_to_pdf': 'Word',
    'jpg_to_pdf': 'Image',
    'pdf_to_jpg': 'PDF',
  };

  static const Map<String, String> _voiceToolOutputFormat = {
    'pdf_to_word': 'Word (.docx)',
    'word_to_pdf': 'PDF (.pdf)',
    'jpg_to_pdf': 'PDF (.pdf)',
    'pdf_to_jpg': 'JPG Images',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialInputFormat != null) {
      _selectedInputFormat = widget.initialInputFormat;
      final defaultOutputs = formatConversions[widget.initialInputFormat!] ?? const <String>[];
      _selectedOutputFormat = widget.initialOutputFormat ?? (defaultOutputs.isNotEmpty ? defaultOutputs.first : null);
    }
    _hydrateFromHomeUpload();
    _applyConverterSeoMetadata();
    _applyVoiceCommand();
  }

  void _applyVoiceCommand() {
    final params = VoiceCommandService.consumePendingParameters();
    if (params.isEmpty) {
      return;
    }
    final voiceTool = params[VoiceCommandService.voiceToolKey]?.toString() ?? '';
    final requestedInput = _voiceToolInputFormat[voiceTool];
    final requestedOutput = _voiceToolOutputFormat[voiceTool];
    if (requestedOutput != null && _selectedInputFormat == requestedInput) {
      setState(() {
        _selectedOutputFormat = requestedOutput;
      });
    }
    final autoExecute = params[VoiceCommandService.autoExecuteFlagKey] == true;
    if (autoExecute && _selectedFile != null && _selectedInputFormat != null && _selectedOutputFormat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _convertSelectedFile(autoExecute: true));
    }
  }

  void _hydrateFromHomeUpload() {
    final supportedExtensions = inputExtensions.values.expand((items) => items).toSet().toList();
    var cachedFiles = UploadContextService.getCompatibleFiles(supportedExtensions);

    // If no files in UploadContextService, check FileStorageService
    if (cachedFiles.isEmpty) {
      final storedFile = FileStorageService.getLatestFile();
      if (storedFile != null && _isSupportedFormat(storedFile.name, supportedExtensions)) {
        cachedFiles = [PickedFileData(
          name: storedFile.name,
          size: storedFile.sizeBytes,
          bytes: storedFile.getBytes(),
        )];
      }
    }

    if (cachedFiles.isEmpty) {
      return;
    }

    final cached = cachedFiles.first;

    final inferredInput = _inferInputFormat(cached.name);
    final inputExtensionsForFormat = inferredInput == null
        ? const <String>[]
        : (inputExtensions[inferredInput] ?? const <String>[]);
    // Only attach files matching the auto-selected input tab, so a mixed
    // Home upload (e.g. a PDF alongside an image) never leaves the page in
    // an inconsistent "tab selected, mismatched files attached" state.
    final matchingFiles = inputExtensionsForFormat.isEmpty
        ? cachedFiles
        : cachedFiles.where((file) => _isSupportedFormat(file.name, inputExtensionsForFormat)).toList();
    final filesToAttach = matchingFiles.isNotEmpty ? matchingFiles : cachedFiles;
    final outputChoices = inferredInput == null
        ? const <String>[]
        : (formatConversions[inferredInput] ?? const <String>[]);

    setState(() {
      _selectedFiles = filesToAttach;
      _selectedFile = cached.bytes;
      _selectedFileName = cached.name;
      _selectedInputFormat = inferredInput;
      _selectedOutputFormat = outputChoices.isNotEmpty ? outputChoices.first : null;
      _statusMessage = filesToAttach.length == 1
          ? '✓ File loaded from Home: ${cached.name}'
          : '✓ ${filesToAttach.length} file(s) loaded from Home upload';
    });
  }

  bool _isSupportedFormat(String fileName, List<String> supportedExtensions) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) return false;
    final ext = parts.last;
    return supportedExtensions.contains(ext);
  }

  String? _inferInputFormat(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) {
      return null;
    }

    final ext = parts.last;
    for (final entry in inputExtensions.entries) {
      if (entry.value.contains(ext)) {
        return entry.key;
      }
    }
    return null;
  }

  bool _isConversionSupported(String? input, String? output) {
    if (input == null || output == null) {
      return false;
    }

    return true;
  }

  bool _isCompressPdfFlow() {
    return _selectedInputFormat == 'PDF' && _selectedOutputFormat == 'Compress PDF';
  }

  String _inferMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'application/octet-stream';
  }

  Future<void> _openCompressToolWithContext() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _statusMessage = 'Select at least one PDF file first, then open compression settings.';
      });
      return;
    }

    UploadContextService.setUploadedFiles(_selectedFiles);
    for (final file in _selectedFiles) {
      await FileStorageService.storeFile(
        name: file.name,
        bytes: file.bytes,
        mimeType: _inferMimeType(file.name),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Opening Compress Tool with loaded file context...';
    });

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CompressionToolPage()),
    );
  }

  void _applyConverterSeoMetadata() {
    final document = html.document;
    final head = document.head;
    if (head == null) {
      return;
    }

    const title = 'Free AI Resume Converter & ATS Formatter India | PDF to Word & ATS Scan';
    const description = 'Convert resume PDF to Word, extract ATS text, and format bio-data instantly. 100% Free & Secure Online Resume Converter for Indian Job Seekers.';
    const keywords = 'resume converter India, PDF to Word India, ATS formatter, ATS scan, bio-data converter, free online resume converter';
    const url = 'https://getreadyjob.com/convert';

    document.title = title;
    _upsertMetaTag(name: 'description', content: description);
    _upsertMetaTag(name: 'keywords', content: keywords);
    _upsertMetaTag(property: 'og:title', content: title);
    _upsertMetaTag(property: 'og:description', content: description);
    _upsertMetaTag(property: 'og:url', content: url);
    _upsertMetaTag(name: 'twitter:title', content: title);
    _upsertMetaTag(name: 'twitter:description', content: description);

    _upsertLinkTag(rel: 'canonical', href: url);
    _upsertLinkTag(rel: 'alternate', href: url, hreflang: 'x-default');
    _upsertLinkTag(rel: 'alternate', href: 'https://getreadyjob.com/en-in/convert', hreflang: 'en-in');

    _upsertJsonLdScript(
      json: {
        '@context': 'https://schema.org',
        '@type': 'WebApplication',
        'name': 'Free AI Resume Converter & ATS Formatter India',
        'url': url,
        'applicationCategory': 'BusinessApplication',
        'operatingSystem': 'Web',
        'description': description,
        'areaServed': {
          '@type': 'Country',
          'name': 'India',
        },
        'audience': {
          '@type': 'Audience',
          'audienceType': 'Indian job seekers and professionals',
        },
        'offers': {
          '@type': 'Offer',
          'price': '0',
          'priceCurrency': 'USD',
        },
      },
    );
  }

  void _upsertMetaTag({String? name, String? property, required String content}) {
    final selector = name != null
        ? 'meta[name="$name"]'
        : 'meta[property="$property"]';
    final existing = html.document.querySelector(selector);
    if (existing != null) {
      existing.setAttribute('content', content);
      return;
    }

    final meta = html.MetaElement();
    if (name != null) {
      meta.setAttribute('name', name);
    }
    if (property != null) {
      meta.setAttribute('property', property);
    }
    meta.setAttribute('content', content);
    html.document.head!.append(meta);
  }

  void _upsertLinkTag({required String rel, required String href, String? hreflang}) {
    final selector = hreflang != null
        ? 'link[rel="$rel"][hreflang="$hreflang"]'
        : 'link[rel="$rel"]';
    final existing = html.document.querySelector(selector);
    if (existing != null) {
      existing.setAttribute('href', href);
      return;
    }

    final link = html.LinkElement()
      ..setAttribute('rel', rel)
      ..setAttribute('href', href);
    if (hreflang != null) {
      link.setAttribute('hreflang', hreflang);
    }
    html.document.head!.append(link);
  }

  void _upsertJsonLdScript({required Map<String, dynamic> json}) {
    final existing = html.document.querySelector('script[data-seo-converter="true"]');
    existing?.remove();

    final script = html.ScriptElement();
    script.type = 'application/ld+json';
    script.setAttribute('data-seo-converter', 'true');
    script.text = jsonEncode(json);
    html.document.head!.append(script);
  }

  @override
  Widget build(BuildContext context) {
    final availableFormats = _selectedInputFormat == null
        ? const <String>[]
        : (formatConversions[_selectedInputFormat!] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 0.2,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh & Clear Files',
            onPressed: _isConverting ? null : _resetSelection,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Colors.white),
          ),
        ],
        title: const Text('Convert File'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ToolWorkspaceShell(
                      title: 'Convert File',
                      subtitle: 'Convert PDFs, Word documents, spreadsheets, and images into the output format you need.',
                      icon: Icons.swap_horiz_rounded,
                      accentColor: const Color(0xFF1F4E79),
                      statusText: _statusMessage,
                      showProgress: _isConverting,
                      progress: 0.7,
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildToolPanel(
                              step: 1,
                              title: 'Input Format',
                              subtitle: 'Choose the file type you have',
                              child: _buildFormatGrid(
                                formats: formatConversions.keys.toList(),
                                isInput: true,
                                crossAxisCount: 2,
                                childAspectRatio: 2.8,
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            child: Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC72C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildToolPanel(
                              step: 2,
                              title: 'Output Format',
                              subtitle: 'Choose what you want to create',
                              child: _buildFormatGrid(
                                formats: availableFormats,
                                isInput: false,
                                crossAxisCount: 2,
                                childAspectRatio: 2.8,
                              ),
                              footer: _selectedInputFormat == null
                                  ? 'Choose an input format first'
                                  : 'Target: ${_selectedInputFormat!} → ${_selectedOutputFormat ?? 'not selected'}',
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildToolPanel(
                            step: 1,
                            title: 'Input Format',
                            subtitle: 'Choose the file type you have',
                            child: _buildFormatGrid(
                              formats: formatConversions.keys.toList(),
                              isInput: true,
                              crossAxisCount: 3,
                              childAspectRatio: 2.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 14,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Container(
                              width: double.infinity,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC72C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildToolPanel(
                            step: 2,
                            title: 'Output Format',
                            subtitle: 'Choose what you want to create',
                            child: _buildFormatGrid(
                              formats: availableFormats,
                              isInput: false,
                              crossAxisCount: 3,
                              childAspectRatio: 2.2,
                            ),
                            footer: _selectedInputFormat == null
                                ? 'Choose an input format first'
                                : 'Target: ${_selectedInputFormat!} → ${_selectedOutputFormat ?? 'not selected'}',
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    _buildUploadPanel(),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _getStatusColor().withOpacity(0.4)),
                      ),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                    if ((_selectedInputFormat ?? '').toUpperCase().contains('PDF')) ...[
                      const SizedBox(height: 10),
                      _buildOcrQuotaBanner(),
                    ],
                    if (_isConverting) ...[
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
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _activeConversionSteps[
                                    _conversionStepIndex.clamp(0, _activeConversionSteps.length - 1)],
                                style: const TextStyle(
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
                    if (_showIntentPopup) ...[
                      const SizedBox(height: 16),
                      _buildIntentPopup(),
                    ],
                    const SizedBox(height: 16),
                    const ToolGuidancePanel(
                      title: 'About Convert File',
                      summary: 'Use this tool to move between document and image workflows from one guided page.',
                      supportedFormats: ['PDF', 'DOCX', 'TXT', 'CSV', 'XLSX', 'JPG', 'PNG', 'WEBP', 'PPTX'],
                      howToUse: ['Choose your input format.', 'Choose the output format you want.', 'Upload the file and start conversion.'],
                      faqs: ['Will layout always stay identical? Some formats vary.', 'What if a legacy file fails? Resave older files in newer formats first.'],
                      tips: ['Use DOCX instead of DOC when possible.', 'Use XLSX instead of XLS when possible.', 'Review converted files before final use.'],
                    ),
                    const SizedBox(height: 16),
                    const ProductionFooter(compact: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolPanel({
    required int step,
    required String title,
    required String subtitle,
    required Widget child,
    String? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
          const SizedBox(height: 12),
          child,
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntentPopup() {
    if (_selectedFiles.isEmpty || _pendingIntentFormat == null) {
      return const SizedBox.shrink();
    }

    final supportedActions = _getActionsForFormat(_pendingIntentFormat!);
    final selectionLabel = _selectedFiles.length == 1
        ? '1 file queued'
        : '${_selectedFiles.length} files queued';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E4F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: Color(0xFF1F4E79)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Advanced Intent & Processing',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$selectionLabel • Choose the best action for each file type.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          ..._selectedFiles.map((file) => _buildIntentFileCard(file)).toList(),
          const SizedBox(height: 12),
          Text(
            'Available actions for ${_pendingIntentFormat!}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F4E79)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: supportedActions.map((action) {
              final selected = _selectedIntentActions.contains(action);
              return FilterChip(
                label: Text(action),
                selected: selected,
                selectedColor: const Color(0xFFFFC72C).withOpacity(0.24),
                checkmarkColor: const Color(0xFF1F4E79),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedIntentActions.add(action);
                    } else {
                      _selectedIntentActions.remove(action);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedIntentActions.isEmpty ? null : () async {
                    await _executeIntentConversion();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Convert Selected Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showIntentPopup = false;
                    _selectedIntentActions = <String>{};
                  });
                },
                child: const Text('Continue'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'If you want to do manually, select Continue.',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentFileCard(PickedFileData file) {
    final formatLabel = _getDisplayFormat(file.name);
    final sizeLabel = _formatBytes(file.size);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF1F4E79)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$formatLabel • $sizeLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getActionsForFormat(String format) {
    switch (format) {
      case 'PDF':
        return [
          'PDF to Word',
          'Edit PDF',
          'Compress PDF',
          'Split PDF',
          'Merge PDF',
          'Extract Text',
          'OCR PDF',
        ];
      case 'Excel':
        return [
          'Excel to PDF',
          'Excel to CSV',
          'Excel to JSON',
          'Clean Data',
        ];
      case 'CSV':
        return [
          'CSV to Excel',
          'CSV to PDF',
          'CSV to JSON',
        ];
      case 'Word':
        return [
          'Word to PDF',
          'Word to Text',
          'Word to PowerPoint',
        ];
      case 'Image':
        return [
          'Image to PDF',
          'Image to JPG',
          'Image to PNG',
          'Image to WebP',
        ];
      case 'PowerPoint':
        return [
          'PPT to PDF',
          'PPT to Word',
        ];
      default:
        return [
          'Convert to PDF',
          'Convert to Text',
        ];
    }
  }

  String _getDisplayFormat(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'csv':
        return 'CSV';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'bmp':
        return 'Image';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      default:
        return 'File';
    }
  }

  Future<void> _executeIntentConversion() async {
    if (_selectedIntentActions.isEmpty || _selectedFiles.isEmpty) {
      return;
    }

    final chosenAction = _selectedIntentActions.first;
    String outputFormat = _selectedOutputFormat ?? 'PDF (.pdf)';
    if (chosenAction == 'CSV to Excel') {
      outputFormat = 'Excel (.xlsx)';
    } else if (chosenAction == 'CSV to JSON') {
      outputFormat = 'JSON (.json)';
    } else if (chosenAction == 'CSV to PDF') {
      outputFormat = 'PDF (.pdf)';
    } else if (chosenAction.contains('Word')) {
      outputFormat = 'Word (.docx)';
    } else if (chosenAction.contains('Text')) {
      outputFormat = 'Text (.txt)';
    } else if (chosenAction.contains('CSV')) {
      outputFormat = 'CSV (.csv)';
    } else if (chosenAction.contains('JSON')) {
      outputFormat = 'Text (.txt)';
    } else if (chosenAction.contains('PDF')) {
      outputFormat = 'PDF (.pdf)';
    }

    setState(() {
      _showIntentPopup = false;
      _isConverting = true;
      _selectedOutputFormat = outputFormat;
      _statusMessage = 'Preparing selected files for conversion...';
    });
    _startConversionStepTimer();

    final artifacts = <ConversionArtifact>[];
    final failureMessages = <String>[];
    var hasScannedPdfFailure = false;
    try {
      for (final file in _selectedFiles) {
        final result = await _conversionService.convert(
          inputBytes: file.bytes,
          inputFileName: file.name,
          outputFormat: outputFormat,
        );
        if (!result.success || result.outputBytes == null || result.outputFileName == null) {
          failureMessages.add('${file.name}: ${result.message}');
          if (result.isScannedPdf) {
            hasScannedPdfFailure = true;
          }
          continue;
        }
        artifacts.add(
          ConversionArtifact(
            sourceFileName: file.name,
            outputFormat: outputFormat,
            fileName: result.outputFileName!,
            outputBytes: Uint8List.fromList(result.outputBytes!.toList()),
            message: result.message,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = artifacts.isEmpty
            ? '${hasScannedPdfFailure ? '⚠' : '✗'} ${failureMessages.isNotEmpty ? failureMessages.first : 'No files were converted successfully.'}'
            : 'Conversion completed.';
      });

      if (artifacts.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (_) => AdvancedConversionResultDialog(artifacts: artifacts),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = '✗ ${ErrorMessageService.friendly(e, context: 'Batch conversion')}';
      });
    }
  }

  Widget _buildUploadPanel() {
    final canPickFile = _selectedInputFormat != null;
    final canStartConvert =
        _selectedInputFormat != null && _selectedOutputFormat != null;
    final selectedExtensions = _selectedInputFormat == null
        ? const <String>[]
        : (inputExtensions[_selectedInputFormat!] ?? const <String>[]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Choose File and Continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isCompressPdfFlow()
              ? (_selectedFileName == null
                ? 'Choose your PDF file, then open dedicated compression settings (target size + engine mode).'
                : 'Ready for compression. Open Compress Tool to set target KB and compression engine.')
              : canStartConvert
                ? 'Pick a file that matches your input format, then convert it right here.'
                : (canPickFile
                    ? 'Choose output format to enable Start Convert.'
                    : 'Choose input format first.'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedFileName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFiles.length > 1
                        ? 'Selected files: ${_selectedFiles.length}'
                        : 'Selected file: $_selectedFileName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._selectedFiles.take(4).map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${file.name} • ${_formatBytes(file.size)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isConverting ? null : () => _removeSelectedFile(file),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: _isConverting ? Colors.grey : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedFiles.length > 4)
                      Text(
                        '+${_selectedFiles.length - 4} more file(s)',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isConverting ? null : _clearSelectedFiles,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_selectedFileName != null) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppleButton(
                  label: _isConverting ? 'Converting...' : (_selectedFiles.length > 1 ? 'Choose Files' : 'Choose File'),
                  icon: _isConverting ? Icons.hourglass_empty : Icons.upload_file,
                  onPressed: (_isConverting || !canPickFile) ? null : _pickFileAndConvert,
                  isPrimary: _selectedFileName == null,
                  isFullWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppleButton(
                  label: _isConverting
                    ? 'Working...'
                    : (_isCompressPdfFlow() ? 'Open Compress Settings' : 'Start Convert'),
                  icon: _isCompressPdfFlow() ? Icons.tune_rounded : Icons.auto_fix_high,
                  onPressed: (_isConverting || !canStartConvert || _selectedFileName == null)
                      ? null
                    : (_isCompressPdfFlow() ? _openCompressToolWithContext : _convertSelectedFile),
                  isPrimary: _selectedFileName != null,
                  isFullWidth: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selectedExtensions.isEmpty
                ? 'Supported: choose input format first'
                : 'Supported: ${selectedExtensions.map((item) => '.${item.toUpperCase()}').join(', ')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _supportedOutputHint(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatGrid({
    required List<String> formats,
    required bool isInput,
    int crossAxisCount = 3,
    double childAspectRatio = 1.6,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: childAspectRatio,
      children: formats
          .map(
            (format) => _buildFormatButton(
              format: format,
              isInput: isInput,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFormatButton({
    required String format,
    required bool isInput,
  }) {
    final displayFormat = format
        .replaceAll(RegExp(r'\n\s*ready\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+ready\s*$', caseSensitive: false), '')
        .trim();

    final bool isSupportedOutput = !isInput
        ? _isConversionSupported(_selectedInputFormat, format)
        : true;

    final isSelected = isInput
        ? _selectedInputFormat == format
        : _selectedOutputFormat == format;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isInput) {
            _selectedInputFormat = format;
            _selectedOutputFormat = null;
            _selectedFiles = [];
            _selectedFile = null;
            _selectedFileName = null;
            _statusMessage = 'Choose output format to continue';
          } else {
            _selectedOutputFormat = format;
            if (format == 'Compress PDF') {
              _statusMessage = _selectedFiles.isEmpty
                  ? 'Compress PDF selected. Choose file and open compression settings.'
                  : 'Compress PDF selected. Open compression settings to set target KB and engine mode.';
            }
          }
        });

        if (!isInput && format == 'Compress PDF' && _selectedFiles.isNotEmpty) {
          Future<void>.microtask(_openCompressToolWithContext);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayFormat,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              if (!isInput && !isSupportedOutput) const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  String _supportedOutputHint() {
    if (_selectedInputFormat == null) {
      return 'All listed conversions are active. Best layout fidelity is currently on PDF-based conversions.';
    }

    final candidates = formatConversions[_selectedInputFormat!] ?? const <String>[];
    final supported = candidates
        .where((output) => _isConversionSupported(_selectedInputFormat, output))
        .toList(growable: false);

    return 'Available now: ${_selectedInputFormat!} -> ${supported.join(', ')}. Formatting can vary by source type.';
  }

  void _removeSelectedFile(PickedFileData file) {
    final updated = _selectedFiles.where((item) => item != file).toList(growable: false);

    setState(() {
      _selectedFiles = updated;
      if (_selectedFiles.isEmpty) {
        _selectedFile = null;
        _selectedFileName = null;
        _statusMessage = 'All selected files were removed. Choose files again.';
        return;
      }

      _selectedFile = _selectedFiles.first.bytes;
      _selectedFileName = _selectedFiles.first.name;
      _statusMessage = '${_selectedFiles.length} file(s) remain selected.';
    });
  }

  void _clearSelectedFiles() {
    setState(() {
      _selectedFiles = [];
      _selectedFile = null;
      _selectedFileName = null;
      _statusMessage = 'Selection cleared. Choose files again.';
    });
  }

  void _resetSelection() {
    UploadContextService.clearUploadedFiles();
    setState(() {
      _selectedFiles = [];
      _selectedFile = null;
      _selectedFileName = null;
      _selectedInputFormat = null;
      _selectedOutputFormat = null;
      _statusMessage = 'Refreshed. All selected files were cleared.';
    });
  }

  void _startConversion() {
    if (_selectedInputFormat == null || _selectedOutputFormat == null) return;

    _pickFileAndConvert();
  }

  Future<void> _pickFileAndConvert() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: inputExtensions[_selectedInputFormat!] ?? [],
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
      final effectiveInput = _selectedInputFormat;
      final shouldOpenCompressionSettings =
          effectiveInput == 'PDF' && _selectedOutputFormat == 'Compress PDF';

      if (effectiveInput != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles = files;
          _selectedFile = files.first.bytes;
          _selectedFileName = files.first.name;
          _statusMessage = shouldOpenCompressionSettings
              ? (files.length == 1
                  ? 'PDF selected. Open Compress Settings to continue.'
                  : '${files.length} PDFs selected. Open Compress Settings to continue.')
              : (files.length == 1
                  ? 'File selected. Review the next steps below.'
                  : '${files.length} files selected. Review the next steps below.');
          _showIntentPopup = !shouldOpenCompressionSettings;
          _pendingIntentFormat = shouldOpenCompressionSettings ? null : effectiveInput;
          _selectedIntentActions = <String>{};
        });

        if (shouldOpenCompressionSettings) {
          await _openCompressToolWithContext();
          return;
        }
      } else {
        setState(() {
          _selectedFiles = files;
          _selectedFile = files.first.bytes;
          _selectedFileName = files.first.name;
          _statusMessage = files.length == 1
              ? 'File selected. Tap Start Convert to continue.'
              : '${files.length} files selected. Tap Start Convert to continue.';
        });
      }
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

  Future<void> _convertSelectedFile({bool autoExecute = false}) async {
    if (_isCompressPdfFlow()) {
      await _openCompressToolWithContext();
      return;
    }

    if (_selectedFile == null || _selectedFileName == null || _selectedFiles.isEmpty) {
      setState(() {
        _statusMessage = 'Please choose a file first.';
      });
      return;
    }

    if (!_isConversionSupported(_selectedInputFormat, _selectedOutputFormat)) {
      setState(() {
        _statusMessage = 'This conversion is listed for roadmap and will be enabled soon.';
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
      _statusMessage = _selectedFiles.length > 1
          ? 'Converting ${_selectedFiles.length} files to $_selectedOutputFormat...'
          : 'Converting $_selectedFileName to $_selectedOutputFormat...';
    });
    _startConversionStepTimer();

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final isCombinedImageToPdf =
          _selectedFiles.length > 1 &&
          _selectedInputFormat == 'Image' &&
          _selectedOutputFormat == 'PDF (.pdf)';

      if (isCombinedImageToPdf) {
        final combinedPdf = await _conversionService.createPdfFromImages(
          imageBytesList: _selectedFiles.map((file) => file.bytes).toList(growable: false),
          imageNames: _selectedFiles.map((file) => file.name).toList(growable: false),
        );

        if (!mounted) return;

        final outputName = 'jobready_images_combined.pdf';
        setState(() {
          _isConverting = false;
          _statusMessage = '✓ ${_selectedFiles.length} images merged into one PDF successfully.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Combined PDF generated. Download now.'),
            backgroundColor: Colors.green,
          ),
        );

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: 'PDF (.pdf)',
            fileName: outputName,
            outputBytes: combinedPdf,
          ),
        );
        return;
      }

      if (_selectedFiles.length > 1) {
        final archive = Archive();
        for (final file in _selectedFiles) {
          final result = await _conversionService.convert(
            inputBytes: file.bytes,
            inputFileName: file.name,
            outputFormat: _selectedOutputFormat!,
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
          throw Exception('Unable to create ZIP output.');
        }

        if (!mounted) return;

        setState(() {
          _isConverting = false;
          _statusMessage = '✓ ${_selectedFiles.length} files converted successfully.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch conversion completed. Download is available.'),
            backgroundColor: Colors.green,
          ),
        );

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: '${_selectedOutputFormat!} Batch',
            fileName: 'jobready_converted_files.zip',
            outputBytes: Uint8List.fromList(zipBytes),
          ),
        );
        return;
      }

      final result = await _conversionService.convert(
        inputBytes: _selectedFile!,
        inputFileName: _selectedFileName!,
        outputFormat: _selectedOutputFormat!,
      );

      if (!mounted) return;

      if (!result.success || result.outputBytes == null || result.outputFileName == null) {
        setState(() {
          _isConverting = false;
          _statusMessage = result.isScannedPdf ? '⚠ ${result.message}' : '✗ ${result.message}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.isScannedPdf ? Colors.orange : Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isConverting = false;
        _statusMessage = '✓ Converted successfully. Download is available.';
      });

      if (autoExecute) {
        WasmDocumentService.triggerBrowserDownload(
          bytes: Uint8List.fromList(result.outputBytes!.toList()),
          fileName: result.outputFileName!,
          mimeType: _inferMimeType(result.outputFileName!),
        );
        DocumentHistoryService.addEntry(
          fileName: result.outputFileName!,
          outputFormat: _selectedOutputFormat!,
          fileSizeBytes: result.outputBytes!.length,
        );
        UsageQuotaService.recordAction(_selectedOutputFormat!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice command complete. File converted and downloaded automatically.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File completed. Download is available.'),
          backgroundColor: Colors.green,
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: _selectedOutputFormat!,
          fileName: result.outputFileName!,
          outputBytes: Uint8List.fromList(result.outputBytes!.toList()),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorDetail = ErrorMessageService.friendly(e, context: 'Conversion');

      setState(() {
        _isConverting = false;
        _statusMessage = '✗ $errorDetail';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorDetail),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('⚠')) return Colors.orange;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Converting')) return Colors.blue;
    return Colors.grey;
  }

  /// Combined AI OCR quota indicator (shared across Scanned PDF -> Word and
  /// the PDF to PDF OCR Tool) - shown whenever a PDF input is selected here,
  /// since that's when the scanned-PDF OCR fallback could be used.
  Widget _buildOcrQuotaBanner() {
    final isFree = OcrQuotaService.isFreePlan;
    final color = isFree ? Colors.orange : Colors.blueGrey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  OcrQuotaService.remainingLabel(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          if (isFree) ...[
            const SizedBox(height: 4),
            const Text(
              'AI OCR is available on 7-Day, Monthly, and Lifetime plans.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
