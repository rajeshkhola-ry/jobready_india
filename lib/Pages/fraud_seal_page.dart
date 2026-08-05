import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../Services/analytics_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/wasm_document_service.dart';

class FraudSealPage extends StatefulWidget {
  const FraudSealPage({super.key});

  @override
  State<FraudSealPage> createState() => _FraudSealPageState();
}

class _FraudSealPageState extends State<FraudSealPage> {
  // ── Document ───────────────────────────────────────────────────────────────
  PickedFileData? _docFile;
  ui.Image? _docImage;

  // ── Watermark ──────────────────────────────────────────────────────────────
  bool _watermarkEnabled = true;
  final TextEditingController _purposeCtrl =
      TextEditingController(text: 'FOR BANK SUBMISSION ONLY');
  final TextEditingController _recipientCtrl = TextEditingController();
  _WmColor _wmColor = _WmColor.red;
  double _wmOpacity = 0.18;

  // ── Blur / Blackout brush ──────────────────────────────────────────────────
  _BrushMode _brushMode = _BrushMode.blur;
  final List<_BrushZone> _zones = [];
  Offset? _dragStart;
  Rect? _activeDrag;

  // ── Authenticity seal ──────────────────────────────────────────────────────
  bool _sealEnabled = true;
  late final String _sealRef;
  late final String _sealTimestamp;

  // ── Canvas / export ────────────────────────────────────────────────────────
  final GlobalKey _canvasKey = GlobalKey();
  bool _isExporting = false;
  String _status = 'Upload a document image to begin.';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _sealRef = 'GRJ-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase().padLeft(8, '0').substring(0, 8)}';
    _sealTimestamp = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _purposeCtrl.addListener(() => setState(() {}));
    _recipientCtrl.addListener(() => setState(() {}));
    AnalyticsService.trackToolOpen('fraud_seal');
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _recipientCtrl.dispose();
    _docImage?.dispose();
    super.dispose();
  }

  // ── Document pick ──────────────────────────────────────────────────────────

  Future<void> _pickDocument() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(picked.bytes);
    final frame = await codec.getNextFrame();
    _docImage?.dispose();
    setState(() {
      _docFile = picked;
      _docImage = frame.image;
      _zones.clear();
      _status = 'Document loaded. Apply watermark, brush zones, or export with seal.';
    });
  }

  // ── Brush gestures ─────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d, Size s) {
    _dragStart = _norm(d.localPosition, s);
  }

  void _onPanUpdate(DragUpdateDetails d, Size s) {
    setState(() => _activeDrag = _corners(_dragStart!, _norm(d.localPosition, s)));
  }

  void _onPanEnd(DragEndDetails _) {
    if (_activeDrag != null &&
        _activeDrag!.width > 0.008 &&
        _activeDrag!.height > 0.008) {
      setState(() {
        _zones.add(_BrushZone(_activeDrag!, _brushMode));
        _status = '${_zones.length} zone(s) applied.';
      });
    }
    _dragStart = null;
    setState(() => _activeDrag = null);
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _exportDocument() async {
    setState(() {
      _isExporting = true;
      _status = 'Rendering secure document at high resolution…';
    });
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Canvas not ready.');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Encoding failed.');

      final purpose = _purposeCtrl.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      WasmDocumentService.triggerBrowserDownload(
        bytes: data.buffer.asUint8List(),
        fileName: 'sealed_${purpose.isEmpty ? 'document' : purpose}_$_sealRef.png',
        mimeType: 'image/png',
      );
      AnalyticsService.trackToolAction('fraud_seal', 'export');
      if (mounted) {
        setState(() => _status = 'Exported with Purpose Seal [$_sealRef]. ✓');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Offset _norm(Offset p, Size s) =>
      Offset((p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  static Rect _corners(Offset a, Offset b) => Rect.fromLTRB(
        math.min(a.dx, b.dx), math.min(a.dy, b.dy),
        math.max(a.dx, b.dx), math.max(a.dy, b.dy));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1F3D),
        foregroundColor: Colors.white,
        title: const Text('Purpose-Lock & Fraud-Check Seal'),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_docImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportDocument,
                icon: _isExporting
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.shield_moon_rounded, size: 16),
                label: Text(_isExporting ? 'Sealing…' : 'Export Sealed Doc'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCD34D),
                  foregroundColor: const Color(0xFF0A1F3D),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final settingsPanel = _buildSettingsPanel();
        final canvasPanel = _buildCanvasPanel();

        if (wide) {
          return Row(children: [
            SizedBox(
              width: 320,
              child: Container(
                color: const Color(0xFFEDF3FA),
                child: settingsPanel,
              ),
            ),
            Expanded(child: canvasPanel),
          ]);
        }
        return Column(children: [
          SizedBox(
            height: constraints.maxHeight * 0.40,
            child: Container(color: const Color(0xFFEDF3FA), child: settingsPanel),
          ),
          Expanded(child: canvasPanel),
        ]);
      }),
    );
  }

  // ── Settings panel ─────────────────────────────────────────────────────────

  Widget _buildSettingsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload
          _card(
            icon: Icons.upload_file_rounded,
            color: const Color(0xFF0A1F3D),
            title: 'Document',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_docFile == null)
                  _dropTile('Upload bank statement, letter, or document image',
                      onTap: _pickDocument)
                else
                  _fileTile(_docFile!.name),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickDocument,
                    icon: const Icon(Icons.upload_rounded, size: 15),
                    label: Text(_docFile == null ? 'Upload Document' : 'Replace'),
                    style: _btn(const Color(0xFF0A1F3D)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Watermark
          _card(
            icon: Icons.water_rounded,
            color: const Color(0xFF991B1B),
            title: 'Purpose Watermark',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Switch(
                    value: _watermarkEnabled,
                    onChanged: (v) => setState(() => _watermarkEnabled = v),
                    activeColor: const Color(0xFF0A1F3D),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
                if (_watermarkEnabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _purposeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Purpose text',
                      hintText: 'FOR HDFC BANK ONLY',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _recipientCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Recipient / Institution',
                      hintText: 'HDFC Bank Ltd.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  const Text('Colour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _WmColor.values.map((c) {
                      final active = c == _wmColor;
                      return GestureDetector(
                        onTap: () => setState(() => _wmColor = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.swatch.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? c.swatch : const Color(0xFFCDD9E8),
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Text(c.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: c.swatch)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Opacity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    Text('${(_wmOpacity * 100).round()}%',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                  Slider(
                    value: _wmOpacity,
                    min: 0.05, max: 0.50,
                    activeColor: const Color(0xFF0A1F3D),
                    onChanged: (v) => setState(() => _wmOpacity = v),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Brush tool
          _card(
            icon: Icons.edit_rounded,
            color: const Color(0xFF1E5B88),
            title: 'Blur / Blackout Brush',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: _modeBtn(
                      label: '🔵  Blur',
                      active: _brushMode == _BrushMode.blur,
                      onTap: () => setState(() => _brushMode = _BrushMode.blur),
                      activeColor: const Color(0xFF1E5B88),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeBtn(
                      label: '⬛  Blackout',
                      active: _brushMode == _BrushMode.blackout,
                      onTap: () => setState(() => _brushMode = _BrushMode.blackout),
                      activeColor: const Color(0xFF111827),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                if (_zones.isNotEmpty) ...[
                  Text('${_zones.length} zone(s) applied.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() { if (_zones.isNotEmpty) _zones.removeLast(); }),
                        icon: const Icon(Icons.undo_rounded, size: 14),
                        label: const Text('Undo', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _zones.clear()),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text('Clear', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9F1239)),
                      ),
                    ),
                  ]),
                ] else
                  const Text(
                    'Drag on the document canvas to apply blur or blackout zones over account numbers, amounts, or any sensitive data.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.5),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Seal
          _card(
            icon: Icons.shield_moon_rounded,
            color: const Color(0xFF065F46),
            title: 'Authenticity Seal',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Embed seal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Switch(
                    value: _sealEnabled,
                    onChanged: (v) => setState(() => _sealEnabled = v),
                    activeColor: const Color(0xFF065F46),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REF: $_sealRef',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46), fontFamily: 'Courier New')),
                      Text('Sealed: $_sealTimestamp',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF166534))),
                      const SizedBox(height: 2),
                      const Text('Seal is embedded bottom-right. Generated locally — no data uploaded.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Status
          _statusRow(_status),
        ],
      ),
    );
  }

  // ── Canvas panel ───────────────────────────────────────────────────────────

  Widget _buildCanvasPanel() {
    return Container(
      color: const Color(0xFFCBD5E1),
      child: Center(
        child: _docImage == null
            ? _emptyCanvas()
            : LayoutBuilder(builder: (ctx, bc) {
                final cw = bc.maxWidth - 32;
                final imgW = _docImage!.width.toDouble();
                final imgH = _docImage!.height.toDouble();
                final ch = (cw * imgH / imgW).clamp(200.0, bc.maxHeight - 32);
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: SizedBox(
                      width: cw, height: ch,
                      child: GestureDetector(
                        onPanStart: (d) => _onPanStart(d, Size(cw, ch)),
                        onPanUpdate: (d) => _onPanUpdate(d, Size(cw, ch)),
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _SealPainter(
                            image: _docImage!,
                            zones: List.unmodifiable(_zones),
                            activeDrag: _activeDrag,
                            brushMode: _brushMode,
                            watermarkEnabled: _watermarkEnabled,
                            purpose: _purposeCtrl.text.trim().toUpperCase(),
                            recipient: _recipientCtrl.text.trim(),
                            wmColor: _wmColor,
                            wmOpacity: _wmOpacity,
                            sealEnabled: _sealEnabled,
                            sealRef: _sealRef,
                            sealTimestamp: _sealTimestamp,
                          ),
                          size: Size(cw, ch),
                        ),
                      ),
                    ),
                  ),
                );
              }),
      ),
    );
  }

  Widget _emptyCanvas() => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.upload_file_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('Upload a document to start',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          SizedBox(height: 4),
          Text('Bank statement · Letter · Certificate · Any document',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      );

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _card({required IconData icon, required Color color, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE7F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _dropTile(String label, {required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB8D0ED)),
          ),
          child: Column(children: [
            const Icon(Icons.upload_rounded, size: 24, color: Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _fileTile(String name) => Row(children: [
        const Icon(Icons.description_rounded, size: 14, color: Color(0xFF0E3A66)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ]);

  Widget _statusRow(String msg) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB8D0ED)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF475569)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.45)),
          ),
        ]),
      );

  Widget _modeBtn({required String label, required bool active, required VoidCallback onTap, required Color activeColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : const Color(0xFFCDD9E8)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF334155))),
      ),
    );
  }

  ButtonStyle _btn(Color c) => ElevatedButton.styleFrom(
        backgroundColor: c,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      );
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _SealPainter extends CustomPainter {
  final ui.Image image;
  final List<_BrushZone> zones;
  final Rect? activeDrag;
  final _BrushMode brushMode;
  final bool watermarkEnabled;
  final String purpose;
  final String recipient;
  final _WmColor wmColor;
  final double wmOpacity;
  final bool sealEnabled;
  final String sealRef;
  final String sealTimestamp;

  const _SealPainter({
    required this.image,
    required this.zones,
    required this.activeDrag,
    required this.brushMode,
    required this.watermarkEnabled,
    required this.purpose,
    required this.recipient,
    required this.wmColor,
    required this.wmOpacity,
    required this.sealEnabled,
    required this.sealRef,
    required this.sealTimestamp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgSrc = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final imgDst = _fitRect(image, size);

    // 1 — Base image
    canvas.drawImageRect(image, imgSrc, imgDst, Paint());

    // 2 — Blur zones (re-draw image with blur filter, clipped to zone)
    for (final z in zones.where((z) => z.mode == _BrushMode.blur)) {
      final r = _dn(z.rect, size);
      canvas.save();
      canvas.clipRect(r);
      canvas.drawImageRect(
        image, imgSrc, imgDst,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      );
      canvas.restore();
    }

    // 3 — Blackout zones
    final blackPaint = Paint()..color = Colors.black;
    for (final z in zones.where((z) => z.mode == _BrushMode.blackout)) {
      canvas.drawRect(_dn(z.rect, size), blackPaint);
    }

    // 4 — Active drag preview
    if (activeDrag != null) {
      final r = _dn(activeDrag!, size);
      final previewColor = brushMode == _BrushMode.blur
          ? const Color(0xFF1E5B88)
          : Colors.black;
      canvas.drawRect(r, Paint()..color = previewColor.withValues(alpha: 0.30));
      canvas.drawRect(r, Paint()
        ..color = previewColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // 5 — Watermark overlay
    if (watermarkEnabled && purpose.isNotEmpty) {
      _drawWatermark(canvas, size);
    }

    // 6 — Authenticity seal
    if (sealEnabled) {
      _drawSeal(canvas, size);
    }
  }

  // ── Watermark ────────────────────────────────────────────────────────────

  void _drawWatermark(Canvas canvas, Size size) {
    final color = wmColor.swatch.withValues(alpha: wmOpacity);
    final fontSize = (size.width * 0.038).clamp(10.0, 22.0);
    final line1 = purpose;
    final line2 = recipient.isNotEmpty ? 'RECIPIENT: ${recipient.toUpperCase()}' : '';
    final lineH = fontSize * 1.5;
    final tileH = (line2.isNotEmpty ? lineH * 2.6 : lineH * 1.8);
    final tileW = size.width * 0.80;

    canvas.save();
    // Tile diagonally: iterate over a grid covering the canvas
    for (double cx = -size.width; cx < size.width * 2; cx += tileW) {
      for (double cy = -size.height; cy < size.height * 2; cy += tileH * 2) {
        canvas.save();
        canvas.translate(cx + size.width / 2, cy + size.height / 2);
        canvas.rotate(-math.pi / 5.5); // ~-33°
        _paintWmLine(canvas, line1, fontSize, color, 0);
        if (line2.isNotEmpty) {
          _paintWmLine(canvas, line2, fontSize * 0.72, color, lineH * 1.3);
        }
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _paintWmLine(Canvas canvas, String text, double fontSize, Color color, double dy) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 1,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w800,
        letterSpacing: 1.1,
      ))
      ..addText(text);
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 9999));
    canvas.drawParagraph(para, Offset(-para.longestLine / 2, dy));
  }

  // ── Authenticity seal ─────────────────────────────────────────────────────

  void _drawSeal(Canvas canvas, Size size) {
    const padH = 10.0;
    const padV = 7.0;
    final fontSize = (size.width * 0.022).clamp(7.0, 13.0);
    final lineH = fontSize * 1.45;
    final lines = [
      '✓  GETREADYJOB · SECURE DOCUMENT',
      'PURPOSE: ${purpose.isEmpty ? '(not set)' : purpose}',
      if (recipient.isNotEmpty) 'RECIPIENT: ${recipient.toUpperCase()}',
      'REF: $sealRef   •   SEALED: $sealTimestamp',
      'Generated locally — no data uploaded to any server.',
    ];
    final boxW = (size.width * 0.72).clamp(180.0, 460.0);
    final boxH = lines.length * lineH + padV * 2 + 4;
    final boxL = size.width - boxW - 8;
    final boxT = size.height - boxH - 8;

    // Box background
    canvas.drawRect(
      Rect.fromLTWH(boxL, boxT, boxW, boxH),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    // Box border: outer dark, inner gold accent line
    canvas.drawRect(
      Rect.fromLTWH(boxL, boxT, boxW, boxH),
      Paint()
        ..color = const Color(0xFF0A1F3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRect(
      Rect.fromLTWH(boxL + 2, boxT + 2, boxW - 4, boxH - 4),
      Paint()
        ..color = const Color(0xFFFCD34D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Text lines
    double ty = boxT + padV;
    for (int i = 0; i < lines.length; i++) {
      final isHeader = i == 0;
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
        ..pushStyle(ui.TextStyle(
          color: isHeader ? const Color(0xFF0A1F3D) : const Color(0xFF334155),
          fontSize: isHeader ? fontSize : fontSize * 0.88,
          fontWeight: isHeader ? ui.FontWeight.w800 : ui.FontWeight.w400,
          letterSpacing: isHeader ? 0.6 : 0.2,
        ))
        ..addText(lines[i]);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: boxW - padH * 2));
      canvas.drawParagraph(para, Offset(boxL + padH, ty));
      ty += lineH;
    }
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  static Rect _fitRect(ui.Image img, Size size) {
    final imgAspect = img.width / img.height;
    final sizeAspect = size.width / size.height;
    double w, h, dx, dy;
    if (imgAspect > sizeAspect) {
      w = size.width; h = size.width / imgAspect; dx = 0; dy = (size.height - h) / 2;
    } else {
      h = size.height; w = size.height * imgAspect; dx = (size.width - w) / 2; dy = 0;
    }
    return Rect.fromLTWH(dx, dy, w, h);
  }

  static Rect _dn(Rect r, Size s) => Rect.fromLTWH(
      r.left * s.width, r.top * s.height, r.width * s.width, r.height * s.height);

  @override
  bool shouldRepaint(_SealPainter o) => true; // always repaint on any state change
}

// ── Data types ─────────────────────────────────────────────────────────────────

enum _BrushMode { blur, blackout }

class _BrushZone {
  final Rect rect;
  final _BrushMode mode;
  const _BrushZone(this.rect, this.mode);
}

enum _WmColor {
  red, navy, black, green;

  Color get swatch => switch (this) {
        _WmColor.red   => const Color(0xFFB91C1C),
        _WmColor.navy  => const Color(0xFF1E3A5F),
        _WmColor.black => const Color(0xFF111827),
        _WmColor.green => const Color(0xFF065F46),
      };

  String get label => switch (this) {
        _WmColor.red   => 'Red',
        _WmColor.navy  => 'Navy',
        _WmColor.black => 'Black',
        _WmColor.green => 'Green',
      };
}
