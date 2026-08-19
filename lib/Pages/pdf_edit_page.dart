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

/// A detected run of ORIGINAL vector text on the current page, in top-down
/// PDF point space (matches Syncfusion's Rect.fromLTWH convention directly).
class _PdfFragmentHit {
  const _PdfFragmentHit({required this.rect, required this.text});
  final Rect rect;
  final String text;
}

/// A user-placed edit: either a plain whiteout box, or a whiteout box with
/// replacement/new text drawn on top - both drawn directly over the ORIGINAL
/// PDF page at export time, so everything else on the page stays untouched.
class _PdfOverlayItem {
  _PdfOverlayItem({
    required this.id,
    required this.rect,
    required this.text,
    required this.fontSize,
    this.isWhiteoutOnly = false,
  });

  final String id;
  Rect rect;
  String text;
  double fontSize;
  final bool isWhiteoutOnly;
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
  final Map<int, List<_PdfOverlayItem>> _pageOverlays = <int, List<_PdfOverlayItem>>{};
  _PdfOverlayItem? _selectedOverlay;
  int _overlayIdCounter = 0;
  final TextEditingController _overlayTextController = TextEditingController();

  final PdfOcrService _ocrService = const PdfOcrService();

  List<_PdfOverlayItem> get _currentOverlays => _pageOverlays.putIfAbsent(_currentPageIndex, () => <_PdfOverlayItem>[]);

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
      const renderScale = 2.0; // 2x for a crisp preview/edit surface
      final pixelWidth = (page.width * renderScale).round().toDouble();
      final pixelHeight = (page.height * renderScale).round().toDouble();

      final rendered = await page.render(fullWidth: pixelWidth, fullHeight: pixelHeight);
      Uint8List? pngBytes;
      if (rendered != null) {
        try {
          final image = await rendered.createImage();
          try {
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              pngBytes = byteData.buffer.asUint8List();
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
        fragments.add(_PdfFragmentHit(rect: rect, text: fragment.text));
      }

      if (!mounted) return;
      setState(() {
        _currentPagePng = pngBytes;
        _currentPagePointSize = Size(page.width, page.height);
        _currentPageFragments = fragments;
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

  // ── Overlay CRUD (canvas edits) ────────────────────────────────────────────

  String _nextOverlayId() {
    _overlayIdCounter += 1;
    return 'overlay-$_overlayIdCounter';
  }

  /// A text fragment's tight bounding-box height is a reasonable estimate of
  /// its original point size (glyph ascent/descent roughly fill the box).
  double _inferFontSize(double boundsHeight) => boundsHeight.clamp(8.0, 48.0);

  void _selectFragmentForEditing(_PdfFragmentHit fragment) {
    final overlay = _PdfOverlayItem(
      id: _nextOverlayId(),
      rect: fragment.rect,
      text: fragment.text,
      fontSize: _inferFontSize(fragment.rect.height),
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
    final overlay = _PdfOverlayItem(
      id: _nextOverlayId(),
      rect: Rect.fromLTWH(pageSize.width * 0.3, pageSize.height * 0.45, pageSize.width * 0.4, 22),
      text: 'New text',
      fontSize: 12,
    );
    setState(() {
      _currentOverlays.add(overlay);
      _selectedOverlay = overlay;
      _overlayTextController.text = overlay.text;
    });
  }

  void _addWhiteoutBox() {
    final pageSize = _currentPagePointSize;
    if (pageSize == Size.zero) return;
    final overlay = _PdfOverlayItem(
      id: _nextOverlayId(),
      rect: Rect.fromLTWH(pageSize.width * 0.3, pageSize.height * 0.45, pageSize.width * 0.4, 22),
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

  void _selectOverlay(_PdfOverlayItem overlay) {
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

  void _moveOverlay(_PdfOverlayItem overlay, Offset pagePointDelta) {
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

  void _resizeOverlay(_PdfOverlayItem overlay, Offset pagePointDelta, _OverlayResizeCorner corner) {
    const minSize = 10.0;
    var left = overlay.rect.left;
    var top = overlay.rect.top;
    var right = overlay.rect.right;
    var bottom = overlay.rect.bottom;

    switch (corner) {
      case _OverlayResizeCorner.topLeft:
        left += pagePointDelta.dx;
        top += pagePointDelta.dy;
        break;
      case _OverlayResizeCorner.topRight:
        right += pagePointDelta.dx;
        top += pagePointDelta.dy;
        break;
      case _OverlayResizeCorner.bottomLeft:
        left += pagePointDelta.dx;
        bottom += pagePointDelta.dy;
        break;
      case _OverlayResizeCorner.bottomRight:
        right += pagePointDelta.dx;
        bottom += pagePointDelta.dy;
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
    });
  }

  // ── Export ──────────────────────────────────────────────────────────────

  /// Draws every page's whiteout/text overlays directly onto the ORIGINAL
  /// loaded document's matching pages (never a blank new document), so any
  /// page/area without an overlay is byte-for-byte the original PDF content.
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
            bounds: overlay.rect,
          );
          if (!overlay.isWhiteoutOnly && overlay.text.trim().isNotEmpty) {
            final font = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, overlay.fontSize);
            page.graphics.drawString(
              overlay.text,
              font,
              brush: sfpdf.PdfSolidBrush(sfpdf.PdfColor(0, 0, 0)),
              bounds: overlay.rect,
            );
          }
        }
      }
      return Uint8List.fromList(outputDocument.saveSync());
    } finally {
      outputDocument.dispose();
    }
  }

  /// Builds a plain-text snapshot of the WHOLE document (all pages, not just
  /// the currently viewed one) for the DOCX export path, extracting on demand
  /// for any page that hasn't been visited/rendered yet in this session.
  Future<String> _buildFullDocumentPlainText() async {
    final document = _pdfDoc;
    if (document == null) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < document.pages.length; i++) {
      final overlaysForPage = _pageOverlays[i] ?? const <_PdfOverlayItem>[];
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
              ),
        ];
      }
      for (final fragment in fragments) {
        final covered = overlaysForPage.any((o) => o.rect.overlaps(fragment.rect));
        if (!covered) {
          buffer.writeln(fragment.text);
        }
      }
      for (final overlay in overlaysForPage) {
        if (!overlay.isWhiteoutOnly && overlay.text.trim().isNotEmpty) {
          buffer.writeln(overlay.text);
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Uint8List _buildDocxBytes(String editedText) {
    final paragraphs = editedText.split('\n').where((line) => line.trim().isNotEmpty).toList(growable: false);
    final bodyXml = StringBuffer();
    bodyXml.write('<w:body>');
    for (final paragraph in paragraphs) {
      final escapedParagraph = _escapeXml(paragraph);
      bodyXml.write('<w:p><w:r><w:t>$escapedParagraph</w:t></w:r></w:p>');
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
      final text = await _buildFullDocumentPlainText();
      final outputBytes = _buildDocxBytes(text);
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
                summary: 'Tap any original text on the page to edit it in place, or add a new text/whiteout box. Run OCR or Tables for scanned content, then export an updated PDF or DOCX.',
                supportedFormats: ['PDF'],
                howToUse: ['Upload a PDF.', 'Tap any text to edit it, or use Add Text/Add Whiteout.', 'Export the updated PDF or DOCX.'],
                faqs: ['Will OCR work on every scan? Results vary by source quality.', 'Does the export keep the original layout? Yes - edits are drawn directly onto the original page; everything else is untouched.'],
                tips: ['Drag the corner handles to resize a text/whiteout box.', 'Use Add Whiteout to redact an area without adding new text.', 'Keep the original PDF for comparison.'],
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
                      // Tap targets for detected original text not yet covered by an overlay.
                      for (final fragment in _currentPageFragments)
                        if (!_currentOverlays.any((o) => o.rect.overlaps(fragment.rect)))
                          Positioned(
                            left: fragment.rect.left * scale,
                            top: fragment.rect.top * scale,
                            width: fragment.rect.width * scale,
                            height: fragment.rect.height * scale,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectFragmentForEditing(fragment),
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
          'Tap any original text to edit it in place.',
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

  Widget _buildOverlayWidget(_PdfOverlayItem overlay, double scale) {
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
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: overlay.isWhiteoutOnly
                  ? null
                  : Text(
                      overlay.text,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: TextStyle(fontSize: overlay.fontSize * scale, color: Colors.black, height: 1.0),
                    ),
            ),
          ),
          if (isSelected) ..._buildOverlayResizeHandles(overlay, scale),
        ],
      ),
    );
  }

  List<Widget> _buildOverlayResizeHandles(_PdfOverlayItem overlay, double scale) {
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

  Widget _buildOverlayEditPanel(_PdfOverlayItem overlay) {
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
          Text(
            overlay.isWhiteoutOnly ? 'Whiteout box selected' : 'Editing text at original position',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 8),
          if (!overlay.isWhiteoutOnly)
            TextField(
              controller: _overlayTextController,
              onChanged: _updateSelectedOverlayText,
              decoration: const InputDecoration(labelText: 'Replacement text', border: OutlineInputBorder(), isDense: true),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!overlay.isWhiteoutOnly) ...[
                const Text('Font size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    min: 6,
                    max: 48,
                    value: overlay.fontSize.clamp(6, 48),
                    onChanged: (value) => setState(() => overlay.fontSize = value),
                  ),
                ),
              ] else
                const Spacer(),
              TextButton.icon(
                onPressed: _deleteSelectedOverlay,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
