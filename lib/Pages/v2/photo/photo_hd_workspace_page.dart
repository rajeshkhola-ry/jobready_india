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
        _statusMessage =
            'Ready: ${result.outputFileName} created at ${result.width} x ${result.height}.';
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
                      child: const Text(
                        'Use this V2 workspace to enlarge passport-size photos into larger print or card sizes with best-quality export. HD mode applies a stronger quality-focused upscale pass.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
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
                            const Text(
                              'No image selected yet. JPG, PNG, WEBP, and BMP are supported.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            )
                          else
                            _SelectedImageSummary(file: _selectedImage!),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Upload Photo'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _statusMessage = 'Image cleared. Upload a new photo to continue.';
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
                            initialValue: _selectedPreset,
                            items: PhotoResizeService.presets
                                .map(
                                  (preset) => DropdownMenuItem<PhotoSizePreset>(
                                    value: preset,
                                    child: Text(preset.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (preset) {
                              if (preset == null) {
                                return;
                              }
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
                            onChanged: (value) {
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
                              'Selected output: ${_selectedPreset.width} x ${_selectedPreset.height} px. The app keeps the best fit of the original image and fills extra canvas space with white background if needed.',
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
                              icon: Icon(_isProcessing ? Icons.hourglass_top_rounded : Icons.high_quality_rounded),
                              label: Text(_isProcessing ? 'Processing...' : 'Generate HD Photo'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (_selectedImage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Current file size: ${_formatBytes(_selectedImage!.size)}',
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
