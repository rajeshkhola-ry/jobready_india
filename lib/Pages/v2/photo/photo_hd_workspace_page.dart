import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../../../Services/file_picker_service.dart';
import '../../../Services/free_trial_service.dart';
import '../../../Services/photo_resize_service.dart';
import '../../../Services/upload_context_service.dart';
import '../../../Widgets/download_result_dialog.dart';
import '../../../Widgets/quota_gate.dart';

class PhotoHdWorkspacePage extends StatefulWidget {
  const PhotoHdWorkspacePage({super.key});

  @override
  State<PhotoHdWorkspacePage> createState() => _PhotoHdWorkspacePageState();
}

class _PhotoHdWorkspacePageState extends State<PhotoHdWorkspacePage> {
  final PhotoResizeService _photoResizeService = const PhotoResizeService();
  final GlobalKey _dropZoneKey = GlobalKey();
  bool _isDragOver = false;
  bool _hasShownPlanDialog = false;
  String _selectedPlanId = 'pro';

  PickedFileData? _selectedImage;
  PhotoSizePreset _selectedPreset = PhotoResizeService.presets.first;
  String _selectedDpi = '300';
  String _selectedAspectPreset = 'passport';
  String _selectedBackgroundColor = '#FFFFFF';
  int _maxTargetKb = 100;
  bool _enforceFileSizeLimit = true;
  bool _hdMode = true;
  bool _isProcessing = false;
  double _comparisonPosition = 0.5;
  Uint8List? _comparisonPreviewBytes;
  _StatusType _statusType = _StatusType.idle;
  String _statusMessage = 'Upload a passport photo or other image to start.';

  @override
  void initState() {
    super.initState();
    _hydrateFromUploadContext();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceAccessGate());
    if (kIsWeb) {
      html.document.body?.addEventListener('dragover', _handleBodyDragOver);
      html.document.body?.addEventListener('dragleave', _handleBodyDragLeave);
      html.document.body?.addEventListener('drop', _handleBodyDrop);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      html.document.body?.removeEventListener('dragover', _handleBodyDragOver);
      html.document.body?.removeEventListener('dragleave', _handleBodyDragLeave);
      html.document.body?.removeEventListener('drop', _handleBodyDrop);
    }
    super.dispose();
  }

  void _handleBodyDragOver(html.Event event) {
    event.preventDefault();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDragOver = true;
    });
  }

  void _handleBodyDragLeave(html.Event event) {
    event.preventDefault();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDragOver = false;
    });
  }

  void _handleBodyDrop(html.Event event) {
    event.preventDefault();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDragOver = false;
    });

    final dataTransfer = (event as dynamic).dataTransfer;
    final files = dataTransfer?.files;
    if (files == null || files.isEmpty) {
      return;
    }

    final file = files.item(0);
    if (file == null) {
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.listen((loadEvent) {
      final result = reader.result;
      if (result is String) {
        final dataUri = Uri.parse(result);
        final bytes = dataUri.data?.contentAsBytes();
        if (bytes != null) {
          _consumeDroppedFile(file.name, file.type, bytes);
        }
      }
    });
    reader.readAsDataUrl(file);
  }

  Future<void> _consumeDroppedFile(String name, String type, Uint8List bytes) async {
    final normalizedName = name.isEmpty ? 'dropped-image' : name;
    final allowed = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];
    final extension = normalizedName.split('.').last.toLowerCase();
    if (!allowed.contains(extension)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please drop a JPG, PNG, WEBP, or BMP image.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selectedImage = PickedFileData(name: normalizedName, size: bytes.length, bytes: bytes);
      _statusType = _StatusType.idle;
      _statusMessage = 'Image dropped: $normalizedName';
    });

    Future<void>.microtask(_refreshComparisonPreview);
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

    Future<void>.microtask(_refreshComparisonPreview);
  }

  Future<void> _refreshComparisonPreview() async {
    final selectedImage = _selectedImage;
    if (selectedImage == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comparisonPreviewBytes = null;
      });
      return;
    }

    try {
      final preview = await _photoResizeService.upscalePhoto(
        bytes: selectedImage.bytes,
        fileName: selectedImage.name,
        preset: _selectedPreset,
        enableHdMode: _hdMode,
        dpi: _selectedDpi,
        backgroundColor: _selectedBackgroundColor,
        maxTargetKb: _maxTargetKb,
        aspectPresetId: _selectedAspectPreset,
        enforceFileSizeLimit: _enforceFileSizeLimit,
        previewOnly: true,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _comparisonPreviewBytes = preview.bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comparisonPreviewBytes = null;
      });
    }
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
      _statusMessage = 'Preparing ${_hdMode ? 'identity-safe HD ' : ''}photo for ${_selectedPreset.label}...';
    });

    // Let the progress indicator render before heavy image work starts.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    try {
      final result = await _photoResizeService.upscalePhoto(
        bytes: selectedImage.bytes,
        fileName: selectedImage.name,
        preset: _selectedPreset,
        enableHdMode: _hdMode,
        dpi: _selectedDpi,
        backgroundColor: _selectedBackgroundColor,
        maxTargetKb: _maxTargetKb,
        aspectPresetId: _selectedAspectPreset,
        enforceFileSizeLimit: _enforceFileSizeLimit,
        previewOnly: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _statusType = _StatusType.success;
        _statusMessage =
            'Ready: ${result.outputFileName} — ${result.width} × ${result.height} px. ${result.outputLabel}';
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

  List<_PlanOption> get _planOptions => [
        _PlanOption(
          id: 'lite',
          label: 'HD Lite',
          subtitle: 'Fast boost for quick passport and ID-sized images',
          priceTag: 'Starter',
          description: 'Perfect for light upscaling with a cleaner, identity-safe result.',
          features: ['Fast preview generation', 'Identity-safe enhancement', 'Portable output sizes'],
          accent: const Color(0xFF2563EB),
          icon: Icons.auto_fix_high_rounded,
        ),
        _PlanOption(
          id: 'pro',
          label: 'HD Pro',
          subtitle: 'Balanced quality and control for everyday photo work',
          priceTag: 'Recommended',
          description: 'A stronger quality lift with more refinement detail and sharper output.',
          features: ['Higher detail recovery', 'Better color balance', 'More controlled resizing'],
          accent: const Color(0xFF4F46E5),
          icon: Icons.workspace_premium_rounded,
        ),
        _PlanOption(
          id: 'team',
          label: 'HD Team',
          subtitle: 'For batch work and premium studio-style workflows',
          priceTag: 'Team',
          description: 'Ideal for more demanding output and multi-image review sessions.',
          features: ['Batch-friendly workflow', 'Premium refinement controls', 'Priority output handling'],
          accent: const Color(0xFF0F766E),
          icon: Icons.groups_rounded,
        ),
      ];

  _PlanOption _getSelectedPlan(String id) {
    return _planOptions.firstWhere(
      (plan) => plan.id == id,
      orElse: () => _planOptions[1],
    );
  }

  Future<void> _enforceAccessGate() async {
    if (!mounted) {
      return;
    }
    final allowed = await checkOneTimeToolAccessAndProceed(
      context: context,
      toolKey: FreeTrialService.hdPhotoTool,
      toolLabel: 'HD Photo Studio',
    );
    if (!mounted) {
      return;
    }
    if (!allowed) {
      Navigator.of(context).pop();
      return;
    }
    if (!_hasShownPlanDialog) {
      _showPlanSelectionDialog();
    }
  }

  Future<void> _showPlanSelectionDialog() async {
    if (!mounted || _hasShownPlanDialog) {
      return;
    }

    final selection = await showDialog<_PlanOption>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String selectedPlanId = _selectedPlanId;
        String? hoveredPlanId;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8FBFF), Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCE9F8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your HD Photo plan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a plan to tailor your enhancement experience and keep the image workflow moving.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._planOptions.map((plan) {
                      final isSelected = plan.id == selectedPlanId;
                      final isHovered = hoveredPlanId == plan.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setDialogState(() => hoveredPlanId = plan.id),
                          onExit: (_) => setDialogState(() => hoveredPlanId = null),
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => selectedPlanId = plan.id);
                              setState(() {
                                _selectedPlanId = plan.id;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              transform: Matrix4.identity()..scale(isHovered ? 1.01 : 1.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? plan.accent : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.2 : 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: plan.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(plan.icon, color: plan.accent, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plan.label,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: plan.accent.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                plan.priceTag,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: plan.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          plan.subtitle,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          plan.description,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            height: 1.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: plan.features
                                              .map(
                                                (feature) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    feature,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? plan.accent : const Color(0xFFCBD5E1),
                                        width: 2,
                                      ),
                                      color: isSelected ? plan.accent : Colors.white,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final chosenPlan = _planOptions.firstWhere(
                              (plan) => plan.id == selectedPlanId,
                              orElse: () => _planOptions[1],
                            );
                            setState(() {
                              _selectedPlanId = chosenPlan.id;
                            });
                            Navigator.of(dialogContext).pop(chosenPlan);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: const Text(
                              'Try Pro for Free',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _hasShownPlanDialog = true;
      if (selection != null) {
        _selectedPlanId = selection.id;
        _statusType = _StatusType.idle;
        _statusMessage = 'Selected ${selection.label}. Continue with your enhancement workflow.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo HD Workspace'),
        backgroundColor: const Color(0xFF0E3A66),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
                              borderRadius: BorderRadius.circular(14),
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
                                  'Identity-Preserving HD Photo Studio',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    height: 1.25,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Upload a photo, choose a target size, and generate a conservative HD export without changing facial identity.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.55,
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
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _getSelectedPlan(_selectedPlanId).accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getSelectedPlan(_selectedPlanId).icon,
                              color: _getSelectedPlan(_selectedPlanId).accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected plan: ${_getSelectedPlan(_selectedPlanId).label}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _getSelectedPlan(_selectedPlanId).description,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getSelectedPlan(_selectedPlanId).accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _getSelectedPlan(_selectedPlanId).priceTag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _getSelectedPlan(_selectedPlanId).accent,
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
                            'Source Photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedImage == null)
                            InkWell(
                              key: _dropZoneKey,
                              onTap: _isProcessing ? null : _pickImage,
                              onHover: (hovering) {
                                if (!kIsWeb || _isProcessing) {
                                  return;
                                }
                                setState(() {
                                  _isDragOver = hovering;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _isDragOver ? const Color(0xFFEAF2FF) : const Color(0xFFF8FBFF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isDragOver ? const Color(0xFF0E3A66) : const Color(0xFFB8D0ED),
                                    width: _isDragOver ? 2 : 1,
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 34,
                                      color: Color(0xFF0E3A66),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Drag & drop your image here',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'or click Upload Photo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Supported: JPG, PNG, WEBP, BMP',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
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
                          DropdownButtonFormField<String>(
                            value: _selectedDpi,
                            items: PhotoResizeService.dpiOptions
                                .map((dpi) => DropdownMenuItem(value: dpi, child: Text('$dpi DPI')))
                                .toList(growable: false),
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedDpi = value;
                                    });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Print DPI',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedAspectPreset,
                            items: const [
                              DropdownMenuItem(value: 'passport', child: Text('3.5cm x 4.5cm (Passport)')),
                              DropdownMenuItem(value: 'visa', child: Text('2 x 2 inch (Visa / Universal)')),
                              DropdownMenuItem(value: 'square', child: Text('1:1 Square / Stamp')),
                            ],
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedAspectPreset = value;
                                    });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Aspect ratio preset',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedBackgroundColor,
                            items: const [
                              DropdownMenuItem(value: '#FFFFFF', child: Text('Plain White #FFFFFF')),
                              DropdownMenuItem(value: '#E0F2FE', child: Text('Light Blue #E0F2FE')),
                            ],
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedBackgroundColor = value;
                                    });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Background fill',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: _enforceFileSizeLimit,
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    setState(() {
                                      _enforceFileSizeLimit = value;
                                    });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Compress to portal-safe output'),
                            subtitle: const Text('Keeps the export under the selected file-size target where possible.'),
                          ),
                          if (_enforceFileSizeLimit) ...[
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(child: Text('Target file size')),
                                    Text('≤ ${_maxTargetKb}KB', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0E3A66))),
                                  ],
                                ),
                                Slider(
                                  value: _maxTargetKb.toDouble(),
                                  min: 50,
                                  max: 100,
                                  divisions: 1,
                                  label: _maxTargetKb.toString(),
                                  onChanged: _isProcessing ? null : (value) {
                                    setState(() { _maxTargetKb = value.round(); });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: _hdMode,
                            onChanged: _isProcessing
                                ? null
                                : (value) {
                                    setState(() {
                                      _hdMode = value;
                                    });
                                    Future<void>.microtask(_refreshComparisonPreview);
                                  },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Identity-Safe HD Mode'),
                            subtitle: const Text(
                              'Uses mild upscaling and color correction only. No face replacement, no aggressive AI restoration.',
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
                              'Selected output: ${_selectedPreset.width} \u00d7 ${_selectedPreset.height} px  \u00b7  Identity-preserving enhancement only, no facial feature changes.',
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
                            'Before / After Comparison',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedImage != null)
                            Container(
                              height: 280,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD8E5F5)),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.memory(
                                        _selectedImage!.bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (_comparisonPreviewBytes != null)
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: FractionallySizedBox(
                                          widthFactor: _comparisonPosition,
                                          alignment: Alignment.centerLeft,
                                          child: Image.memory(
                                            _comparisonPreviewBytes!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: SliderTheme(
                                      data: const SliderThemeData(
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                                        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                                      ),
                                      child: Slider(
                                        value: _comparisonPosition,
                                        onChanged: (value) {
                                          setState(() {
                                            _comparisonPosition = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    bottom: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text('Enhanced view', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFD8E5F5)),
                              ),
                              child: const Text('Upload an image to preview the before/after comparison slider.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                              label: Text(_isProcessing ? 'Processing...' : 'Generate Identity-Safe HD Photo'),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E5F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlanOption {
  const _PlanOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.priceTag,
    required this.description,
    required this.features,
    required this.accent,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final String priceTag;
  final String description;
  final List<String> features;
  final Color accent;
  final IconData icon;
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
