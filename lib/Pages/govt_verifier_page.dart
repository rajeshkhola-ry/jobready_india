import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../Services/analytics_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/upload_context_service.dart';
import '../Services/voice_command_service.dart';
import '../Services/wasm_document_service.dart';

class GovtVerifierPage extends StatefulWidget {
  const GovtVerifierPage({super.key});

  @override
  State<GovtVerifierPage> createState() => _GovtVerifierPageState();
}

class _GovtVerifierPageState extends State<GovtVerifierPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Tab 1: Name/DOP Overlay ────────────────────────────────────────────────
  PickedFileData? _overlayFile;
  ui.Image? _overlayImage;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _dopCtrl = TextEditingController();
  bool _stripAtBottom = true;
  bool _twoLineStrip = false;
  final GlobalKey _overlayCanvasKey = GlobalKey();
  bool _isExportingOverlay = false;
  String _overlayStatus = 'Upload a passport photo, enter your name and date.';

  // ── Tab 2: Exact KB & Dimension Resizer ───────────────────────────────────
  PickedFileData? _resizerFile;
  GovtPhotoPreset _selectedPreset = kGovtPhotoPresets.first;
  late int _targetKb;
  bool _isResizing = false;
  String _resizerStatus = 'Select an exam/portal preset and upload your photo.';
  String? _achievedSize;

  // ── Tab 3: Smart Redactor ──────────────────────────────────────────────────
  PickedFileData? _redactorFile;
  ui.Image? _redactorImage;
  final List<Rect> _redactorMasks = [];
  _DocType _docType = _DocType.aadhaarFront;
  Offset? _dragStart;
  Rect? _activeDrag;
  final GlobalKey _redactorCanvasKey = GlobalKey();
  bool _isExportingRedaction = false;
  String _redactorStatus = 'Select a document type, upload the image, then apply masks.';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _targetKb = _selectedPreset.maxKb;
    _nameCtrl.addListener(() => setState(() {}));
    _dopCtrl.addListener(() => setState(() {}));
    AnalyticsService.trackToolOpen('govt_verifier');
    _applyVoiceCommandPreset();
    _hydrateFromUploadContext();
  }

  void _applyVoiceCommandPreset() {
    final params = VoiceCommandService.consumePendingParameters();
    if (params.isEmpty) {
      return;
    }
    final rawPreset = params['preset'];
    final match = rawPreset == null ? null : _matchExamPreset(rawPreset.toString());
    if (match != null) {
      setState(() {
        _selectedPreset = match;
        _targetKb = match.maxKb;
        _tabs.index = 1;
        _resizerStatus = 'Voice command: "${match.label}" preset selected. Upload your photo.';
      });
    }
    final autoExecute = params[VoiceCommandService.autoExecuteFlagKey] == true;
    if (autoExecute) {
      setState(() => _tabs.index = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _resizerFile != null) {
          _resizeAndDownload();
        }
      });
    }
  }

  GovtPhotoPreset? _matchExamPreset(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (normalized.isEmpty) {
      return null;
    }
    for (final preset in kGovtPhotoPresets) {
      if (preset.id == normalized) {
        return preset;
      }
    }
    for (final preset in kGovtPhotoPresets) {
      if (preset.id.startsWith(normalized)) {
        return preset;
      }
    }
    for (final preset in kGovtPhotoPresets) {
      final normalizedLabel = preset.label.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
      if (normalizedLabel.contains(normalized)) {
        return preset;
      }
    }
    return null;
  }

  void _hydrateFromUploadContext() {
    final resizerImage = UploadContextService.getFirstCompatibleFile(['jpg', 'jpeg', 'png']);
    if (resizerImage != null) {
      _resizerFile = resizerImage;
      _resizerStatus = '✓ ${resizerImage.name} loaded from workspace upload. Tap "Resize & Download".';
    }

    final overlayImage = UploadContextService.getFirstCompatibleFile(['jpg', 'jpeg', 'png']);
    if (overlayImage != null) {
      unawaited(_decodeOverlayImage(overlayImage));
    }
  }

  Future<void> _decodeOverlayImage(PickedFileData picked) async {
    final codec = await ui.instantiateImageCodec(picked.bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    _overlayImage?.dispose();
    setState(() {
      _overlayFile = picked;
      _overlayImage = frame.image;
      _overlayStatus = '✓ ${picked.name} loaded from workspace upload. Enter your name and DOP, then download.';
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _dopCtrl.dispose();
    _overlayImage?.dispose();
    _redactorImage?.dispose();
    super.dispose();
  }

  // ── Tab 1 helpers ──────────────────────────────────────────────────────────

  Future<void> _pickOverlayImage() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(picked.bytes);
    final frame = await codec.getNextFrame();
    _overlayImage?.dispose();
    setState(() {
      _overlayFile = picked;
      _overlayImage = frame.image;
      _overlayStatus = 'Photo loaded. Enter your name and DOP, then download.';
    });
  }

  Future<void> _exportOverlayImage() async {
    if (_overlayImage == null) return;
    setState(() { _isExportingOverlay = true; _overlayStatus = 'Rendering overlay…'; });
    try {
      final boundary = _overlayCanvasKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Canvas not ready.');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Encoding failed.');
      final name = _nameCtrl.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      WasmDocumentService.triggerBrowserDownload(
        bytes: data.buffer.asUint8List(),
        fileName: 'passport_overlay_${name.isEmpty ? 'photo' : name}.png',
        mimeType: 'image/png',
      );
      if (mounted) setState(() => _overlayStatus = 'Downloaded with Name/DOP overlay. ✓');
    } catch (e) {
      if (mounted) setState(() => _overlayStatus = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExportingOverlay = false);
    }
  }

  // ── Tab 2 helpers ──────────────────────────────────────────────────────────

  Future<void> _pickResizerImage() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _resizerFile = picked;
      _achievedSize = null;
      _resizerStatus = 'Image loaded: ${picked.name}. Tap "Resize & Download".';
    });
  }

  Future<void> _resizeAndDownload() async {
    if (_resizerFile == null) return;
    setState(() { _isResizing = true; _achievedSize = null; _resizerStatus = 'Resizing…'; });
    try {
      final result = await compute(
        computeGovtPhotoResize,
        GovtPhotoResizeArgs(
          bytes: _resizerFile!.bytes,
          width: _selectedPreset.width,
          height: _selectedPreset.height,
          targetKb: _targetKb,
        ),
      );
      if (!mounted) return;
      final achievedKb = (result.length / 1024).toStringAsFixed(1);
      setState(() {
        _achievedSize = '${achievedKb} KB  •  ${_selectedPreset.width}×${_selectedPreset.height} px';
        _resizerStatus = 'Done — ${achievedKb} KB, ${_selectedPreset.width}×${_selectedPreset.height} px.';
      });
      final label = _selectedPreset.id.replaceAll('_', '-');
      WasmDocumentService.triggerBrowserDownload(
        bytes: result,
        fileName: 'govt_photo_${label}_${_targetKb}kb.jpg',
        mimeType: 'image/jpeg',
      );
      AnalyticsService.trackToolAction('govt_verifier', 'photo_resize');
    } catch (e) {
      if (mounted) setState(() => _resizerStatus = 'Resize failed: $e');
    } finally {
      if (mounted) setState(() => _isResizing = false);
    }
  }

  // ── Tab 3 helpers ──────────────────────────────────────────────────────────

  Future<void> _pickRedactorImage() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(picked.bytes);
    final frame = await codec.getNextFrame();
    _redactorImage?.dispose();
    setState(() {
      _redactorFile = picked;
      _redactorImage = frame.image;
      _redactorMasks.clear();
      _redactorStatus = 'Image loaded. Tap "Auto-Apply Zones" or draw custom masks.';
    });
  }

  void _autoApplyZones() {
    setState(() {
      _redactorMasks
        ..clear()
        ..addAll(_docType.presetZones.map((p) => p.rect));
      _redactorStatus = 'Auto-applied ${_redactorMasks.length} zone(s) for ${_docType.label}.';
    });
  }

  void _onRedactPanStart(DragStartDetails d, Size s) {
    _dragStart = _norm(d.localPosition, s);
  }

  void _onRedactPanUpdate(DragUpdateDetails d, Size s) {
    setState(() => _activeDrag = _corners(_dragStart!, _norm(d.localPosition, s)));
  }

  void _onRedactPanEnd(DragEndDetails _) {
    if (_activeDrag != null && _activeDrag!.width > 0.01 && _activeDrag!.height > 0.01) {
      setState(() {
        _redactorMasks.add(_activeDrag!);
        _redactorStatus = '${_redactorMasks.length} zone(s) active.';
      });
    }
    _dragStart = null;
    setState(() => _activeDrag = null);
  }

  Future<void> _exportRedaction() async {
    if (_redactorImage == null) return;
    setState(() { _isExportingRedaction = true; _redactorStatus = 'Rendering redacted image…'; });
    try {
      final boundary = _redactorCanvasKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Canvas not ready.');
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Encoding failed.');
      WasmDocumentService.triggerBrowserDownload(
        bytes: data.buffer.asUint8List(),
        fileName: 'redacted_${_docType.id}.png',
        mimeType: 'image/png',
      );
      if (mounted) setState(() => _redactorStatus = 'Redacted image downloaded. ✓');
    } catch (e) {
      if (mounted) setState(() => _redactorStatus = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExportingRedaction = false);
    }
  }

  // ── Geometry helpers ───────────────────────────────────────────────────────

  static Offset _norm(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  static Rect _corners(Offset a, Offset b) => Rect.fromLTRB(
        a.dx < b.dx ? a.dx : b.dx, a.dy < b.dy ? a.dy : b.dy,
        a.dx > b.dx ? a.dx : b.dx, a.dy > b.dy ? a.dy : b.dy,
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2D4A),
        foregroundColor: Colors.white,
        title: const Text('Govt-Rule Auto-Verifier & Redactor'),
        titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFCD34D),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.badge_rounded, size: 16), text: 'Name / DOP Strip'),
            Tab(icon: Icon(Icons.compress_rounded, size: 16), text: 'Exact KB Resizer'),
            Tab(icon: Icon(Icons.security_rounded, size: 16), text: 'Smart Redactor'),
          ],
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
        child: TabBarView(
          controller: _tabs,
          children: [_buildOverlayTab(), _buildResizerTab(), _buildRedactorTab()],
        ),
      ),
    );
  }

  // ── Tab 1: Name/DOP Overlay ────────────────────────────────────────────────

  Widget _buildOverlayTab() {
    final hasImage = _overlayImage != null;
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDop = _dopCtrl.text.trim().isNotEmpty;
    final canExport = hasImage && (hasName || hasDop);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.badge_rounded,
                color: const Color(0xFF0F2D4A),
                title: 'Name & Date of Photo (DOP) Overlay Strip',
                body: 'Adds a black strip with crisp white text following SSC/UPSC standards. '
                    '100% local — no upload. Exported at 3× resolution for print.',
              ),
              const SizedBox(height: 14),

              // Upload
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Source Photo'),
                  const SizedBox(height: 10),
                  if (_overlayFile == null)
                    _dropZone('Upload a passport photo (JPG / PNG)', onTap: _pickOverlayImage)
                  else
                    _fileRow(_overlayFile!.name, Icons.image_rounded, sizeBytes: _overlayFile!.size),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _pickOverlayImage,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(_overlayFile == null ? 'Upload Photo' : 'Replace Photo'),
                    style: _primaryBtn(const Color(0xFF0F2D4A)),
                  ),
                ],
              )),
              const SizedBox(height: 14),

              // Name & DOP fields
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Overlay Text'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Full Name (as per ID)',
                      hintText: 'RAMESH KUMAR SHARMA',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dopCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date of Photo (DOP)',
                      hintText: '05/08/2026',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: _stripAtBottom,
                          onChanged: (v) => setState(() => _stripAtBottom = v),
                          activeColor: const Color(0xFF0F2D4A),
                        ),
                        const Text('Strip at bottom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: _twoLineStrip,
                          onChanged: (v) => setState(() => _twoLineStrip = v),
                          activeColor: const Color(0xFF0F2D4A),
                        ),
                        const Text('Two-line layout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 14),

              // Live preview
              if (hasImage) ...[
                _panel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _H('Preview'),
                    const SizedBox(height: 10),
                    Center(
                      child: LayoutBuilder(builder: (ctx, bc) {
                        final maxW = bc.maxWidth.clamp(180.0, 340.0);
                        final imgW = _overlayImage!.width.toDouble();
                        final imgH = _overlayImage!.height.toDouble();
                        final h = (maxW * imgH / imgW).clamp(100.0, 480.0);
                        return RepaintBoundary(
                          key: _overlayCanvasKey,
                          child: SizedBox(
                            width: maxW, height: h,
                            child: CustomPaint(
                              painter: _OverlayStripPainter(
                                image: _overlayImage!,
                                name: _nameCtrl.text.trim().toUpperCase(),
                                dop: _dopCtrl.text.trim(),
                                atBottom: _stripAtBottom,
                                twoLine: _twoLineStrip,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                )),
                const SizedBox(height: 14),
              ],

              _statusRow(_overlayStatus),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!canExport || _isExportingOverlay) ? null : _exportOverlayImage,
                  icon: _isExportingOverlay
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded),
                  label: Text(_isExportingOverlay ? 'Rendering…' : 'Download Photo with Name/DOP Strip (PNG)'),
                  style: _primaryBtn(const Color(0xFF0F2D4A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Exact KB Resizer ────────────────────────────────────────────────

  Widget _buildResizerTab() {
    final p = _selectedPreset;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.compress_rounded,
                color: const Color(0xFF1E5B88),
                title: 'Exact KB & Dimension Resizer',
                body: 'Resize your photo/signature to the exact pixel dimensions and KB required by '
                    'SSC, UPSC, IBPS, RRB, and other govt portals. Binary-quality compression stays within limits.',
              ),
              const SizedBox(height: 14),

              // Preset grid
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Exam / Portal Preset'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kGovtPhotoPresets.map((preset) {
                      final active = preset.id == _selectedPreset.id;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedPreset = preset;
                          _targetKb = preset.maxKb;
                          _achievedSize = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF0F2D4A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? const Color(0xFF0F2D4A) : const Color(0xFFD0E0F0),
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.label,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${preset.width}×${preset.height}px  •  ${preset.minKb}–${preset.maxKb} KB',
                                style: TextStyle(fontSize: 10.5, color: active ? const Color(0xFFBAD4F0) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB8D0ED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.notes, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Text('Target size: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text('$_targetKb KB', style: const TextStyle(fontSize: 12, color: Color(0xFF0F2D4A), fontWeight: FontWeight.w800)),
                          const Spacer(),
                          if (_achievedSize != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                              child: Text(_achievedSize!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                            ),
                        ]),
                        Slider(
                          value: _targetKb.toDouble(),
                          min: p.minKb.toDouble(),
                          max: p.maxKb.toDouble(),
                          divisions: p.maxKb - p.minKb > 0 ? p.maxKb - p.minKb : 1,
                          activeColor: const Color(0xFF0F2D4A),
                          label: '$_targetKb KB',
                          onChanged: (v) => setState(() => _targetKb = v.round()),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 14),

              // Upload
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Photo / Signature'),
                  const SizedBox(height: 10),
                  if (_resizerFile == null)
                    _dropZone('Upload photo or signature image', onTap: _pickResizerImage)
                  else
                    _fileRow(_resizerFile!.name, Icons.image_rounded, sizeBytes: _resizerFile!.size),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _pickResizerImage,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(_resizerFile == null ? 'Upload Image' : 'Replace Image'),
                    style: _primaryBtn(const Color(0xFF1E5B88)),
                  ),
                ],
              )),
              const SizedBox(height: 14),

              _statusRow(_resizerStatus),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_resizerFile == null || _isResizing) ? null : _resizeAndDownload,
                  icon: _isResizing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.compress_rounded),
                  label: Text(_isResizing
                      ? 'Resizing…'
                      : 'Resize to ${p.width}×${p.height}px / $_targetKb KB & Download'),
                  style: _primaryBtn(const Color(0xFF1E5B88)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 3: Smart Redactor ──────────────────────────────────────────────────

  Widget _buildRedactorTab() {
    final hasImage = _redactorImage != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.security_rounded,
                color: const Color(0xFF1A2B45),
                title: 'Smart Aadhaar / PAN Redactor',
                body: 'Auto-applies redaction zones for the selected document type. '
                    'Drag to add custom zones. 100% local — no data leaves your device.',
              ),
              const SizedBox(height: 14),

              // Document type
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Document Type'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _DocType.values.map((dt) {
                      final active = dt == _docType;
                      return ChoiceChip(
                        avatar: Icon(dt.icon, size: 14, color: active ? Colors.white : const Color(0xFF475569)),
                        label: Text(dt.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        selected: active,
                        onSelected: (_) => setState(() { _docType = dt; _redactorMasks.clear(); }),
                        selectedColor: const Color(0xFF1A2B45),
                        labelStyle: TextStyle(color: active ? Colors.white : const Color(0xFF0F172A)),
                        side: const BorderSide(color: Color(0xFFB8D0ED)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _docType.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
                  ),
                ],
              )),
              const SizedBox(height: 14),

              // Upload
              _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _H('Document Image'),
                  const SizedBox(height: 10),
                  if (_redactorFile == null)
                    _dropZone('Upload Aadhaar / PAN / document image', onTap: _pickRedactorImage)
                  else
                    _fileRow(_redactorFile!.name, Icons.description_rounded),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, children: [
                    ElevatedButton.icon(
                      onPressed: _pickRedactorImage,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(_redactorFile == null ? 'Upload Image' : 'Replace'),
                      style: _primaryBtn(const Color(0xFF1A2B45)),
                    ),
                    if (hasImage)
                      OutlinedButton.icon(
                        onPressed: _autoApplyZones,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: Text('Auto-Apply ${_docType.label} Zones'),
                      ),
                  ]),
                ],
              )),

              if (hasImage) ...[
                const SizedBox(height: 14),
                _panel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _H('Canvas — drag to add custom mask'),
                        const Spacer(),
                        if (_redactorMasks.isNotEmpty) ...[
                          TextButton.icon(
                            onPressed: () => setState(() { _redactorMasks.removeLast(); }),
                            icon: const Icon(Icons.undo_rounded, size: 15),
                            label: const Text('Undo'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() { _redactorMasks.clear(); }),
                            icon: const Icon(Icons.delete_outline_rounded, size: 15),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF9F1239)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(builder: (ctx, bc) {
                      final maxW = bc.maxWidth;
                      final imgW = _redactorImage!.width.toDouble();
                      final imgH = _redactorImage!.height.toDouble();
                      final h = (maxW * imgH / imgW).clamp(150.0, 540.0);
                      return RepaintBoundary(
                        key: _redactorCanvasKey,
                        child: SizedBox(
                          width: maxW, height: h,
                          child: GestureDetector(
                            onPanStart: (d) => _onRedactPanStart(d, Size(maxW, h)),
                            onPanUpdate: (d) => _onRedactPanUpdate(d, Size(maxW, h)),
                            onPanEnd: _onRedactPanEnd,
                            child: CustomPaint(
                              painter: _RedactorPainter(
                                image: _redactorImage!,
                                masks: _redactorMasks,
                                activeDrag: _activeDrag,
                              ),
                              size: Size(maxW, h),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      '${_redactorMasks.length} mask zone(s)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                )),
                const SizedBox(height: 14),
              ],

              _statusRow(_redactorStatus),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!hasImage || _redactorMasks.isEmpty || _isExportingRedaction)
                      ? null
                      : _exportRedaction,
                  icon: _isExportingRedaction
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shield_rounded),
                  label: Text(_isExportingRedaction ? 'Rendering…' : 'Download Redacted Image (PNG)'),
                  style: _primaryBtn(const Color(0xFF1A2B45)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _infoCard({required IconData icon, required Color color, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8E5F5)),
        ),
        child: child,
      );

  Widget _dropZone(String label, {required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB8D0ED)),
          ),
          child: Column(children: [
            const Icon(Icons.upload_file_rounded, size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ]),
        ),
      );

  Widget _fileRow(String name, IconData icon, {int? sizeBytes}) => Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF0E3A66)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              if (sizeBytes != null)
                Text(_formatFileSize(sizeBytes), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
      ]);

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Widget _statusRow(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB8D0ED)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45))),
        ]),
      );

  ButtonStyle _primaryBtn(Color color) => ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      );
}

// ── Overlay painter ────────────────────────────────────────────────────────────

class _OverlayStripPainter extends CustomPainter {
  final ui.Image image;
  final String name;
  final String dop;
  final bool atBottom;
  final bool twoLine;

  const _OverlayStripPainter({
    required this.image,
    required this.name,
    required this.dop,
    required this.atBottom,
    required this.twoLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.contain);

    if (name.isEmpty && dop.isEmpty) return;

    final stripH = (size.height * 0.115).clamp(18.0, 38.0);
    final stripTop = atBottom ? size.height - stripH : 0.0;
    final stripRect = Rect.fromLTWH(0, stripTop, size.width, stripH);

    canvas.drawRect(stripRect, Paint()..color = Colors.black);

    final fontSize = (stripH * (twoLine ? 0.28 : 0.36)).clamp(7.0, 14.0);
    final style = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: fontSize,
      fontWeight: ui.FontWeight.w700,
      letterSpacing: 0.4,
    );

    if (twoLine) {
      _paintLine(canvas, name.isNotEmpty ? 'Name: $name' : '', size.width, stripTop, stripH * 0.3, style);
      _paintLine(canvas, dop.isNotEmpty ? 'DOP: $dop' : '', size.width, stripTop + stripH * 0.55, stripH * 0.3, style);
    } else {
      final parts = <String>[];
      if (name.isNotEmpty) parts.add('Name: $name');
      if (dop.isNotEmpty) parts.add('DOP: $dop');
      _paintLine(canvas, parts.join('     '), size.width, stripTop + (stripH - fontSize) / 2, stripH, style);
    }
  }

  void _paintLine(Canvas canvas, String text, double width, double top, double lineH, ui.TextStyle style) {
    if (text.isEmpty) return;
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(style)
      ..addText(text);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(para, Offset(0, top + (lineH - para.height) / 2));
  }

  @override
  bool shouldRepaint(_OverlayStripPainter old) =>
      old.image != image || old.name != name || old.dop != dop ||
      old.atBottom != atBottom || old.twoLine != twoLine;
}

// ── Redactor painter ───────────────────────────────────────────────────────────

class _RedactorPainter extends CustomPainter {
  final ui.Image image;
  final List<Rect> masks;
  final Rect? activeDrag;

  const _RedactorPainter({required this.image, required this.masks, this.activeDrag});

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.contain);
    final black = Paint()..color = Colors.black;
    for (final r in masks) {
      canvas.drawRect(_dn(r, size), black);
    }
    if (activeDrag != null) {
      canvas.drawRect(_dn(activeDrag!, size), Paint()..color = Colors.black.withValues(alpha: 0.72));
    }
  }

  static Rect _dn(Rect r, Size s) => Rect.fromLTWH(
        r.left * s.width, r.top * s.height, r.width * s.width, r.height * s.height);

  @override
  bool shouldRepaint(_RedactorPainter o) =>
      o.masks != masks || o.activeDrag != activeDrag || o.image != image;
}

// ── Section heading ────────────────────────────────────────────────────────────

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      );
}

// ── Resize compute isolate ─────────────────────────────────────────────────────

class GovtPhotoResizeArgs {
  final Uint8List bytes;
  final int width;
  final int height;
  final int targetKb;
  const GovtPhotoResizeArgs({required this.bytes, required this.width, required this.height, required this.targetKb});
}

Uint8List computeGovtPhotoResize(GovtPhotoResizeArgs args) {
  final src = img.decodeImage(args.bytes);
  if (src == null) throw Exception('Cannot decode image.');

  final resized = img.copyResize(
    src,
    width: args.width,
    height: args.height,
    interpolation: img.Interpolation.cubic,
  );

  // Binary search: highest quality within targetKb
  int lo = 15, hi = 95;
  Uint8List? best;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: mid));
    if (encoded.length <= args.targetKb * 1024) {
      best = encoded;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best ?? Uint8List.fromList(img.encodeJpg(resized, quality: 15));
}

// ── Exam presets ───────────────────────────────────────────────────────────────

class GovtPhotoPreset {
  final String id;
  final String label;
  final int width;
  final int height;
  final int minKb;
  final int maxKb;
  final String notes;

  const GovtPhotoPreset({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.minKb,
    required this.maxKb,
    required this.notes,
  });
}

const List<GovtPhotoPreset> kGovtPhotoPresets = [
  GovtPhotoPreset(
    id: 'ssc_photo',
    label: 'SSC Photo',
    width: 200, height: 230,
    minKb: 20, maxKb: 50,
    notes: 'SSC CGL/CHSL/MTS: 3.5×4.5 cm, 20–50 KB, JPG/JPEG. White or light background.',
  ),
  GovtPhotoPreset(
    id: 'ssc_signature',
    label: 'SSC Signature',
    width: 140, height: 60,
    minKb: 10, maxKb: 20,
    notes: 'SSC CGL/CHSL/MTS: 3.5×1.5 cm, 10–20 KB, JPG/JPEG. Black ink on white background.',
  ),
  GovtPhotoPreset(
    id: 'upsc_photo',
    label: 'UPSC Photo',
    width: 300, height: 400,
    minKb: 20, maxKb: 300,
    notes: 'UPSC CSE/IFoS: 3.5×4.5 cm, max 300 KB, JPG. Must show full face, light background.',
  ),
  GovtPhotoPreset(
    id: 'ibps_photo',
    label: 'IBPS / Bank Photo',
    width: 200, height: 230,
    minKb: 20, maxKb: 50,
    notes: 'IBPS PO/Clerk/SO: approx 200×230 px, 20–50 KB, JPG. Plain white background.',
  ),
  GovtPhotoPreset(
    id: 'ibps_signature',
    label: 'IBPS Signature',
    width: 140, height: 60,
    minKb: 10, maxKb: 20,
    notes: 'IBPS PO/Clerk/SO: approx 140×60 px, 10–20 KB, JPG. Blue/black ink on white.',
  ),
  GovtPhotoPreset(
    id: 'rrb_photo',
    label: 'RRB / Railway Photo',
    width: 200, height: 230,
    minKb: 15, maxKb: 100,
    notes: 'RRB NTPC/Group-D/ALP: 3.5×4.5 cm, 15–100 KB, JPG. Light background, no cap.',
  ),
  GovtPhotoPreset(
    id: 'jee_photo',
    label: 'JEE / NEET Photo',
    width: 144, height: 192,
    minKb: 10, maxKb: 100,
    notes: 'JEE Main/NEET-UG: approx 3.5×4.5 cm, 10–100 KB, JPG. Plain white background.',
  ),
  GovtPhotoPreset(
    id: 'aadhaar_photo_update',
    label: 'Aadhaar Photo Update',
    width: 200, height: 200,
    minKb: 10, maxKb: 100,
    notes: 'UIDAI: square crop preferred, max 100 KB, JPG/JPEG. Face clearly visible.',
  ),
];

// ── Document types for Smart Redactor ─────────────────────────────────────────

class _RedactZone {
  final String label;
  final Rect rect;  // normalised 0..1
  const _RedactZone(this.label, this.rect);
}

enum _DocType {
  aadhaarFront,
  aadhaarBack,
  panCard,
  voterIdFront,
  passport;

  String get id => name;

  String get label => switch (this) {
        _DocType.aadhaarFront => 'Aadhaar Front',
        _DocType.aadhaarBack => 'Aadhaar Back',
        _DocType.panCard => 'PAN Card',
        _DocType.voterIdFront => 'Voter ID',
        _DocType.passport => 'Passport',
      };

  IconData get icon => switch (this) {
        _DocType.aadhaarFront => Icons.credit_card_rounded,
        _DocType.aadhaarBack => Icons.credit_card_off_rounded,
        _DocType.panCard => Icons.account_balance_rounded,
        _DocType.voterIdFront => Icons.how_to_vote_rounded,
        _DocType.passport => Icons.book_rounded,
      };

  String get description => switch (this) {
        _DocType.aadhaarFront =>
          'Masks: 12-digit Aadhaar number, photo area, date of birth, and address. '
              'Leaves name and UID suffix (last 4 digits) visible for basic verification.',
        _DocType.aadhaarBack =>
          'Masks: full address block and QR code on the back face of the Aadhaar card.',
        _DocType.panCard =>
          'Masks: 10-character PAN number, full name, father\'s name, and date of birth.',
        _DocType.voterIdFront =>
          'Masks: voter ID number, house number, and address fields.',
        _DocType.passport =>
          'Masks: passport number, date of birth, personal number, and MRZ lines.',
      };

  List<_RedactZone> get presetZones => switch (this) {
        _DocType.aadhaarFront => const [
            _RedactZone('Aadhaar Number', Rect.fromLTWH(0.12, 0.82, 0.65, 0.09)),
            _RedactZone('Photo Area', Rect.fromLTWH(0.02, 0.18, 0.30, 0.48)),
            _RedactZone('Date of Birth', Rect.fromLTWH(0.30, 0.60, 0.42, 0.08)),
            _RedactZone('Address Block', Rect.fromLTWH(0.30, 0.70, 0.62, 0.10)),
          ],
        _DocType.aadhaarBack => const [
            _RedactZone('Address Block', Rect.fromLTWH(0.05, 0.25, 0.78, 0.38)),
            _RedactZone('QR Code', Rect.fromLTWH(0.68, 0.50, 0.30, 0.45)),
          ],
        _DocType.panCard => const [
            _RedactZone('PAN Number', Rect.fromLTWH(0.35, 0.34, 0.52, 0.12)),
            _RedactZone('Name', Rect.fromLTWH(0.35, 0.50, 0.55, 0.12)),
            _RedactZone("Father's Name", Rect.fromLTWH(0.35, 0.64, 0.55, 0.12)),
            _RedactZone('Date of Birth', Rect.fromLTWH(0.35, 0.78, 0.36, 0.12)),
          ],
        _DocType.voterIdFront => const [
            _RedactZone('Voter ID Number', Rect.fromLTWH(0.38, 0.18, 0.55, 0.10)),
            _RedactZone('Address / Ward', Rect.fromLTWH(0.10, 0.55, 0.82, 0.22)),
          ],
        _DocType.passport => const [
            _RedactZone('Passport Number', Rect.fromLTWH(0.38, 0.12, 0.50, 0.10)),
            _RedactZone('Date of Birth', Rect.fromLTWH(0.38, 0.42, 0.40, 0.10)),
            _RedactZone('MRZ Line 1', Rect.fromLTWH(0.00, 0.80, 1.00, 0.10)),
            _RedactZone('MRZ Line 2', Rect.fromLTWH(0.00, 0.90, 1.00, 0.10)),
          ],
      };
}
