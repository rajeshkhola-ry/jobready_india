import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../Widgets/apple_button.dart';
import '../Widgets/download_result_dialog.dart';
import '../Widgets/quota_gate.dart';
import '../Widgets/site_footer_link.dart';
import '../Services/conversion_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/upload_context_service.dart';

/// Convert Tool Page - File format conversion (PDF, Word, Excel, Images, etc.)
/// User selects input format → Output format → Converts
/// NO size picker (conversion only, not compression)
class ConvertToolPage extends StatefulWidget {
  const ConvertToolPage({super.key});

  @override
  State<ConvertToolPage> createState() => _ConvertToolPageState();
}

class _ConvertToolPageState extends State<ConvertToolPage> {
  String? _selectedInputFormat;
  String? _selectedOutputFormat;
  bool _isConverting = false;
  String _statusMessage = 'Select input format to start';

  List<PickedFileData> _selectedFiles = [];
  Uint8List? _selectedFile;
  String? _selectedFileName;
  final ConversionService _conversionService = const ConversionService();

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
    'Image': ['PDF (.pdf)', 'JPG Images', 'PNG Images', 'WebP (.webp)', 'PowerPoint (.pptx)'],
    'PowerPoint': ['PDF (.pdf)', 'Word (.docx)'],
  };

  static const Map<String, List<String>> inputExtensions = {
    'PDF': ['pdf'],
    'Word': ['doc', 'docx'],
    'Excel': ['xls', 'xlsx', 'csv'],
    'Image': ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    'PowerPoint': ['ppt', 'pptx'],
  };

  @override
  void initState() {
    super.initState();
    try {
      _hydrateFromHomeUpload();
    } catch (_) {
      _statusMessage = 'Select input format to start';
    }
  }

  void _hydrateFromHomeUpload() {
    if (kIsWeb) {
      // Skip eager file restoration on web; large cached files can crash first-frame rendering.
      return;
    }

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
    final outputChoices = inferredInput == null
        ? const <String>[]
        : (formatConversions[inferredInput] ?? const <String>[]);

    setState(() {
      _selectedFiles = cachedFiles;
      _selectedFile = cached.bytes;
      _selectedFileName = cached.name;
      _selectedInputFormat = inferredInput;
      _selectedOutputFormat = outputChoices.isNotEmpty ? outputChoices.first : null;
      _statusMessage = cachedFiles.length == 1
          ? '✓ File loaded from Home: ${cached.name}'
          : '✓ ${cachedFiles.length} file(s) loaded from Home upload';
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

  @override
  Widget build(BuildContext context) {
    final availableFormats = _selectedInputFormat == null
        ? const <String>[]
        : (formatConversions[_selectedInputFormat!] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh & Clear Files',
            onPressed: _isConverting ? null : _resetSelection,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFC72C)),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Color(0xFFFFC72C)),
          ),
        ],
        title: const Text(
          'Convert File',
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
          final isWide = constraints.maxWidth >= 760;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: safeWidth,
                minHeight: safeHeight,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.25)),
                      ),
                      child: const Text(
                        '1. Choose input format. 2. Choose output format. 3. Choose file and start convert. All steps stay on this page.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
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
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Conversion in progress... please wait.',
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
            ),
          );
        },
      ),
      bottomNavigationBar: const SiteFooterLink(),
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
                  'Choose File and Start Convert',
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
            canStartConvert
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
                      : 'Start Convert',
                  icon: Icons.auto_fix_high,
                  onPressed: (_isConverting || !canStartConvert || _selectedFileName == null)
                      ? null
                      : _convertSelectedFile,
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
            _statusMessage = 'Select output format to continue';
          } else {
            _selectedOutputFormat = format;
          }
        });
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
          child: Text(
            format,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
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

      if (files.isEmpty) {
        setState(() {
          _statusMessage = 'File selection cancelled';
        });
        return;
      }
      setState(() {
        _selectedFiles = files;
        _selectedFile = files.first.bytes;
        _selectedFileName = files.first.name;
        _statusMessage = files.length == 1
          ? 'File selected. Tap Convert Now to continue.'
          : '${files.length} files selected. Tap Convert All to continue.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _convertSelectedFile() async {
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
            content: Text('Batch conversion completed. Download now.'),
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
          _statusMessage = '✗ ${result.message}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isConverting = false;
          _statusMessage = '✓ Converted successfully. Download available.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File converted successfully. Download now.'),
          backgroundColor: Colors.green,
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: _selectedOutputFormat!,
          fileName: result.outputFileName!,
          outputBytes: result.outputBytes!,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConverting = false;
        _statusMessage = '✗ Error: $e';
      });
    }
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Converting')) return Colors.blue;
    return Colors.grey;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
