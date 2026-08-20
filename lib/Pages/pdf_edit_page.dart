import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:universal_html/html.dart' as html;

import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/ocr_quota_service.dart';
import '../Services/pdf_ocr_service.dart';
import '../Services/remote_ocr_service.dart';
import '../Services/upload_context_service.dart';
import '../Services/voice_command_service.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/tool_guidance_panel.dart';

enum _OverlayResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Highlighter presets exposed on the rich formatting toolbar - kept as
/// named constants so both the UI swatches and the DOCX `w:highlight`
/// exporter (which only accepts a fixed OOXML color-name palette) agree.
const int _highlightYellowArgb = 0xFFFFFF00;
const int _highlightGreenArgb = 0xFF00FF00;

/// A detected run of ORIGINAL vector text on the current page, in top-down
/// PDF point space (matches Syncfusion's Rect.fromLTWH convention directly).
class _PdfFragmentHit {
  const _PdfFragmentHit({required this.rect, required this.text, required this.charRects});
  final Rect rect;
  final String text;
  final List<Rect> charRects;
}

/// A paragraph/line detected by grouping raw text fragments (see
/// `_buildParagraphBlocks`) - the real MS-Word-like editing unit offered to
/// the user (never a single fragmented word) - with font size, weight, and
/// color already best-effort inherited from the original page.
class _DetectedBlock {
  const _DetectedBlock({
    required this.rect,
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.bold,
    required this.textColorArgb,
  });

  final Rect rect;
  final String text;
  final double fontSize;
  final sfpdf.PdfFontFamily fontFamily;
  final bool bold;
  final int textColorArgb;
}

/// A user-editable paragraph placed on the canvas: either a plain whiteout
/// box, or a rich-text paragraph (bold/italic/underline, size, color,
/// highlight) that dynamically reflows - re-wraps and grows/shrinks its own
/// height - as it is edited, and is re-typeset directly over the ORIGINAL
/// PDF page at export time (see `_buildExportedPdfBytes`), so anything
/// outside an edited block stays byte-for-byte the original PDF content.
class _PdfTextBlock {
  _PdfTextBlock({
    required this.id,
    required this.originalRect,
    required this.rect,
    required this.text,
    required this.fontSize,
    this.fontFamily = sfpdf.PdfFontFamily.helvetica,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.textColorArgb = 0xFF000000,
    this.highlightColorArgb,
    this.isWhiteoutOnly = false,
  });

  final String id;
  final Rect originalRect;
  Rect rect;
  String text;
  double fontSize;
  sfpdf.PdfFontFamily fontFamily;
  bool bold;
  bool italic;
  bool underline;
  int textColorArgb;
  int? highlightColorArgb;
  final bool isWhiteoutOnly;

  Color get textColor => Color(textColorArgb);
  Color? get highlightColor => highlightColorArgb == null ? null : Color(highlightColorArgb!);

  /// The area that must always be whited-out at export time, so a shrunk or
  /// moved edit can never leave a sliver of the original glyphs peeking out.
  Rect get maskRect => originalRect.expandToInclude(rect).inflate(1.5);
}

/// One rich-text run inside a DOCX paragraph (see `_buildFullDocumentParagraphs`).
class _DocxRun {
  const _DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.colorArgb = 0xFF000000,
    this.fontSize = 11,
    this.highlightName,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final int colorArgb;
  final double fontSize;
  final String? highlightName;
}

/// A small toggle-style icon button used by the rich formatting toolbar
/// (Bold/Italic/Underline) - highlighted when its attribute is active.
class _ToggleIconButton extends StatelessWidget {
  const _ToggleIconButton({required this.icon, required this.active, required this.onTap, required this.tooltip});

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1F4E79) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? const Color(0xFF1F4E79) : const Color(0xFFD1D5DB)),
          ),
          child: Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF374151)),
        ),
      ),
    );
  }
}

class PdfEditPage extends StatefulWidget {
  final String? initialFileName;
  final Uint8List? initialBytes;

  const PdfEditPage({
    super.key,
    this.initialFileName,
    this.initialBytes,
  });

  @override
  State<PdfEditPage> createState() => _PdfEditPageState();
}

class _PdfEditPageState extends State<PdfEditPage> {
  Uint8List? _selectedBytes;
  String? _selectedName;
  bool _isSaving = false;
  bool _isLoadingText = false;
  bool _isScanning = false;
  bool _isConvertingToSearchablePdf = false;
  String _loadStatus = 'Ready';
  double _scanProgress = 0.0;
  Timer? _progressTimer;

  pdfrx.PdfDocument? _pdfDoc;
  int _pageCount = 0;
  int _currentPageIndex = 0;
  bool _isRenderingPage = false;
  Uint8List? _currentPagePng;
  Size _currentPagePointSize = Size.zero;
  List<_PdfFragmentHit> _currentPageFragments = <_PdfFragmentHit>[];
  List<_DetectedBlock> _currentPageBlocks = <_DetectedBlock>[];
  static const double _renderScale = 2.0; // 2x for a crisp preview/edit surface
  final Map<int, List<_PdfTextBlock>> _pageOverlays = <int, List<_PdfTextBlock>>{};
  _PdfTextBlock? _selectedOverlay;
  int _overlayIdCounter = 0;
  final TextEditingController _overlayTextController = TextEditingController();

  final PdfOcrService _ocrService = const PdfOcrService();

  List<_PdfTextBlock> get _currentOverlays => _pageOverlays.putIfAbsent(_currentPageIndex, () => <_PdfTextBlock>[]);

  @override
  void initState() {
    super.initState();
    _selectedBytes = widget.initialBytes;
    _selectedName = widget.initialFileName;

    // Prefer a file dropped/browsed on the Homepage upload zone.
    if (_selectedBytes == null) {
      final cached = UploadContextService.getFirstCompatibleFile(['pdf']);
      if (cached != null) {
        _selectedBytes = cached.bytes;
        _selectedName = cached.name;
        _loadStatus = '✓ ${cached.name} loaded from workspace upload';
      }
    }

    // If still nothing, check for previously uploaded files
    if (_selectedBytes == null) {
      final storedFile = FileStorageService.getLatestFile();
      if (storedFile != null && _isPdfFile(storedFile.name)) {
        _selectedBytes = storedFile.getBytes();
        _selectedName = storedFile.name;
        _loadStatus = 'Loaded previously uploaded file: ${storedFile.name}';
      }
    }

    if (_selectedBytes != null) {
      _openDocumentForEditing();
    }

    _applyVoiceCommand();
  }

  // Editing inherently requires the user to decide what to change, so there is
  // no single well-defined "auto action" to run end-to-end here (unlike
  // compress/merge/split/etc). We still auto-load the file (above) and extract
  // its text automatically; this just confirms that to the user and clears
  // the pending voice-command signal so it doesn't leak into a later page.
  void _applyVoiceCommand() {
    final params = VoiceCommandService.consumePendingParameters();
    if (params.isEmpty) {
      return;
    }
    final autoExecute = params[VoiceCommandService.autoExecuteFlagKey] == true;
    if (autoExecute && _selectedBytes != null) {
      _loadStatus = 'Voice command: file loaded and text extracted. Edit the text, then Save & Download.';
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _overlayTextController.dispose();
    _pdfDoc?.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final files = await FilePickerService.pickMultipleFileData(
      allowedExtensions: const ['pdf'],
    );

    if (files.isEmpty) {
      return;
    }

    setState(() {
      _selectedBytes = files.first.bytes;
      _selectedName = files.first.name;
      _loadStatus = 'ℹ️ PDF loaded. Rendering page for editing…';
    });

    await _openDocumentForEditing();
  }

  void _clearUploadedFile() {
    _pdfDoc?.dispose();
    setState(() {
      _selectedBytes = null;
      _selectedName = null;
      _pdfDoc = null;
      _pageCount = 0;
      _currentPageIndex = 0;
      _currentPagePng = null;
      _currentPageFragments = <_PdfFragmentHit>[];
      _currentPageBlocks = <_DetectedBlock>[];
      _pageOverlays.clear();
      _selectedOverlay = null;
      _loadStatus = 'File removed. Upload a new PDF to continue.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded file removed.')),
    );
  }

  /// Opens the uploaded bytes with pdfrx (a real PDFium-backed renderer, not a
  /// text dump) so the ORIGINAL page can be shown pixel-for-pixel as the base
  /// layer, and resets any per-document editor state for the new file.
  Future<void> _openDocumentForEditing() async {
    final bytes = _selectedBytes;
    if (bytes == null) {
      return;
    }

    final previousDoc = _pdfDoc;

    setState(() {
      _isLoadingText = true;
      _loadStatus = 'Rendering original PDF for editing…';
    });

    try {
      final document = await pdfrx.PdfDocument.openData(bytes, sourceName: _selectedName ?? 'document.pdf');
      await previousDoc?.dispose();
      if (!mounted) {
        await document.dispose();
        return;
      }
      setState(() {
        _pdfDoc = document;
        _pageCount = document.pages.length;
        _currentPageIndex = 0;
        _pageOverlays.clear();
        _selectedOverlay = null;
      });
      await _renderCurrentPage();
      if (mounted) {
        setState(() {
          _loadStatus = 'Ready: tap any text to edit it in place, or add a text/whiteout box.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadStatus = 'Error: unable to open this PDF for visual editing ($e).';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingText = false;
        });
      }
    }
  }

  /// Renders the current page as a raster image (base layer, 100% original
  /// fidelity) and separately extracts its real vector text runs with
  /// positions, so each run can be tapped and edited in place.
  Future<void> _renderCurrentPage() async {
    final document = _pdfDoc;
    if (document == null || _currentPageIndex < 0 || _currentPageIndex >= document.pages.length) {
      return;
    }

    setState(() {
      _isRenderingPage = true;
      _selectedOverlay = null;
    });

    try {
      final page = document.pages[_currentPageIndex];
      final pixelWidth = (page.width * _renderScale).round();
      final pixelHeight = (page.height * _renderScale).round();

      final rendered = await page.render(fullWidth: pixelWidth.toDouble(), fullHeight: pixelHeight.toDouble());
      Uint8List? pngBytes;
      Uint8List? rgbaBytes;
      if (rendered != null) {
        try {
          final image = await rendered.createImage();
          try {
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              pngBytes = byteData.buffer.asUint8List();
            }
            // Raw pixels (not just the PNG for display) let us approximate the
            // original ink's weight/color per block - see _detectInkStyle.
            final rawByteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            if (rawByteData != null) {
              rgbaBytes = rawByteData.buffer.asUint8List();
            }
          } finally {
            image.dispose();
          }
        } finally {
          rendered.dispose();
        }
      }

      final pageText = await page.loadText();
      final fragments = <_PdfFragmentHit>[];
      for (final fragment in pageText.fragments) {
        if (fragment.text.trim().isEmpty) {
          continue;
        }
        final bounds = fragment.bounds;
        // pdfrx uses PDF-native bottom-up Y; flip to top-down to match
        // Syncfusion's Rect.fromLTWH convention used by the exporter below.
        final rect = Rect.fromLTWH(bounds.left, page.height - bounds.top, bounds.width, bounds.height);
        final charRects = <Rect>[
          for (final charRect in fragment.charRects)
            Rect.fromLTWH(charRect.left, page.height - charRect.top, charRect.width, charRect.height),
        ];
        fragments.add(_PdfFragmentHit(rect: rect, text: fragment.text, charRects: charRects));
      }

      // Group fragmented words/runs into MS-Word-like paragraph/line blocks
      // (requirement #1) with best-effort inherited font metadata (#2),
      // rather than exposing every tiny fragment as its own tap target.
      final blocks = _buildParagraphBlocks(fragments, rgbaBytes, pixelWidth, pixelHeight, _renderScale);

      if (!mounted) return;
      setState(() {
        _currentPagePng = pngBytes;
        _currentPagePointSize = Size(page.width, page.height);
        _currentPageFragments = fragments;
        _currentPageBlocks = blocks;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadStatus = 'Error rendering page ${_currentPageIndex + 1}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingPage = false;
        });
      }
    }
  }

  Future<void> _goToPage(int index) async {
    if (_pdfDoc == null || index < 0 || index >= _pageCount || index == _currentPageIndex) {
      return;
    }
    setState(() {
      _currentPageIndex = index;
    });
    await _renderCurrentPage();
  }

  void _startScanProgress() {
    _progressTimer?.cancel();
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      setState(() {
        _scanProgress = (_scanProgress + 0.08).clamp(0.0, 0.95);
      });
    });
  }

  void _finishScanProgress({required double value}) {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanProgress = value;
    });
  }

  Future<void> _extractTables() async {
    if (_selectedBytes == null || _selectedName == null) return;
    setState(() {
      _isLoadingText = true;
      _loadStatus = 'Extracting tables and form data...';
    });
    try {
      final result = await _ocrService.extractText(
        pdfBytes: _selectedBytes!,
        fileName: _selectedName!,
        mode: PdfExtractionMode.tableAware,
      );
      final text = result.success && result.text.trim().isNotEmpty
          ? result.text
          : 'No table or form content found in this PDF.';
      _loadStatus = result.success
          ? 'Ready: Tables and forms extracted'
          : 'ℹ️ OCR backend not configured. Extracted embedded table data instead.';
      if (mounted) {
        _showExtractedTextDialog('Extracted Tables & Forms', text);
      }
    } catch (e) {
      _loadStatus = 'Error: Table extraction failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loadStatus)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  /// Runs OCR on the original PDF (for scanned/image-only pages that have no
  /// vector text layer for pdfrx to detect) and shows the result read-only -
  /// unlike the in-place text overlays above, OCR text has no reliable
  /// per-word position, so it cannot be safely mapped onto the visual canvas.
  Future<void> _runOcrForScannedPages() async {
    if (_selectedBytes == null || _selectedName == null) return;
    setState(() {
      _isLoadingText = true;
      _loadStatus = 'Running OCR on scanned pages...';
    });
    _startScanProgress();
    try {
      final result = await _ocrService.extractText(
        pdfBytes: _selectedBytes!,
        fileName: _selectedName!,
        forceOcr: true,
      );
      final text = result.success && result.text.trim().isNotEmpty
          ? result.text
          : 'No text could be recognized on this PDF.';
      _loadStatus = result.success ? 'Ready: OCR text extracted' : 'ℹ️ OCR backend not configured.';
      if (mounted) {
        _showExtractedTextDialog('OCR Result (Scanned Pages)', text);
      }
    } catch (e) {
      _loadStatus = 'Error: OCR failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loadStatus)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingText = false);
      _finishScanProgress(value: 1.0);
    }
  }

  void _showExtractedTextDialog(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Paragraph/line grouping + adaptive metadata detection ───────────────

  /// Clusters raw text fragments into lines by vertical-center proximity,
  /// then orders each line left-to-right and the lines top-to-bottom - the
  /// foundation both the on-canvas paragraph blocks and the DOCX exporter
  /// build on, so a page is never treated as a flat bag of fragments.
  List<List<_PdfFragmentHit>> _groupFragmentsIntoLines(List<_PdfFragmentHit> fragments) {
    if (fragments.isEmpty) return const <List<_PdfFragmentHit>>[];
    final sorted = [...fragments]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final lines = <List<_PdfFragmentHit>>[];
    for (final fragment in sorted) {
      final centerY = fragment.rect.top + fragment.rect.height / 2;
      List<_PdfFragmentHit>? targetLine;
      for (final line in lines) {
        final lineRect = _boundingRectOf(line);
        final lineCenterY = lineRect.top + lineRect.height / 2;
        final referenceHeight = fragment.rect.height > lineRect.height ? fragment.rect.height : lineRect.height;
        if ((centerY - lineCenterY).abs() <= referenceHeight * 0.6) {
          targetLine = line;
          break;
        }
      }
      if (targetLine != null) {
        targetLine.add(fragment);
      } else {
        lines.add([fragment]);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }
    lines.sort((a, b) => _boundingRectOf(a).top.compareTo(_boundingRectOf(b).top));
    return lines;
  }

  Rect _boundingRectOf(List<_PdfFragmentHit> fragments) {
    var rect = fragments.first.rect;
    for (final fragment in fragments.skip(1)) {
      rect = rect.expandToInclude(fragment.rect);
    }
    return rect;
  }

  /// Merges tightly-spaced, left-aligned consecutive lines into one
  /// reflowable paragraph block (MS Word Flow, requirement #1); a bigger gap
  /// or a different left margin (heading, new column, table cell, etc.)
  /// deliberately starts a new block instead of over-merging unrelated text.
  List<_DetectedBlock> _buildParagraphBlocks(
    List<_PdfFragmentHit> fragments,
    Uint8List? rgba,
    int pixelWidth,
    int pixelHeight,
    double renderScale,
  ) {
    final lines = _groupFragmentsIntoLines(fragments);
    if (lines.isEmpty) return const <_DetectedBlock>[];

    final blocks = <List<List<_PdfFragmentHit>>>[];
    for (final line in lines) {
      final lineRect = _boundingRectOf(line);
      if (blocks.isNotEmpty) {
        final previousRect = _boundingRectOf(blocks.last.last);
        final gap = lineRect.top - previousRect.bottom;
        final leftDiff = (lineRect.left - previousRect.left).abs();
        if (gap >= -2 && gap <= previousRect.height * 0.55 && leftDiff <= 6.0) {
          blocks.last.add(line);
          continue;
        }
      }
      blocks.add([line]);
    }

    return [
      for (final block in blocks) _describeBlock(block, rgba, pixelWidth, pixelHeight, renderScale),
    ];
  }

  _DetectedBlock _describeBlock(
    List<List<_PdfFragmentHit>> lines,
    Uint8List? rgba,
    int pixelWidth,
    int pixelHeight,
    double renderScale,
  ) {
    final allFragments = [for (final line in lines) ...line];
    final tightRect = _boundingRectOf(allFragments);
    // A small width buffer gives freshly-detected (unedited) text a little
    // slack before the Flutter-side reflow measurement ever nudges its
    // height - see _recomputeBlockLayout.
    final rect = Rect.fromLTWH(tightRect.left, tightRect.top, tightRect.width * 1.08, tightRect.height);
    final text = lines.map((line) => line.map((f) => f.text.trim()).where((t) => t.isNotEmpty).join(' ')).join(' ').trim();

    final avgLineHeight = allFragments.map((f) => f.rect.height).reduce((a, b) => a + b) / allFragments.length;
    final fontSize = _inferFontSize(avgLineHeight);
    final style = _detectInkStyle(tightRect, rgba, pixelWidth, pixelHeight, renderScale);
    final fontFamily = _detectFontFamily(allFragments);

    return _DetectedBlock(
      rect: rect,
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      bold: style.bold,
      textColorArgb: style.colorArgb,
    );
  }

  /// pdfrx doesn't expose the PDF's real embedded font name, so approximate
  /// via glyph-width consistency: monospace fonts (Courier-like) have
  /// near-identical character advance widths - the closest safe,
  /// evidence-based stand-in for a real font-family read.
  sfpdf.PdfFontFamily _detectFontFamily(List<_PdfFragmentHit> fragments) {
    final widths = <double>[
      for (final fragment in fragments)
        for (final charRect in fragment.charRects)
          if (charRect.width > 0.5) charRect.width,
    ];
    if (widths.length < 6) {
      return sfpdf.PdfFontFamily.helvetica;
    }
    final mean = widths.reduce((a, b) => a + b) / widths.length;
    final variance = widths.map((w) => (w - mean) * (w - mean)).reduce((a, b) => a + b) / widths.length;
    final coefficientOfVariation = mean == 0 ? 1.0 : variance / (mean * mean);
    return coefficientOfVariation < 0.02 ? sfpdf.PdfFontFamily.courier : sfpdf.PdfFontFamily.helvetica;
  }

  /// Samples the already-rasterized page bitmap under a block's original
  /// bounds to approximate its ink weight (bold vs regular) and color -
  /// pdfrx/PDFium's Dart API doesn't surface either directly, so this is a
  /// real (disclosed, evidence-based) measurement rather than a guess.
  ({bool bold, int colorArgb}) _detectInkStyle(
    Rect rect,
    Uint8List? rgba,
    int pixelWidth,
    int pixelHeight,
    double renderScale,
  ) {
    if (rgba == null || pixelWidth <= 0 || pixelHeight <= 0) {
      return (bold: false, colorArgb: 0xFF000000);
    }
    final left = (rect.left * renderScale).floor().clamp(0, pixelWidth - 1);
    final top = (rect.top * renderScale).floor().clamp(0, pixelHeight - 1);
    final right = (rect.right * renderScale).ceil().clamp(left + 1, pixelWidth);
    final bottom = (rect.bottom * renderScale).ceil().clamp(top + 1, pixelHeight);

    var inkPixelCount = 0;
    var totalPixelCount = 0;
    var inkRedSum = 0;
    var inkGreenSum = 0;
    var inkBlueSum = 0;
    const step = 2; // sample every 2nd pixel per axis - fast and plenty accurate for this heuristic

    for (var y = top; y < bottom; y += step) {
      final rowOffset = y * pixelWidth * 4;
      for (var x = left; x < right; x += step) {
        final offset = rowOffset + x * 4;
        if (offset + 3 >= rgba.length) continue;
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        totalPixelCount++;
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        if (luminance < 165) {
          inkPixelCount++;
          inkRedSum += r;
          inkGreenSum += g;
          inkBlueSum += b;
        }
      }
    }

    if (totalPixelCount == 0 || inkPixelCount == 0) {
      return (bold: false, colorArgb: 0xFF000000);
    }

    final inkRatio = inkPixelCount / totalPixelCount;
    // Empirically, bold glyphs cover noticeably more of their box in ink
    // than regular-weight glyphs at the same point size.
    final bold = inkRatio > 0.30;
    final colorArgb = 0xFF000000 | ((inkRedSum ~/ inkPixelCount) << 16) | ((inkGreenSum ~/ inkPixelCount) << 8) | (inkBlueSum ~/ inkPixelCount);
    return (bold: bold, colorArgb: colorArgb);
  }

  // ── Overlay CRUD (canvas edits) ────────────────────────────────────────────

  String _nextOverlayId() {
    _overlayIdCounter += 1;
    return 'overlay-$_overlayIdCounter';
  }

  /// A text fragment's tight bounding-box height is a reasonable estimate of
  /// its original point size (glyph ascent/descent roughly fill the box).
  double _inferFontSize(double boundsHeight) => boundsHeight.clamp(8.0, 48.0);

  /// Promotes a detected paragraph/line block into an editable overlay,
  /// inheriting its detected size/weight/color (requirement #2) - editing a
  /// real paragraph, never a single fragmented word.
  void _selectDetectedBlockForEditing(_DetectedBlock detected) {
    final overlay = _PdfTextBlock(
      id: _nextOverlayId(),
      originalRect: detected.rect,
      rect: detected.rect,
      text: detected.text,
      fontSize: detected.fontSize,
      fontFamily: detected.fontFamily,
      bold: detected.bold,
      textColorArgb: detected.textColorArgb,
    );
    setState(() {
      _currentOverlays.add(overlay);
      _selectedOverlay = overlay;
      _overlayTextController.text = overlay.text;
    });
  }

  void _addTextBox() {
    final pageSize = _currentPagePointSize;
    if (pageSize == Size.zero) return;
    final rect = Rect.fromLTWH(pageSize.width * 0.3, pageSize.height * 0.45, pageSize.width * 0.4, 22);
    final overlay = _PdfTextBlock(
      id: _nextOverlayId(),
      originalRect: rect,
      rect: rect,
      text: 'New text',
      fontSize: 12,
    );
    _recomputeBlockLayout(overlay);
    setState(() {
      _currentOverlays.add(overlay);
      _selectedOverlay = overlay;
      _overlayTextController.text = overlay.text;
    });
  }

  void _addWhiteoutBox() {
    final pageSize = _currentPagePointSize;
    if (pageSize == Size.zero) return;
    final rect = Rect.fromLTWH(pageSize.width * 0.3, pageSize.height * 0.45, pageSize.width * 0.4, 22);
    final overlay = _PdfTextBlock(
      id: _nextOverlayId(),
      originalRect: rect,
      rect: rect,
      text: '',
      fontSize: 12,
      isWhiteoutOnly: true,
    );
    setState(() {
      _currentOverlays.add(overlay);
      _selectedOverlay = overlay;
      _overlayTextController.clear();
    });
  }

  /// Inserts a brand-new line right below the currently selected block (or
  /// at a default spot if none is selected), matching its style.
  void _addLineBelow() {
    final pageSize = _currentPagePointSize;
    if (pageSize == Size.zero) return;
    final reference = _selectedOverlay;
    final fontSize = reference?.fontSize ?? 12.0;
    final width = reference?.rect.width ?? pageSize.width * 0.4;
    final left = reference?.rect.left ?? pageSize.width * 0.3;
    var top = reference != null ? reference.rect.bottom + 4 : pageSize.height * 0.45;
    if (top > pageSize.height - 20) top = pageSize.height - 20;
    if (top < 0) top = 0;

    final rect = Rect.fromLTWH(left, top, width, fontSize * 1.3);
    final overlay = _PdfTextBlock(
      id: _nextOverlayId(),
      originalRect: rect,
      rect: rect,
      text: 'New line',
      fontSize: fontSize,
      fontFamily: reference?.fontFamily ?? sfpdf.PdfFontFamily.helvetica,
      bold: reference?.bold ?? false,
      italic: reference?.italic ?? false,
      textColorArgb: reference?.textColorArgb ?? 0xFF000000,
    );
    _recomputeBlockLayout(overlay);
    setState(() {
      _currentOverlays.add(overlay);
      _selectedOverlay = overlay;
      _overlayTextController.text = overlay.text;
    });
  }

  void _selectOverlay(_PdfTextBlock overlay) {
    setState(() {
      _selectedOverlay = overlay;
      _overlayTextController.text = overlay.text;
    });
  }

  void _updateSelectedOverlayText(String value) {
    final overlay = _selectedOverlay;
    if (overlay == null) return;
    setState(() {
      overlay.text = value;
      _recomputeBlockLayout(overlay);
    });
  }

  void _deleteSelectedOverlay() {
    final overlay = _selectedOverlay;
    if (overlay == null) return;
    setState(() {
      _currentOverlays.remove(overlay);
      _selectedOverlay = null;
      _overlayTextController.clear();
    });
  }

  void _moveOverlay(_PdfTextBlock overlay, Offset pagePointDelta) {
    final pageSize = _currentPagePointSize;
    var next = overlay.rect.shift(pagePointDelta);
    if (pageSize != Size.zero) {
      final dx = next.left.clamp(0.0, (pageSize.width - next.width).clamp(0.0, pageSize.width));
      final dy = next.top.clamp(0.0, (pageSize.height - next.height).clamp(0.0, pageSize.height));
      next = Rect.fromLTWH(dx, dy, next.width, next.height);
    }
    setState(() {
      overlay.rect = next;
    });
  }

  /// Resizes a box by dragging a corner handle. Whiteout-only boxes resize
  /// freely on all four corners; text blocks only resize in WIDTH (their
  /// height is auto-managed by the reflow engine so it always exactly fits
  /// the current text - see _recomputeBlockLayout).
  void _resizeOverlay(_PdfTextBlock overlay, Offset pagePointDelta, _OverlayResizeCorner corner) {
    const minSize = 10.0;
    final delta = overlay.isWhiteoutOnly ? pagePointDelta : Offset(pagePointDelta.dx, 0);
    var left = overlay.rect.left;
    var top = overlay.rect.top;
    var right = overlay.rect.right;
    var bottom = overlay.rect.bottom;

    switch (corner) {
      case _OverlayResizeCorner.topLeft:
        left += delta.dx;
        top += delta.dy;
        break;
      case _OverlayResizeCorner.topRight:
        right += delta.dx;
        top += delta.dy;
        break;
      case _OverlayResizeCorner.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
        break;
      case _OverlayResizeCorner.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
        break;
    }

    if (right - left < minSize) {
      if (corner == _OverlayResizeCorner.topLeft || corner == _OverlayResizeCorner.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (corner == _OverlayResizeCorner.topLeft || corner == _OverlayResizeCorner.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    setState(() {
      overlay.rect = Rect.fromLTRB(left, top, right, bottom);
      _recomputeBlockLayout(overlay);
    });
  }

  // ── Dynamic inline reflow + rich formatting (requirements #1, #2, #3) ───

  /// Re-wraps the block's text to fit its current width and grows/shrinks
  /// its height to match - the "dynamic inline reflow" requirement: typing
  /// more/less text never leaves a blank gap or an overlapping remainder.
  /// Growth is capped so an edit can never silently paint over unrelated
  /// content that sits below it on the page.
  void _recomputeBlockLayout(_PdfTextBlock overlay) {
    if (overlay.isWhiteoutOnly) return;
    final painter = TextPainter(
      text: TextSpan(text: overlay.text.isEmpty ? ' ' : overlay.text, style: _flutterStyleForBlock(overlay)),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: overlay.rect.width);

    final minHeight = overlay.fontSize * 1.15;
    final naturalHeight = painter.height < minHeight ? minHeight : painter.height;
    final ceiling = _growthCeiling(overlay);
    var maxHeight = ceiling - overlay.rect.top - 2;
    if (maxHeight < minHeight) maxHeight = minHeight;
    final newHeight = naturalHeight > maxHeight ? maxHeight : naturalHeight;

    overlay.rect = Rect.fromLTWH(overlay.rect.left, overlay.rect.top, overlay.rect.width, newHeight);
  }

  /// The lowest Y a block may grow down to before it would start covering
  /// other original (unedited) text or another already-placed edit.
  double _growthCeiling(_PdfTextBlock overlay) {
    final pageHeight = _currentPagePointSize.height;
    var ceiling = pageHeight > 0 ? pageHeight : double.infinity;

    void consider(Rect other) {
      final horizontalOverlap = other.left < overlay.rect.right && other.right > overlay.rect.left;
      if (horizontalOverlap && other.top > overlay.originalRect.top + 1 && other.top < ceiling) {
        ceiling = other.top;
      }
    }

    for (final block in _currentPageBlocks) {
      consider(block.rect);
    }
    for (final other in _currentOverlays) {
      if (identical(other, overlay)) continue;
      consider(other.rect);
    }
    return ceiling;
  }

  TextStyle _flutterStyleForBlock(_PdfTextBlock overlay) {
    return TextStyle(
      fontFamily: 'Trebuchet MS',
      fontSize: overlay.fontSize,
      fontWeight: overlay.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: overlay.italic ? FontStyle.italic : FontStyle.normal,
      decoration: overlay.underline ? TextDecoration.underline : TextDecoration.none,
      color: overlay.textColor,
      height: 1.18,
    );
  }

  void _toggleBold() => _mutateSelectedBlock((overlay) => overlay.bold = !overlay.bold);

  void _toggleItalic() => _mutateSelectedBlock((overlay) => overlay.italic = !overlay.italic);

  void _toggleUnderline() => _mutateSelectedBlock((overlay) => overlay.underline = !overlay.underline);

  void _incrementFontSize() => _mutateSelectedBlock((overlay) => overlay.fontSize = (overlay.fontSize + 1).clamp(6.0, 96.0));

  void _decrementFontSize() => _mutateSelectedBlock((overlay) => overlay.fontSize = (overlay.fontSize - 1).clamp(6.0, 96.0));

  void _setFontSize(double value) => _mutateSelectedBlock((overlay) => overlay.fontSize = value);

  void _setTextColor(int argb) => _mutateSelectedBlock((overlay) => overlay.textColorArgb = argb);

  void _setHighlightColor(int? argb) => _mutateSelectedBlock((overlay) => overlay.highlightColorArgb = argb);

  void _mutateSelectedBlock(void Function(_PdfTextBlock overlay) mutate) {
    final overlay = _selectedOverlay;
    if (overlay == null) return;
    setState(() {
      mutate(overlay);
      _recomputeBlockLayout(overlay);
    });
  }

  /// Self-contained RGB picker (no extra package dependency) for the
  /// toolbar's "Custom" text/highlight color option.
  Future<void> _showCustomColorPicker({required bool isHighlight}) async {
    final overlay = _selectedOverlay;
    if (overlay == null) return;
    final initial = isHighlight ? (overlay.highlightColorArgb ?? _highlightYellowArgb) : overlay.textColorArgb;
    var r = (initial >> 16) & 0xFF;
    var g = (initial >> 8) & 0xFF;
    var b = initial & 0xFF;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget channelSlider(String label, int value, ValueChanged<double> onChanged) {
              return Row(
                children: [
                  SizedBox(width: 18, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Expanded(
                    child: Slider(min: 0, max: 255, value: value.toDouble(), onChanged: onChanged),
                  ),
                  SizedBox(width: 32, child: Text('$value', style: const TextStyle(fontSize: 12))),
                ],
              );
            }

            return AlertDialog(
              title: Text(isHighlight ? 'Custom highlight color' : 'Custom text color'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, r, g, b),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    channelSlider('R', r, (v) => setDialogState(() => r = v.round())),
                    channelSlider('G', g, (v) => setDialogState(() => g = v.round())),
                    channelSlider('B', b, (v) => setDialogState(() => b = v.round())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(0xFF000000 | (r << 16) | (g << 8) | b),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (isHighlight) {
        _setHighlightColor(result);
      } else {
        _setTextColor(result);
      }
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────

  sfpdf.PdfColor _pdfColorFromArgb(int argb) {
    return sfpdf.PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
  }

  sfpdf.PdfStandardFont _syncfusionFontForBlock(_PdfTextBlock overlay) {
    final styles = <sfpdf.PdfFontStyle>[
      if (overlay.bold) sfpdf.PdfFontStyle.bold,
      if (overlay.italic) sfpdf.PdfFontStyle.italic,
      if (overlay.underline) sfpdf.PdfFontStyle.underline,
    ];
    return sfpdf.PdfStandardFont(overlay.fontFamily, overlay.fontSize, multiStyle: styles.isEmpty ? null : styles);
  }

  /// Draws every page's whiteout/text overlays directly onto the ORIGINAL
  /// loaded document's matching pages (never a blank new document), so any
  /// page/area without an overlay is byte-for-byte the original PDF content.
  /// Each edited block is masked with its full `maskRect` (original area
  /// union current area) then re-typeset with matching font family, weight,
  /// style, color, and highlight (requirement #4).
  Uint8List _buildExportedPdfBytes() {
    final originalBytes = _selectedBytes;
    if (originalBytes == null) {
      throw StateError('No PDF loaded.');
    }
    final outputDocument = sfpdf.PdfDocument(inputBytes: originalBytes);
    try {
      for (final entry in _pageOverlays.entries) {
        final pageIndex = entry.key;
        final overlays = entry.value;
        if (overlays.isEmpty || pageIndex < 0 || pageIndex >= outputDocument.pages.count) {
          continue;
        }
        final page = outputDocument.pages[pageIndex];
        for (final overlay in overlays) {
          page.graphics.drawRectangle(
            brush: sfpdf.PdfSolidBrush(sfpdf.PdfColor(255, 255, 255)),
            bounds: overlay.maskRect,
          );
          if (overlay.isWhiteoutOnly || overlay.text.trim().isEmpty) {
            continue;
          }
          if (overlay.highlightColorArgb != null) {
            page.graphics.drawRectangle(
              brush: sfpdf.PdfSolidBrush(_pdfColorFromArgb(overlay.highlightColorArgb!)),
              bounds: overlay.rect,
            );
          }
          page.graphics.drawString(
            overlay.text,
            _syncfusionFontForBlock(overlay),
            brush: sfpdf.PdfSolidBrush(_pdfColorFromArgb(overlay.textColorArgb)),
            bounds: overlay.rect,
            format: sfpdf.PdfStringFormat(lineSpacing: overlay.fontSize * 0.18),
          );
        }
      }
      return Uint8List.fromList(outputDocument.saveSync());
    } finally {
      outputDocument.dispose();
    }
  }

  /// Builds the WHOLE document (all pages) as DOCX paragraphs/runs, so the
  /// exporter can preserve rich formatting (bold/italic/underline/color/
  /// highlight) on edited blocks, not just flatten everything to plain text.
  Future<List<List<_DocxRun>>> _buildFullDocumentParagraphs() async {
    final document = _pdfDoc;
    if (document == null) return const <List<_DocxRun>>[];
    final paragraphs = <List<_DocxRun>>[];

    for (var i = 0; i < document.pages.length; i++) {
      final overlaysForPage = _pageOverlays[i] ?? const <_PdfTextBlock>[];
      List<_PdfFragmentHit> fragments;
      if (i == _currentPageIndex) {
        fragments = _currentPageFragments;
      } else {
        final page = document.pages[i];
        final pageText = await page.loadText();
        fragments = <_PdfFragmentHit>[
          for (final fragment in pageText.fragments)
            if (fragment.text.trim().isNotEmpty)
              _PdfFragmentHit(
                rect: Rect.fromLTWH(fragment.bounds.left, page.height - fragment.bounds.top, fragment.bounds.width, fragment.bounds.height),
                text: fragment.text,
                charRects: const <Rect>[],
              ),
        ];
      }

      final lines = _groupFragmentsIntoLines(fragments);
      for (final line in lines) {
        final lineRect = _boundingRectOf(line);
        final covered = overlaysForPage.any((o) => o.rect.overlaps(lineRect));
        if (covered) continue;
        final text = line.map((f) => f.text.trim()).where((t) => t.isNotEmpty).join(' ');
        if (text.isEmpty) continue;
        paragraphs.add([_DocxRun(text: text, fontSize: _inferFontSize(lineRect.height))]);
      }

      for (final overlay in overlaysForPage) {
        if (overlay.isWhiteoutOnly || overlay.text.trim().isEmpty) continue;
        paragraphs.add([
          _DocxRun(
            text: overlay.text,
            bold: overlay.bold,
            italic: overlay.italic,
            underline: overlay.underline,
            colorArgb: overlay.textColorArgb,
            fontSize: overlay.fontSize,
            highlightName: _highlightNameForArgb(overlay.highlightColorArgb),
          ),
        ]);
      }
    }

    return paragraphs;
  }

  /// OOXML `w:highlight` only accepts a fixed named palette - map the
  /// toolbar's two highlight choices to their exact official names.
  String? _highlightNameForArgb(int? argb) {
    if (argb == null) return null;
    if (argb == _highlightGreenArgb) return 'green';
    return 'yellow';
  }

  Uint8List _buildDocxBytes(List<List<_DocxRun>> paragraphs) {
    final bodyXml = StringBuffer();
    bodyXml.write('<w:body>');
    for (final paragraph in paragraphs) {
      bodyXml.write('<w:p>');
      for (final run in paragraph) {
        if (run.text.trim().isEmpty) continue;
        bodyXml.write('<w:r><w:rPr>');
        if (run.bold) bodyXml.write('<w:b/>');
        if (run.italic) bodyXml.write('<w:i/>');
        if (run.underline) bodyXml.write('<w:u w:val="single"/>');
        bodyXml.write('<w:color w:val="${_argbToHex(run.colorArgb)}"/>');
        if (run.highlightName != null) {
          bodyXml.write('<w:highlight w:val="${run.highlightName}"/>');
        }
        bodyXml.write('<w:sz w:val="${(run.fontSize * 2).round()}"/>');
        bodyXml.write('</w:rPr><w:t xml:space="preserve">${_escapeXml(run.text)}</w:t></w:r>');
      }
      bodyXml.write('</w:p>');
    }
    bodyXml.write('<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body>');

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  ${bodyXml.toString()}
</w:document>''';

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    final output = OutputStream();
    final encoder = ZipEncoder();
    encoder.encode(archive, output: output);
    return Uint8List.fromList(output.getBytes());
  }

  String _argbToHex(int argb) {
    final value = argb & 0xFFFFFF;
    return value.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void _downloadBytes(String fileName, Uint8List bytes, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  Future<void> _exportPdf() async {
    if (_selectedBytes == null || _selectedName == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _loadStatus = 'Exporting PDF…';
    });
    try {
      final outputBytes = _buildExportedPdfBytes();
      final outputName = _selectedName!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '_edited.pdf');
      _downloadBytes(outputName, outputBytes, 'application/pdf');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _loadStatus = 'Ready: exported $outputName';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export started for $outputName')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _loadStatus = 'Error: export failed ($e).';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportDocx() async {
    if (_selectedBytes == null || _selectedName == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _loadStatus = 'Exporting DOCX…';
    });
    try {
      final paragraphs = await _buildFullDocumentParagraphs();
      final outputBytes = _buildDocxBytes(paragraphs);
      final outputName = _selectedName!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '_edited.docx');
      _downloadBytes(outputName, outputBytes, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _loadStatus = 'Ready: exported $outputName';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DOCX export started for $outputName')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _loadStatus = 'Error: export failed ($e).';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  int _countPdfPages(Uint8List pdfBytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        return document.pages.count;
      } finally {
        document.dispose();
      }
    } catch (_) {
      return 0;
    }
  }

  /// Combined AI OCR quota indicator (shared with the Scanned PDF -> Word
  /// fallback path in ConversionService).
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

  /// Sends the ORIGINAL uploaded PDF (not the edited text) to the shared
  /// Google Cloud Vision OCR backend, producing a new PDF that keeps the
  /// original scanned page images but adds an invisible, positioned,
  /// selectable/searchable text layer underneath - unlike Export PDF/DOCX
  /// above (which rebuild a fresh document from the edited text box).
  Future<void> _convertToSearchablePdf() async {
    final bytes = _selectedBytes;
    final name = _selectedName;
    if (bytes == null || name == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF first.')),
      );
      return;
    }

    final pageCount = _countPdfPages(bytes);
    if (pageCount > 0 && !OcrQuotaService.canUseOcr(pageCount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OcrQuotaService.blockedReasonMessage(pageCount))),
      );
      return;
    }

    setState(() {
      _isConvertingToSearchablePdf = true;
      _loadStatus = 'Running AI OCR (Google Cloud Vision)…';
    });

    try {
      final searchablePdfBytes = await const RemoteOcrService().convertToSearchablePdf(
        bytes: bytes,
        fileName: name,
      );
      if (pageCount > 0) {
        await OcrQuotaService.recordUsage(pageCount);
      }

      final outputName = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '_searchable.pdf');
      final blob = html.Blob([searchablePdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', outputName)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        html.Url.revokeObjectUrl(url);
      });

      if (!mounted) return;
      setState(() {
        _isConvertingToSearchablePdf = false;
        _loadStatus = 'Ready: searchable PDF exported';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searchable PDF ready: $outputName')),
      );
    } on RemoteOcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _isConvertingToSearchablePdf = false;
        _loadStatus = 'Ready';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConvertingToSearchablePdf = false;
        _loadStatus = 'Ready';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searchable PDF conversion failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
        title: const Text('PDF to PDF (Edit)'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(_selectedName == null ? 'Upload PDF' : 'Change PDF'),
                    ),
                  ),
                  if (_selectedName != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _clearUploadedFile,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_selectedBytes == null || _isLoadingText) ? null : _runOcrForScannedPages,
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text('Run OCR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_selectedBytes == null || _isLoadingText) ? null : _extractTables,
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Tables'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedName != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing: $_selectedName${_selectedBytes != null ? ' (${_formatFileSize(_selectedBytes!.length)})' : ''} • Ready',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _loadStatus.toLowerCase().contains('error')
                      ? const Color(0xFFFEE2E2)
                      : _loadStatus.toLowerCase().contains('not configured')
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _loadStatus.toLowerCase().contains('error')
                        ? const Color(0xFFFCA5A5)
                        : _loadStatus.toLowerCase().contains('not configured')
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  _loadStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _loadStatus.toLowerCase().contains('error')
                        ? const Color(0xFF991B1B)
                        : _loadStatus.toLowerCase().contains('not configured')
                            ? const Color(0xFF92400E)
                            : const Color(0xFF065F46),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_isScanning)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanning progress: ${(_scanProgress * 100).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F4E79)),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _scanProgress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: const Color(0xFF1F4E79),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              const SizedBox(height: 4),
              _buildVisualEditor(),
              const SizedBox(height: 12),
              _buildOcrQuotaBanner(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedBytes == null || _isConvertingToSearchablePdf)
                      ? null
                      : _convertToSearchablePdf,
                  icon: Icon(_isConvertingToSearchablePdf ? Icons.hourglass_top_rounded : Icons.travel_explore_rounded),
                  label: Text(_isConvertingToSearchablePdf
                      ? 'Running AI OCR (Google Cloud Vision)…'
                      : 'Convert to Searchable PDF (AI OCR)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_selectedBytes == null || _isSaving) ? null : _exportPdf,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(_isSaving ? 'Preparing PDF…' : 'Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_selectedBytes == null || _isSaving) ? null : _exportDocx,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(_isSaving ? 'Preparing DOCX…' : 'Export DOCX'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F4E79),
                        side: const BorderSide(color: Color(0xFF1F4E79), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const ToolGuidancePanel(
                title: 'About PDF Edit & OCR',
                summary: 'Tap any paragraph on the page to edit it in place with a Word-style rich text toolbar - text automatically reflows as you type, and font size/weight/color are auto-matched from the original. Run OCR or Tables for scanned content, then export an updated PDF or DOCX.',
                supportedFormats: ['PDF'],
                howToUse: ['Upload a PDF.', 'Tap any paragraph to edit it, or use Add Text/Add Whiteout.', 'Use the formatting toolbar for Bold/Italic/Underline, font size, text color, or highlight.', 'Export the updated PDF or DOCX with your formatting preserved.'],
                faqs: ['Will OCR work on every scan? Results vary by source quality.', 'Does the export keep the original layout? Yes - edits reflow and are drawn directly onto the original page; everything else is untouched.'],
                tips: ['Drag the corner handles to resize a text/whiteout box - a text box\'s height adjusts automatically to fit its content.', 'Use Add Whiteout to redact an area without adding new text.', 'Use Add Line to insert a new line matching the selected block\'s style.', 'Keep the original PDF for comparison.'],
              ),
              const SizedBox(height: 16),
              const ProductionFooter(compact: true),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildVisualEditor() {
    if (_selectedBytes == null) {
      return Container(
        height: 420,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: const Text(
          'Upload a PDF to start editing it visually.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    if (_isRenderingPage || _currentPagePng == null) {
      return Container(
        height: 420,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditorToolbar(),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, canvasConstraints) {
              final pointSize = _currentPagePointSize;
              if (pointSize == Size.zero) {
                return const SizedBox.shrink();
              }
              final displayWidth = canvasConstraints.maxWidth.clamp(0.0, 760.0);
              final scale = displayWidth / pointSize.width;
              final displayHeight = pointSize.height * scale;

              return Center(
                child: SizedBox(
                  width: displayWidth,
                  height: displayHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.memory(_currentPagePng!, fit: BoxFit.fill, gaplessPlayback: true),
                      ),
                      // Tap targets for detected paragraph/line blocks not yet covered by an overlay.
                      for (final block in _currentPageBlocks)
                        if (!_currentOverlays.any((o) => o.rect.overlaps(block.rect)))
                          Positioned(
                            left: block.rect.left * scale,
                            top: block.rect.top * scale,
                            width: block.rect.width * scale,
                            height: block.rect.height * scale,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectDetectedBlockForEditing(block),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.text,
                                child: Container(
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0x552563EB), width: 1)),
                                ),
                              ),
                            ),
                          ),
                      // User-created / edited overlays.
                      for (final overlay in _currentOverlays) _buildOverlayWidget(overlay, scale),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_pageCount > 1) ...[
            const SizedBox(height: 10),
            _buildPageNavigator(),
          ],
          if (_selectedOverlay != null) ...[
            const SizedBox(height: 10),
            _buildOverlayEditPanel(_selectedOverlay!),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Visual Editor',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
        ),
        OutlinedButton.icon(
          onPressed: _currentPagePng == null ? null : _addTextBox,
          icon: const Icon(Icons.text_fields_rounded, size: 16),
          label: const Text('Add Text'),
        ),
        OutlinedButton.icon(
          onPressed: _currentPagePng == null ? null : _addWhiteoutBox,
          icon: const Icon(Icons.format_color_reset_rounded, size: 16),
          label: const Text('Add Whiteout'),
        ),
        Text(
          'Tap any paragraph to edit it - a Word-style toolbar appears with Bold/Italic/Underline, size, color, and highlight.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildPageNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPageIndex > 0 ? () => _goToPage(_currentPageIndex - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('Page ${_currentPageIndex + 1} of $_pageCount', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: _currentPageIndex < _pageCount - 1 ? () => _goToPage(_currentPageIndex + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildOverlayWidget(_PdfTextBlock overlay, double scale) {
    final isSelected = identical(_selectedOverlay, overlay);
    final width = overlay.rect.width * scale;
    final height = overlay.rect.height * scale;

    return Positioned(
      left: overlay.rect.left * scale,
      top: overlay.rect.top * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _selectOverlay(overlay),
            onPanUpdate: (details) => _moveOverlay(overlay, details.delta / scale),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: overlay.isWhiteoutOnly ? Colors.white : (overlay.highlightColor ?? Colors.white),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              alignment: Alignment.topLeft,
              child: overlay.isWhiteoutOnly
                  ? null
                  : Text(
                      overlay.text,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                      style: _flutterStyleForBlock(overlay).copyWith(fontSize: overlay.fontSize * scale),
                    ),
            ),
          ),
          if (isSelected) ..._buildOverlayResizeHandles(overlay, scale),
        ],
      ),
    );
  }

  List<Widget> _buildOverlayResizeHandles(_PdfTextBlock overlay, double scale) {
    const double handleSize = 14;
    const double half = handleSize / 2;
    final width = overlay.rect.width * scale;
    final height = overlay.rect.height * scale;

    Widget buildHandle(double left, double top, _OverlayResizeCorner corner) {
      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _resizeOverlay(overlay, details.delta / scale, corner),
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
      );
    }

    return <Widget>[
      buildHandle(-half, -half, _OverlayResizeCorner.topLeft),
      buildHandle(width - half, -half, _OverlayResizeCorner.topRight),
      buildHandle(-half, height - half, _OverlayResizeCorner.bottomLeft),
      buildHandle(width - half, height - half, _OverlayResizeCorner.bottomRight),
    ];
  }

  Widget _buildOverlayEditPanel(_PdfTextBlock overlay) {
    if (overlay.isWhiteoutOnly) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Whiteout box selected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E3A8A))),
            ),
            TextButton.icon(
              onPressed: _deleteSelectedOverlay,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    Widget colorSwatch(int argb, {required bool isHighlight}) {
      final selected = isHighlight ? overlay.highlightColorArgb == argb : overlay.textColorArgb == argb;
      return GestureDetector(
        onTap: () => isHighlight ? _setHighlightColor(argb) : _setTextColor(argb),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(color: selected ? const Color(0xFF1F2937) : const Color(0xFFD1D5DB), width: selected ? 2.5 : 1),
          ),
        ),
      );
    }

    final transparentSelected = overlay.highlightColorArgb == null;
    final transparentSwatch = GestureDetector(
      onTap: () => _setHighlightColor(null),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: transparentSelected ? const Color(0xFF1F2937) : const Color(0xFFD1D5DB), width: transparentSelected ? 2.5 : 1),
        ),
        child: const Icon(Icons.not_interested_rounded, size: 14, color: Color(0xFF9CA3AF)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Editing paragraph at original position',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _overlayTextController,
            onChanged: _updateSelectedOverlayText,
            maxLines: null,
            minLines: 2,
            decoration: const InputDecoration(labelText: 'Paragraph text (auto-reflows as you type)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ToggleIconButton(icon: Icons.format_bold_rounded, active: overlay.bold, onTap: _toggleBold, tooltip: 'Bold'),
              _ToggleIconButton(icon: Icons.format_italic_rounded, active: overlay.italic, onTap: _toggleItalic, tooltip: 'Italic'),
              _ToggleIconButton(icon: Icons.format_underlined_rounded, active: overlay.underline, onTap: _toggleUnderline, tooltip: 'Underline'),
              Container(width: 1, height: 24, color: const Color(0xFFBFDBFE)),
              IconButton(
                onPressed: _decrementFontSize,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                tooltip: 'Smaller',
                visualDensity: VisualDensity.compact,
              ),
              Text('${overlay.fontSize.round()}pt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: _incrementFontSize,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                tooltip: 'Larger',
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  min: 6,
                  max: 96,
                  value: overlay.fontSize.clamp(6, 96),
                  onChanged: _setFontSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Text color: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              colorSwatch(0xFF000000, isHighlight: false),
              colorSwatch(0xFFFF0000, isHighlight: false),
              colorSwatch(0xFF0000FF, isHighlight: false),
              GestureDetector(
                onTap: () => _showCustomColorPicker(isHighlight: false),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red]),
                  ),
                  child: const Icon(Icons.colorize_rounded, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Highlight: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              colorSwatch(_highlightYellowArgb, isHighlight: true),
              colorSwatch(_highlightGreenArgb, isHighlight: true),
              transparentSwatch,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addLineBelow,
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('Add Line'),
              ),
              TextButton.icon(
                onPressed: _deleteSelectedOverlay,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                label: const Text('Delete Line', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isPdfFile(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
