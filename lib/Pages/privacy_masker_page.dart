import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../Services/draft_persistence_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/wasm_document_service.dart';

class PrivacyMaskerPage extends StatefulWidget {
  const PrivacyMaskerPage({super.key});

  @override
  State<PrivacyMaskerPage> createState() => _PrivacyMaskerPageState();
}

class _PrivacyMaskerPageState extends State<PrivacyMaskerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Privacy Masker ─────────────────────────────────────────────────────────
  PickedFileData? _sourceFile;
  ui.Image? _decodedImage;
  final List<Rect> _maskRects = [];   // normalised 0..1 fractions of display area
  Offset? _dragStart;
  Rect? _activeDrag;
  final GlobalKey _canvasRepaintKey = GlobalKey();
  bool _isExporting = false;
  String _maskerStatus = 'Upload a photo or document image to start masking.';

  // ── QR Generator ───────────────────────────────────────────────────────────
  final TextEditingController _qrInputCtrl = TextEditingController();
  String _qrContent = '';
  double _qrSize = 220;
  _QrScheme _qrScheme = _QrScheme.url;
  _QrColorScheme _qrColorScheme = _QrColorScheme.blackOnWhite;
  final GlobalKey _qrRepaintKey = GlobalKey();
  bool _isDownloadingQr = false;
  String _qrStatus = 'Enter a URL, phone number, or text to generate a QR code.';

  // ── Draft persistence ──────────────────────────────────────────────────────
  Timer? _qrSaveTimer;
  Timer? _maskSaveTimer;
  DateTime? _qrLastSaved;
  DateTime? _masksLastSaved;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _restoreQrDraft();
    _restoreMaskDraft();
    _qrInputCtrl.addListener(() {
      setState(() => _qrContent = _buildQrPayload(_qrInputCtrl.text.trim()));
      _scheduleQrSave();
    });
  }

  @override
  void dispose() {
    _qrSaveTimer?.cancel();
    _maskSaveTimer?.cancel();
    _tabs.dispose();
    _qrInputCtrl.dispose();
    _decodedImage?.dispose();
    super.dispose();
  }

  // ── QR draft ───────────────────────────────────────────────────────────────

  void _scheduleQrSave() {
    _qrSaveTimer?.cancel();
    _qrSaveTimer = Timer(const Duration(milliseconds: 800), _saveQrDraft);
  }

  void _saveQrDraft() {
    DraftPersistenceService.saveQrDraft(
      text: _qrInputCtrl.text.trim(),
      scheme: _qrScheme.name,
      size: _qrSize,
      colorScheme: _qrColorScheme.name,
    );
    if (mounted) setState(() => _qrLastSaved = DateTime.now());
  }

  void _restoreQrDraft() {
    final draft = DraftPersistenceService.loadQrDraft();
    if (draft == null) return;
    final text = draft['text'] as String? ?? '';
    final schemeName = draft['scheme'] as String? ?? _QrScheme.url.name;
    final size = (draft['size'] as num? ?? 220).toDouble();
    final colorName = draft['colorScheme'] as String? ?? _QrColorScheme.blackOnWhite.name;
    final savedAt = DateTime.tryParse(draft['savedAt'] as String? ?? '');

    _qrInputCtrl.text = text;
    setState(() {
      _qrScheme = _QrScheme.values.byName(schemeName);
      _qrSize = size.clamp(160, 400);
      _qrColorScheme = _QrColorScheme.values.byName(colorName);
      _qrContent = _buildQrPayload(text);
      _qrLastSaved = savedAt;
      if (savedAt != null) _qrStatus = 'Draft restored (saved ${DraftPersistenceService.relativeTime(savedAt)}).';
    });
  }

  // ── Mask draft ─────────────────────────────────────────────────────────────

  void _scheduleMaskSave() {
    _maskSaveTimer?.cancel();
    _maskSaveTimer = Timer(const Duration(milliseconds: 800), _saveMaskDraft);
  }

  void _saveMaskDraft() {
    if (_maskRects.isEmpty) return;
    DraftPersistenceService.saveMaskDraft(rects: _maskRects);
    if (mounted) setState(() => _masksLastSaved = DateTime.now());
  }

  void _restoreMaskDraft() {
    final saved = DraftPersistenceService.loadMaskDraft();
    if (saved == null || saved.rects.isEmpty) return;
    setState(() {
      _maskRects.addAll(saved.rects);
      _masksLastSaved = saved.savedAt;
      _maskerStatus =
          '${saved.rects.length} mask zone(s) restored from last session (${DraftPersistenceService.relativeTime(saved.savedAt)}). '
          'Upload your image again to view them on the canvas.';
    });
  }

  // ── Masker: image loading ──────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked == null || !mounted) return;

    final codec = await ui.instantiateImageCodec(picked.bytes);
    final frame = await codec.getNextFrame();
    _decodedImage?.dispose();

    setState(() {
      _sourceFile = picked;
      _decodedImage = frame.image;
      _maskRects.clear();
      _maskerStatus = 'Image loaded: ${picked.name}. Draw boxes or use presets to mask sensitive data.';
    });
  }

  // ── Masker: drag-to-draw normalised rect ──────────────────────────────────

  void _onPanStart(DragStartDetails d, Size canvasSize) {
    _dragStart = _normalise(d.localPosition, canvasSize);
  }

  void _onPanUpdate(DragUpdateDetails d, Size canvasSize) {
    final end = _normalise(d.localPosition, canvasSize);
    setState(() => _activeDrag = _rectFromCorners(_dragStart!, end));
  }

  void _onPanEnd(DragEndDetails _) {
    if (_activeDrag != null && _activeDrag!.width > 0.01 && _activeDrag!.height > 0.01) {
      setState(() {
        _maskRects.add(_activeDrag!);
        _maskerStatus = '${_maskRects.length} mask zone(s) applied. Add more or download.';
      });
      _scheduleMaskSave();
    }
    _dragStart = null;
    setState(() => _activeDrag = null);
  }

  // ── Masker: preset zones (normalised for typical document layouts) ─────────

  void _addPreset(_MaskPreset preset) {
    setState(() {
      _maskRects.add(preset.rect);
      _maskerStatus = '"${preset.label}" zone masked. ${_maskRects.length} zone(s) total.';
    });
    _scheduleMaskSave();
  }

  void _removeLastMask() {
    if (_maskRects.isEmpty) return;
    setState(() {
      _maskRects.removeLast();
      _maskerStatus = _maskRects.isEmpty
          ? 'All masks cleared.'
          : '${_maskRects.length} zone(s) remaining.';
    });
    _scheduleMaskSave();
  }

  // ── Masker: export ────────────────────────────────────────────────────────

  Future<void> _exportMasked() async {
    if (_decodedImage == null) return;
    setState(() {
      _isExporting = true;
      _maskerStatus = 'Rendering masked image…';
    });

    try {
      final boundary = _canvasRepaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Canvas not ready.');

      // Render at 2× for higher fidelity output
      final img = await boundary.toImage(pixelRatio: 2.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data == null) throw StateError('Image encoding failed.');

      final bytes = data.buffer.asUint8List();
      WasmDocumentService.triggerBrowserDownload(
        bytes: bytes,
        fileName: 'masked_${_sourceFile?.name ?? 'image'}.png',
        mimeType: 'image/png',
      );

      if (mounted) {
        setState(() => _maskerStatus = 'Downloaded — masked image saved as PNG.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _maskerStatus = 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── QR: build payload with scheme prefix ───────────────────────────────────

  String _buildQrPayload(String raw) {
    if (raw.isEmpty) return '';
    switch (_qrScheme) {
      case _QrScheme.url:
        if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
        return 'https://$raw';
      case _QrScheme.phone:
        return 'tel:$raw';
      case _QrScheme.email:
        return 'mailto:$raw';
      case _QrScheme.whatsapp:
        final num = raw.replaceAll(RegExp(r'\D'), '');
        return 'https://wa.me/$num';
      case _QrScheme.text:
        return raw;
    }
  }

  // ── QR: export as PNG ─────────────────────────────────────────────────────

  Future<void> _downloadQr() async {
    if (_qrContent.isEmpty) return;
    setState(() {
      _isDownloadingQr = true;
      _qrStatus = 'Rendering QR code…';
    });

    try {
      final boundary = _qrRepaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('QR canvas not ready.');

      final img = await boundary.toImage(pixelRatio: 3.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data == null) throw StateError('QR encoding failed.');

      WasmDocumentService.triggerBrowserDownload(
        bytes: data.buffer.asUint8List(),
        fileName: 'qr_code_getreadyjob.png',
        mimeType: 'image/png',
      );

      if (mounted) setState(() => _qrStatus = 'QR code downloaded as high-res PNG.');
    } catch (e) {
      if (mounted) setState(() => _qrStatus = 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _isDownloadingQr = false);
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static Offset _normalise(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  static Rect _rectFromCorners(Offset a, Offset b) => Rect.fromLTRB(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
        a.dx > b.dx ? a.dx : b.dx,
        a.dy > b.dy ? a.dy : b.dy,
      );

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B45),
        foregroundColor: Colors.white,
        title: const Text('Privacy & Utility Masker'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF60A5FA),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.shield_rounded, size: 18), text: 'Privacy Masker'),
            Tab(icon: Icon(Icons.qr_code_2_rounded, size: 18), text: 'QR Generator'),
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
          children: [
            _buildMaskerTab(),
            _buildQrTab(),
          ],
        ),
      ),
    );
  }

  // ── Privacy Masker tab ─────────────────────────────────────────────────────

  Widget _buildMaskerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF1A2B45),
                title: 'Privacy Masker — Local Redaction',
                body: 'Black-out Aadhaar numbers, PAN details, photos, or any sensitive field. '
                    'All processing happens in your browser — nothing is uploaded.',
              ),
              const SizedBox(height: 14),

              // Upload
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading('Source Image'),
                    const SizedBox(height: 10),
                    if (_sourceFile == null)
                      _dropZonePlaceholder(
                        'Upload a JPG, PNG, or WEBP of your document',
                        onTap: _pickImage,
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.image_rounded, color: Color(0xFF0E3A66)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _sourceFile!.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(_sourceFile == null ? 'Upload Image' : 'Replace Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B45),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_sourceFile != null)
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _sourceFile = null;
                              _decodedImage?.dispose();
                              _decodedImage = null;
                              _maskRects.clear();
                              _maskerStatus = 'Cleared. Upload a new image to start.';
                            }),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_decodedImage != null) ...[
                const SizedBox(height: 14),

                // Preset zones
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeading('Quick Mask Presets'),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap a preset to black-out that typical zone. Positions are approximate — use freehand drawing to refine.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AADHAAR CARD',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _aadhaarPresets.map((p) => _presetChip(p)).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PAN CARD',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _panPresets.map((p) => _presetChip(p)).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'GENERAL',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _generalPresets.map((p) => _presetChip(p)).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Canvas
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _SectionHeading('Canvas (drag to draw custom mask)'),
                          const Spacer(),
                          if (_maskRects.isNotEmpty)
                            TextButton.icon(
                              onPressed: _removeLastMask,
                              icon: const Icon(Icons.undo_rounded, size: 15),
                              label: const Text('Undo Last'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                            ),
                          if (_maskRects.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _maskRects.clear();
                                _maskerStatus = 'All masks cleared.';
                              }),
                              icon: const Icon(Icons.delete_outline_rounded, size: 15),
                              label: const Text('Clear All'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF9F1239)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxW = constraints.maxWidth;
                          final imgW = _decodedImage!.width.toDouble();
                          final imgH = _decodedImage!.height.toDouble();
                          final displayH = (maxW * imgH / imgW).clamp(180.0, 520.0);

                          return RepaintBoundary(
                            key: _canvasRepaintKey,
                            child: SizedBox(
                              width: maxW,
                              height: displayH,
                              child: GestureDetector(
                                onPanStart: (d) => _onPanStart(d, Size(maxW, displayH)),
                                onPanUpdate: (d) => _onPanUpdate(d, Size(maxW, displayH)),
                                onPanEnd: _onPanEnd,
                                child: CustomPaint(
                                  painter: _MaskPainter(
                                    image: _decodedImage!,
                                    masks: _maskRects,
                                    activeDrag: _activeDrag,
                                  ),
                                  size: Size(maxW, displayH),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_maskRects.length} mask zone(s) active',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Status + export
                if (_masksLastSaved != null) ...[
                  _savedIndicator(_masksLastSaved!, onClear: () {
                    DraftPersistenceService.clearMaskDraft();
                    setState(() => _masksLastSaved = null);
                  }),
                  const SizedBox(height: 8),
                ],
                _statusRow(_maskerStatus),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isExporting || _maskRects.isEmpty) ? null : _exportMasked,
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded),
                    label: Text(_isExporting ? 'Exporting…' : 'Download Masked Image (PNG)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2B45),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                _statusRow(_maskerStatus),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(_MaskPreset preset) {
    return ActionChip(
      avatar: Icon(preset.icon, size: 14, color: const Color(0xFF1A2B45)),
      label: Text(preset.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      onPressed: () => _addPreset(preset),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFB8D0ED)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ── QR Generator tab ───────────────────────────────────────────────────────

  Widget _buildQrTab() {
    final colors = _qrColorScheme.colors;
    final hasContent = _qrContent.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.qr_code_2_rounded,
                iconColor: const Color(0xFF0A66C2),
                title: 'QR Code Generator — Local & Free',
                body: 'Generate QR codes for URLs, phone numbers, emails, or plain text. '
                    'Download as a high-resolution PNG ready for posters and print.',
              ),
              const SizedBox(height: 14),

              // Input
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading('Content'),
                    const SizedBox(height: 10),
                    // Scheme chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _QrScheme.values.map((s) {
                        final active = _qrScheme == s;
                        return ChoiceChip(
                          label: Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          avatar: Icon(s.icon, size: 14),
                          selected: active,
                          onSelected: (_) {
                            setState(() {
                              _qrScheme = s;
                              _qrContent = _buildQrPayload(_qrInputCtrl.text.trim());
                            });
                            _scheduleQrSave();
                          },
                          selectedColor: const Color(0xFF1A2B45),
                          labelStyle: TextStyle(color: active ? Colors.white : const Color(0xFF0F172A)),
                          iconTheme: IconThemeData(color: active ? Colors.white : const Color(0xFF475569)),
                          side: const BorderSide(color: Color(0xFFB8D0ED)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qrInputCtrl,
                      decoration: InputDecoration(
                        labelText: _qrScheme.hint,
                        hintText: _qrScheme.placeholder,
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(_qrScheme.icon, size: 18),
                        suffixIcon: _qrInputCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _qrInputCtrl.clear();
                                  setState(() => _qrContent = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Settings
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading('Style'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Size', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Text('${_qrSize.round()} px', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    Slider(
                      value: _qrSize,
                      min: 160,
                      max: 400,
                      divisions: 12,
                      activeColor: const Color(0xFF1A2B45),
                      onChanged: (v) {
                        setState(() => _qrSize = v);
                        _scheduleQrSave();
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('Colour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _QrColorScheme.values.map((cs) {
                        final active = _qrColorScheme == cs;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _qrColorScheme = cs);
                            _scheduleQrSave();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.colors.$1,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active ? const Color(0xFF0A66C2) : const Color(0xFFD0DFF0),
                                width: active ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              cs.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.colors.$2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Preview
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading('Preview'),
                    const SizedBox(height: 12),
                    if (!hasContent)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Enter content above to see the QR code.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: RepaintBoundary(
                          key: _qrRepaintKey,
                          child: Container(
                            color: colors.$1,
                            padding: const EdgeInsets.all(16),
                            child: QrImageView(
                              data: _qrContent,
                              version: QrVersions.auto,
                              size: _qrSize,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: colors.$2,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: colors.$2,
                              ),
                              backgroundColor: colors.$1,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (hasContent)
                      Text(
                        'Content: $_qrContent',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_qrLastSaved != null) _savedIndicator(_qrLastSaved!, onClear: () {
                DraftPersistenceService.clearQrDraft();
                setState(() => _qrLastSaved = null);
              }),
              if (_qrLastSaved != null) const SizedBox(height: 8),
              _statusRow(_qrStatus),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!hasContent || _isDownloadingQr) ? null : _downloadQr,
                  icon: _isDownloadingQr
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded),
                  label: Text(_isDownloadingQr ? 'Downloading…' : 'Download QR as PNG (High-Res)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A66C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _savedIndicator(DateTime savedAt, {required VoidCallback onClear}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Text(
            'Draft saved ${DraftPersistenceService.relativeTime(savedAt)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required Color iconColor, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
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

  Widget _dropZonePlaceholder(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8D0ED), style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            const Icon(Icons.upload_file_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB8D0ED)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF475569)),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45))),
          ],
        ),
      );
}

// ── Mask painter ───────────────────────────────────────────────────────────────

class _MaskPainter extends CustomPainter {
  final ui.Image image;
  final List<Rect> masks;
  final Rect? activeDrag;

  const _MaskPainter({required this.image, required this.masks, this.activeDrag});

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.contain);

    final blackPaint = Paint()..color = Colors.black;
    for (final r in masks) {
      canvas.drawRect(_denorm(r, size), blackPaint);
    }

    if (activeDrag != null) {
      // Live drag preview with slight transparency
      canvas.drawRect(_denorm(activeDrag!, size), Paint()..color = Colors.black.withValues(alpha: 0.75));
    }
  }

  static Rect _denorm(Rect r, Size s) => Rect.fromLTWH(
        r.left * s.width,
        r.top * s.height,
        r.width * s.width,
        r.height * s.height,
      );

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.masks != masks || old.activeDrag != activeDrag || old.image != image;
}

// ── Shared stateless widget ────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      );
}

// ── Mask preset data ───────────────────────────────────────────────────────────

class _MaskPreset {
  final String label;
  final Rect rect;  // normalised 0..1 fractions
  final IconData icon;

  const _MaskPreset(this.label, this.rect, this.icon);
}

// Aadhaar card (portrait) approximate zones
const List<_MaskPreset> _aadhaarPresets = [
  _MaskPreset('Aadhaar Number (bottom)',  Rect.fromLTWH(0.12, 0.82, 0.65, 0.09), Icons.pin_rounded),
  _MaskPreset('Photo Area',              Rect.fromLTWH(0.02, 0.18, 0.30, 0.48), Icons.face_rounded),
  _MaskPreset('Date of Birth',           Rect.fromLTWH(0.30, 0.60, 0.42, 0.08), Icons.cake_rounded),
  _MaskPreset('Address Block',           Rect.fromLTWH(0.30, 0.70, 0.62, 0.10), Icons.home_rounded),
];

// PAN card (landscape) approximate zones
const List<_MaskPreset> _panPresets = [
  _MaskPreset('PAN Number',   Rect.fromLTWH(0.35, 0.34, 0.50, 0.12), Icons.credit_card_rounded),
  _MaskPreset('Name',         Rect.fromLTWH(0.35, 0.50, 0.55, 0.12), Icons.person_rounded),
  _MaskPreset('Father Name',  Rect.fromLTWH(0.35, 0.64, 0.55, 0.12), Icons.supervisor_account_rounded),
  _MaskPreset('Date of Birth',Rect.fromLTWH(0.35, 0.78, 0.36, 0.12), Icons.cake_rounded),
];

// Generic zones for any document
const List<_MaskPreset> _generalPresets = [
  _MaskPreset('Top-left corner',   Rect.fromLTWH(0.00, 0.00, 0.40, 0.18), Icons.crop_free_rounded),
  _MaskPreset('Top-right corner',  Rect.fromLTWH(0.60, 0.00, 0.40, 0.18), Icons.crop_free_rounded),
  _MaskPreset('Bottom strip',      Rect.fromLTWH(0.00, 0.85, 1.00, 0.15), Icons.table_rows_rounded),
  _MaskPreset('Centre strip',      Rect.fromLTWH(0.00, 0.42, 1.00, 0.16), Icons.table_rows_rounded),
];

// ── QR scheme ──────────────────────────────────────────────────────────────────

enum _QrScheme {
  url,
  phone,
  email,
  whatsapp,
  text;

  String get label => switch (this) {
        _QrScheme.url => 'URL',
        _QrScheme.phone => 'Phone',
        _QrScheme.email => 'Email',
        _QrScheme.whatsapp => 'WhatsApp',
        _QrScheme.text => 'Plain Text',
      };

  String get hint => switch (this) {
        _QrScheme.url => 'Website URL',
        _QrScheme.phone => 'Phone number',
        _QrScheme.email => 'Email address',
        _QrScheme.whatsapp => 'WhatsApp number',
        _QrScheme.text => 'Any text',
      };

  String get placeholder => switch (this) {
        _QrScheme.url => 'getreadyjob.com',
        _QrScheme.phone => '+91 98765 43210',
        _QrScheme.email => 'hello@getreadyjob.com',
        _QrScheme.whatsapp => '+91 98765 43210',
        _QrScheme.text => 'Your text here…',
      };

  IconData get icon => switch (this) {
        _QrScheme.url => Icons.link_rounded,
        _QrScheme.phone => Icons.phone_rounded,
        _QrScheme.email => Icons.email_rounded,
        _QrScheme.whatsapp => Icons.chat_rounded,
        _QrScheme.text => Icons.text_fields_rounded,
      };
}

// ── QR colour scheme ───────────────────────────────────────────────────────────

enum _QrColorScheme {
  blackOnWhite,
  navyOnWhite,
  whiteOnNavy,
  blackOnAmber;

  // ($background, $foreground)
  (Color, Color) get colors => switch (this) {
        _QrColorScheme.blackOnWhite => (Colors.white, Colors.black),
        _QrColorScheme.navyOnWhite  => (Colors.white, const Color(0xFF1A2B45)),
        _QrColorScheme.whiteOnNavy  => (const Color(0xFF1A2B45), Colors.white),
        _QrColorScheme.blackOnAmber => (const Color(0xFFFFF9C4), Colors.black),
      };

  String get label => switch (this) {
        _QrColorScheme.blackOnWhite => 'Black / White',
        _QrColorScheme.navyOnWhite  => 'Navy / White',
        _QrColorScheme.whiteOnNavy  => 'White / Navy',
        _QrColorScheme.blackOnAmber => 'Black / Amber',
      };
}
