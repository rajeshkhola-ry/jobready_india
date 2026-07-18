import 'package:flutter/material.dart';

import '../../../Services/file_picker_service.dart';
import '../../../Services/photo_resize_service.dart';
import '../../../Services/upload_context_service.dart';
import '../../../Widgets/download_result_dialog.dart';

class PhotoHdWorkspacePage extends StatefulWidget {
  const PhotoHdWorkspacePage({super.key});

  @override
  State<PhotoHdWorkspacePage> createState() => _PhotoHdWorkspacePageState();
}

class _PhotoHdWorkspacePageState extends State<PhotoHdWorkspacePage> {
  final PhotoResizeService _photoResizeService = const PhotoResizeService();

  PickedFileData? _selectedImage;
  PhotoSizePreset _selectedPreset = PhotoResizeService.presets.first;
  bool _hdMode = true;
  bool _isProcessing = false;
  _StatusType _statusType = _StatusType.idle;
  String _statusMessage = 'Upload a passport photo or other image to start.';

  @override
  void initState() {
    super.initState();
    _hydrateFromUploadContext();
  }

  void _hydrateFromUploadContext() {
    final image = UploadContextService.getFirstCompatibleFile(
      ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (image == null) {
      return;
    }

    setState(() {
      _selectedImage = image;
      _statusType = _StatusType.idle;
      _statusMessage = 'Loaded image from workspace upload: ${image.name}';
    });
  }

  Future<void> _pickImage() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );

    if (picked == null) {
      return;
    }

    UploadContextService.setLastPickedFile(picked);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = picked;
      _statusType = _StatusType.idle;
      _statusMessage = 'Image selected: ${picked.name}';
    });
  }

  Future<void> _generatePhoto() async {
    final selectedImage = _selectedImage;
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a photo first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusType = _StatusType.processing;
      _statusMessage = 'Preparing ${_hdMode ? 'HD ' : ''}photo for ${_selectedPreset.label}...';
    });

    try {
      final result = _photoResizeService.upscalePhoto(
        bytes: selectedImage.bytes,
        fileName: selectedImage.name,
        preset: _selectedPreset,
        enableHdMode: _hdMode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _statusType = _StatusType.success;
        _statusMessage =
            'Ready: ${result.outputFileName} — ${result.width} × ${result.height} px.';
      });

      await showDialog<void>(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: _hdMode ? 'HD Photo Resize' : 'Photo Resize',
          fileName: result.outputFileName,
          outputBytes: result.bytes,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _statusType = _StatusType.error;
        _statusMessage = 'Unable to prepare image. Please try another file.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo processing failed: $error')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo HD Workspace'),
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
                              Icons.high_quality_rounded,
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
                                  'Photo HD Workspace',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Upload a photo, choose a target size, and generate a high-quality export.',
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
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Source Photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedImage == null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFB8D0ED)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No image selected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supported: JPG, PNG, WEBP, BMP',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          else
                            _SelectedImageSummary(file: _selectedImage!),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _pickImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E3A66),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Upload Photo'),
                              ),
                              if (_selectedImage != null)
                                OutlinedButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedImage = null;
                                            _statusType = _StatusType.idle;
                                            _statusMessage =
                                                'Image cleared. Upload a new photo to continue.';
                                          });
                                        },
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('Clear'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Output Size',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<PhotoSizePreset>(
                            value: _selectedPreset,
                            items: PhotoResizeService.presets
                                .map(
                                  (preset) => DropdownMenuItem<PhotoSizePreset>(
                                    value: preset,
                                    child: Text(preset.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isProcessing
                                ? null
                                : (preset) {
                                    if (preset == null) return;
                                    setState(() {
                                      _selectedPreset = preset;
                                    });
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Choose target size',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: _hdMode,
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    setState(() {
                                      _hdMode = value;
                                    });
                                  },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('HD Photo Mode'),
                            subtitle: const Text(
                              'Applies higher-quality upscale and export settings for the best result possible.',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FBFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD8E5F5)),
                            ),
                            child: Text(
                              'Selected output: ${_selectedPreset.width} \u00d7 ${_selectedPreset.height} px  \u00b7  White background fill applied if needed.',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Output',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _generatePhoto,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0E3A66),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              icon: Icon(_isProcessing ? Icons.hourglass_top_rounded : Icons.high_quality_rounded),
                              label: Text(_isProcessing ? 'Processing...' : 'Generate HD Photo'),
                            ),
                          ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(
                              backgroundColor: Color(0xFFD8E5F5),
                              color: Color(0xFF0E3A66),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _StatusRow(message: _statusMessage, type: _statusType),
                          if (_selectedImage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'File size: ${_formatBytes(_selectedImage!.size)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _SelectedImageSummary extends StatelessWidget {
  final PickedFileData file;

  const _SelectedImageSummary({required this.file});

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image_rounded, color: Color(0xFF0E3A66)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
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
                  _formatBytes(file.size),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
