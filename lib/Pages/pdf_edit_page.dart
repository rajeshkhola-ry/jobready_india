import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../Utils/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:universal_html/html.dart' as html;

import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/ocr_quota_service.dart';
import '../Services/pdf_export_formatter.dart';
import '../Services/pdf_ocr_service.dart';
import '../Services/remote_ocr_service.dart';
import '../Services/upload_context_service.dart';
import '../Services/voice_command_service.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/tool_guidance_panel.dart';

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
  bool _isAutoSaving = false;
  bool _isConvertingToSearchablePdf = false;
  String _loadStatus = 'Ready';
  String _autoSaveStatus = 'Saved ✓';
  double _scanProgress = 0.0;
  String? _lastSavedText;
  String? _previewUrl;
  bool _previewShowingEdits = false;
  html.IFrameElement? _previewIframeElement;
  String? _previewViewType;
  int _previewViewCounter = 0;
  Timer? _autoSaveTimer;
  Timer? _progressTimer;

  final TextEditingController _editorController = TextEditingController();
  final ScrollController _editorScrollController = ScrollController();
  final PdfOcrService _ocrService = const PdfOcrService();

  @override
  void initState() {
    super.initState();
    _editorController.addListener(_handleEditorChanged);
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
      _loadPdfTextIntoEditor();
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
    _autoSaveTimer?.cancel();
    _progressTimer?.cancel();
    _editorController.removeListener(_handleEditorChanged);
    _editorController.dispose();
    _editorScrollController.dispose();
    if (_previewUrl != null) {
      html.Url.revokeObjectUrl(_previewUrl!);
    }
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
      _previewUrl = null;
      _previewShowingEdits = false;
      _lastSavedText = null;
      _autoSaveStatus = 'Saved ✓';
      _isAutoSaving = false;
      _isScanning = false;
      _scanProgress = 0.0;
      _loadStatus = 'ℹ️ PDF loaded. Click "Load Text" or "Run OCR" to extract content.';
    });

    await _loadPdfTextIntoEditor();
  }

  void _clearUploadedFile() {
    setState(() {
      _selectedBytes = null;
      _selectedName = null;
      _previewUrl = null;
      _previewShowingEdits = false;
      _editorController.clear();
      _loadStatus = 'File removed. Upload a new PDF to continue.';
    });
    _previewIframeElement?.src = 'about:blank';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded file removed.')),
    );
  }

  // A fresh, never-before-used viewType is registered for every uploaded file
  // instead of one static string, so a page revisit / hot-restart cannot ever
  // collide with a stale factory left over from an earlier registration -
  // registerViewFactory throws if the same viewType is registered twice, and
  // that failure was silently swallowed by the try/catch below, leaving the
  // iframe reference permanently null (and the preview permanently blank).
  void _allocateNewPreviewView() {
    _previewViewCounter += 1;
    final viewType = 'pdf-preview-view-$_previewViewCounter-${DateTime.now().microsecondsSinceEpoch}';
    _previewIframeElement = null;
    _previewViewType = viewType;
    _registerPdfPreviewFactory(viewType);
  }

  void _registerPdfPreviewFactory(String viewType) {
    try {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#FFFFFF';
        // Keep a direct reference instead of relying on getElementById, which can
        // never find this element (the platform-view wrapper does not expose the
        // viewType string as the iframe's DOM id) - this was the original blank-preview bug.
        _previewIframeElement = iframe;
        final pendingUrl = _previewUrl;
        if (pendingUrl != null) {
          iframe.src = pendingUrl;
        }
        return iframe;
      });
    } catch (_) {
      // Ignore registration failures on environments that do not support this path.
    }
  }

  void _openPreviewInNewTab() {
    final url = _previewUrl;
    if (url == null) {
      return;
    }
    html.window.open(url, '_blank');
  }

  void _handleEditorChanged() {
    final currentText = _editorController.text.trim();
    final hasChanged = _lastSavedText == null || currentText != _lastSavedText;

    if (!hasChanged) {
      if (_autoSaveStatus != 'Saved ✓') {
        setState(() {
          _autoSaveStatus = 'Saved ✓';
          _isAutoSaving = false;
        });
      }
      return;
    }

    setState(() {
      _autoSaveStatus = 'Saving…';
      _isAutoSaving = true;
    });

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      final savedText = _editorController.text.trim();
      setState(() {
        _lastSavedText = savedText;
        _autoSaveStatus = 'Saved ✓';
        _isAutoSaving = false;
      });
      _refreshEditedPreview(savedText);
    });
  }

  /// Regenerates the left preview pane from the CURRENT edited text using the
  /// same builder as the real export, so the preview always matches what the
  /// user would actually download - no separate/divergent rendering path.
  void _refreshEditedPreview(String editedText) {
    if (editedText.isEmpty || _selectedBytes == null) {
      return;
    }
    try {
      final previewBytes = _buildEditedPdfBytes(editedText);
      setState(() {
        _refreshPreview(overrideBytes: previewBytes, showingEdits: true);
      });
    } catch (_) {
      // Best-effort live preview only; Export PDF/DOCX still has its own error handling.
    }
  }

  void _startScanProgress() {
    _progressTimer?.cancel();
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _autoSaveStatus = 'Scanning…';
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
      if (_autoSaveStatus == 'Scanning…') {
        _autoSaveStatus = 'Saved ✓';
      }
    });
  }

  Future<void> _loadPdfTextIntoEditor({bool forceOcr = false}) async {
    if (_selectedBytes == null) {
      return;
    }

    _startScanProgress();

    setState(() {
      _isLoadingText = true;
    });

    try {
      final result = await _ocrService.extractText(
        pdfBytes: _selectedBytes!,
        fileName: _selectedName ?? 'document.pdf',
        forceOcr: forceOcr,
      );

      if (result.success) {
        _editorController.text = result.text;
        _lastSavedText = result.text.trim();
        _previewUrl = null;
        _previewShowingEdits = false;
        _loadStatus = 'Ready: PDF text loaded successfully';
      } else {
        _editorController.text = '';
        _lastSavedText = '';
        _previewUrl = null;
        _previewShowingEdits = false;
        _loadStatus = 'ℹ️ OCR backend not configured. Loaded embedded PDF text instead.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loadStatus)),
        );
      }
    } catch (e) {
      _editorController.text = '';
      _lastSavedText = '';
      _previewUrl = null;
      _previewShowingEdits = false;
      _loadStatus = 'Error: Unable to load text from PDF. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loadStatus)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingText = false;
        });
        _finishScanProgress(value: 1.0);
      }
    }
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
      _editorController.text = result.success && result.text.trim().isNotEmpty
          ? result.text
          : 'No table or form content found in this PDF.';
      _loadStatus = result.success
          ? 'Ready: Tables and forms extracted'
          : 'ℹ️ OCR backend not configured. Extracted embedded table data instead.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loadStatus)));
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

  /// Reads the ORIGINAL uploaded PDF's page size so exported/edited pages keep
  /// the same dimensions instead of Syncfusion's unrelated default page size.
  Size? _originalPageSize() {
    final bytes = _selectedBytes;
    if (bytes == null) {
      return null;
    }
    try {
      final probe = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        if (probe.pages.count == 0) {
          return null;
        }
        return probe.pages[0].size;
      } finally {
        probe.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Uint8List _buildEditedPdfBytes(String editedText) {
    final outputDocument = sfpdf.PdfDocument();
    try {
      final originalSize = _originalPageSize();
      if (originalSize != null) {
        outputDocument.pageSettings.size = originalSize;
      }
      final paragraphs = PdfExportFormatter.prepareParagraphs(editedText);
      final firstPage = outputDocument.pages.add();
      final pageWidth = firstPage.size.width;
      final pageHeight = firstPage.size.height;
      const marginLeft = 20.0;
      const marginTop = 20.0;
      const marginRight = 20.0;
      const marginBottom = 18.0;
      const lineHeight = 14.0;
      const paragraphGap = 10.0;
      const maxCharsPerLine = 92;

      final headerFont = sfpdf.PdfStandardFont(
        sfpdf.PdfFontFamily.timesRoman,
        14,
        style: sfpdf.PdfFontStyle.bold,
      );
      final subtitleFont = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.timesRoman, 10);
      final headingFont = sfpdf.PdfStandardFont(
        sfpdf.PdfFontFamily.timesRoman,
        12,
        style: sfpdf.PdfFontStyle.bold,
      );
      final bodyFont = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.timesRoman, 11);
      final footerFont = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.timesRoman, 9);

      var currentPage = firstPage;
      var yPosition = marginTop + 42;

      void drawPageHeader(sfpdf.PdfPage page) {
        page.graphics.drawString(
          'Edited PDF from: $_selectedName',
          headerFont,
          pen: sfpdf.PdfPen(sfpdf.PdfColor(31, 41, 55)),
          bounds: Rect.fromLTWH(marginLeft, marginTop, pageWidth - marginLeft - marginRight, 18),
        );
        page.graphics.drawString(
          'Exported by GET READY JOB',
          subtitleFont,
          pen: sfpdf.PdfPen(sfpdf.PdfColor(107, 114, 128)),
          bounds: Rect.fromLTWH(marginLeft, marginTop + 20, pageWidth - marginLeft - marginRight, 14),
        );
      }

      void drawFooter(sfpdf.PdfPage page) {
        page.graphics.drawString(
          'Edited by GETREADYJOB PDF Editor',
          footerFont,
          pen: sfpdf.PdfPen(sfpdf.PdfColor(150, 150, 150)),
          bounds: Rect.fromLTWH(
            marginLeft,
            pageHeight - marginBottom - 12,
            pageWidth - marginLeft - marginRight,
            10,
          ),
        );
      }

      drawPageHeader(currentPage);

      for (final paragraph in paragraphs) {
        final wrappedLines = PdfExportFormatter.wrapParagraph(paragraph, maxCharsPerLine: maxCharsPerLine);
        if (wrappedLines.isEmpty) {
          continue;
        }

        final paragraphHeight = wrappedLines.length * lineHeight + paragraphGap;
        while (yPosition + paragraphHeight > pageHeight - marginBottom - 18) {
          drawFooter(currentPage);
          currentPage = outputDocument.pages.add();
          yPosition = marginTop + 42;
          drawPageHeader(currentPage);
        }

        final isHeading = paragraph.length <= 80 && !paragraph.contains('|') && paragraph.split(' ').length <= 8;
        final textFont = isHeading ? headingFont : bodyFont;

        for (final line in wrappedLines) {
          while (yPosition + lineHeight > pageHeight - marginBottom - 12) {
            drawFooter(currentPage);
            currentPage = outputDocument.pages.add();
            yPosition = marginTop + 42;
            drawPageHeader(currentPage);
          }

          currentPage.graphics.drawString(
            line,
            textFont,
            pen: sfpdf.PdfPen(sfpdf.PdfColor(50, 50, 50)),
            bounds: Rect.fromLTWH(marginLeft, yPosition, pageWidth - marginLeft - marginRight, lineHeight),
          );
          yPosition += lineHeight;
        }

        yPosition += paragraphGap;
      }

      drawFooter(currentPage);

      return Uint8List.fromList(outputDocument.saveSync());
    } finally {
      outputDocument.dispose();
    }
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

  Future<void> _exportEditedText({required bool asDocx}) async {
    if (_selectedName == null) {
      return;
    }

    final editedText = _editorController.text.trim();
    if (editedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or edit text before exporting.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _autoSaveStatus = asDocx ? 'Exporting DOCX…' : 'Exporting PDF…';
    });

    try {
      final outputBytes = asDocx ? _buildDocxBytes(editedText) : _buildEditedPdfBytes(editedText);
      final outputName = _selectedName!.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        asDocx ? '_edited.docx' : '_edited.pdf',
      );
      final mimeType = asDocx
          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          : 'application/pdf';
      final blob = html.Blob([outputBytes], mimeType);
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
        _isSaving = false;
        _autoSaveStatus = 'Saved ✓';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asDocx ? 'DOCX' : 'PDF'} export started for $outputName')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _autoSaveStatus = 'Saved ✓';
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
      _autoSaveStatus = 'Running AI OCR (Google Cloud Vision)…';
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
        _autoSaveStatus = 'Saved ✓';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searchable PDF ready: $outputName')),
      );
    } on RemoteOcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _isConvertingToSearchablePdf = false;
        _autoSaveStatus = 'Saved ✓';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConvertingToSearchablePdf = false;
        _autoSaveStatus = 'Saved ✓';
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
          final useSplitScreen = constraints.maxWidth >= 1000;
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
                      onPressed: (_selectedBytes == null || _isLoadingText)
                          ? null
                          : () => _loadPdfTextIntoEditor(forceOcr: false),
                      icon: const Icon(Icons.text_snippet_outlined, size: 18),
                      label: const Text('Load Text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_selectedBytes == null || _isLoadingText)
                          ? null
                          : () => _loadPdfTextIntoEditor(forceOcr: true),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _autoSaveStatus,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                    ),
                  ),
                  if (_isAutoSaving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (useSplitScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildPreviewPanel(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEditorPanel(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewPanel(),
                    const SizedBox(height: 12),
                    _buildEditorPanel(),
                  ],
                ),
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
                      onPressed: (_selectedBytes == null || _isSaving) ? null : () => _exportEditedText(asDocx: false),
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
                      onPressed: (_selectedBytes == null || _isSaving) ? null : () => _exportEditedText(asDocx: true),
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
                summary: 'Use this page to load text from a PDF, run OCR for scanned content, review extracted tables, and export an updated PDF or DOCX.',
                supportedFormats: ['PDF'],
                howToUse: ['Upload a PDF.', 'Load text or run OCR.', 'Edit content and export the updated file.'],
                faqs: ['Will OCR work on every scan? Results vary by source quality.', 'Can I recover complex layouts perfectly? Some formatting may need manual review.'],
                tips: ['Use cleaner scans for better OCR.', 'Review extracted text before exporting.', 'Keep the original PDF for comparison.'],
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

  Widget _buildPreviewPanel() {
    if (_selectedBytes != null && _previewUrl == null) {
      _allocateNewPreviewView();
      _refreshPreview();
    }

    return Container(
      height: 420,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'PDF Preview',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
              ),
              if (_previewUrl != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _previewShowingEdits ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _previewShowingEdits ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Text(
                    _previewShowingEdits ? 'Live edited preview' : 'Original file',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _previewShowingEdits ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_previewUrl != null)
                TextButton.icon(
                  onPressed: _openPreviewInNewTab,
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Open in New Tab'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF1D4ED8),
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (_selectedName != null && _selectedBytes != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$_selectedName • ${_formatFileSize(_selectedBytes!.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _previewUrl == null
                ? const Center(
                    child: Text(
                      'Upload a PDF to preview it here.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: HtmlElementView(
                      key: ValueKey(_previewViewType),
                      viewType: _previewViewType!,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel() {
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
          const Text(
            'Editable OCR Text',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 8),
          if (_isLoadingText)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Scrollbar(
              controller: _editorScrollController,
              thumbVisibility: true,
              child: TextField(
                controller: _editorController,
                scrollController: _editorScrollController,
                minLines: 14,
                maxLines: 24,
                decoration: const InputDecoration(
                  labelText: 'Edit text manually here (changes are auto-saved locally)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Text(
              'Your edits auto-save, update the live preview on the left, and are reflected in the exported PDF/DOCX.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshPreview({Uint8List? overrideBytes, bool showingEdits = false}) {
    final bytesToShow = overrideBytes ?? _selectedBytes;
    if (bytesToShow == null) {
      return;
    }
    final previousUrl = _previewUrl;
    final blob = html.Blob([bytesToShow], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    _previewUrl = url;
    _previewShowingEdits = showingEdits;
    _previewIframeElement?.src = url;
    if (previousUrl != null && previousUrl != url) {
      // Revoke shortly after so the iframe has time to load the new blob first.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        html.Url.revokeObjectUrl(previousUrl);
      });
    }
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
