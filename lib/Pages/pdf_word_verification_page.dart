import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../Widgets/download_result_dialog.dart';

/// One editable paragraph extracted from the converted DOCX - only the
/// lightweight formatting attributes this verification screen supports.
class _DocxParagraph {
  _DocxParagraph({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = TextAlign.left,
  });

  String text;
  bool bold;
  bool italic;
  bool underline;
  TextAlign alignment;
}

/// Additive verification/editing screen shown after a PDF -> Word conversion
/// completes. This is purely a UI layer on top of the ALREADY-converted
/// bytes: it never calls back into the conversion engine, it only lets the
/// user compare the original PDF against the converted text and make quick
/// corrections before the final DOCX is packaged and handed to the existing
/// download/share flow ([DownloadResultDialog], unchanged).
class PdfWordVerificationPage extends StatefulWidget {
  const PdfWordVerificationPage({
    super.key,
    required this.originalPdfBytes,
    required this.convertedDocxBytes,
    required this.outputFileName,
    required this.outputFormat,
  });

  final Uint8List originalPdfBytes;
  final Uint8List convertedDocxBytes;
  final String outputFileName;
  final String outputFormat;

  @override
  State<PdfWordVerificationPage> createState() => _PdfWordVerificationPageState();
}

class _PdfWordVerificationPageState extends State<PdfWordVerificationPage> {
  pdfrx.PdfDocument? _pdfDoc;
  int _pageIndex = 0;
  int _pageCount = 0;
  Uint8List? _currentPagePng;
  bool _isRenderingPage = false;
  String? _pdfLoadError;

  late final List<_DocxParagraph> _paragraphs;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  int _activeParagraphIndex = 0;

  @override
  void initState() {
    super.initState();
    _paragraphs = _parseDocxParagraphs(widget.convertedDocxBytes);
    _controllers = [for (final p in _paragraphs) TextEditingController(text: p.text)];
    _focusNodes = [for (var i = 0; i < _paragraphs.length; i++) FocusNode()];
    for (var i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() => _activeParagraphIndex = i);
        }
      });
    }
    _openOriginalPdf();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _pdfDoc?.dispose();
    super.dispose();
  }

  Future<void> _openOriginalPdf() async {
    try {
      final document = await pdfrx.PdfDocument.openData(widget.originalPdfBytes, sourceName: 'original.pdf');
      if (!mounted) {
        await document.dispose();
        return;
      }
      setState(() {
        _pdfDoc = document;
        _pageCount = document.pages.length;
      });
      await _renderPage(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfLoadError = 'Unable to render the original PDF preview ($e).';
      });
    }
  }

  Future<void> _renderPage(int index) async {
    final document = _pdfDoc;
    if (document == null || index < 0 || index >= document.pages.length) {
      return;
    }
    setState(() => _isRenderingPage = true);
    try {
      final page = document.pages[index];
      const scale = 1.6;
      final pixelWidth = (page.width * scale).round().toDouble();
      final pixelHeight = (page.height * scale).round().toDouble();
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
      if (!mounted) return;
      setState(() {
        _pageIndex = index;
        _currentPagePng = pngBytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfLoadError = 'Error rendering page ${index + 1}: $e';
      });
    } finally {
      if (mounted) setState(() => _isRenderingPage = false);
    }
  }

  // ── DOCX parse/build - additive only; the real conversion engine that
  // produced `widget.convertedDocxBytes` is never touched or re-invoked. ────

  static List<_DocxParagraph> _parseDocxParagraphs(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final xml = utf8.decode(documentFile.content as List<int>);
      final paragraphMatches = RegExp(r'<w:p[ >][\s\S]*?</w:p>', caseSensitive: false).allMatches(xml);
      final paragraphs = <_DocxParagraph>[];
      for (final match in paragraphMatches) {
        final paragraphXml = match.group(0) ?? '';
        final textMatches = RegExp(r'<w:t[^>]*>([\s\S]*?)</w:t>', caseSensitive: false).allMatches(paragraphXml);
        final text = textMatches.map((m) => _unescapeXml(m.group(1) ?? '')).join();
        if (text.trim().isEmpty) {
          continue;
        }
        final bold = RegExp(r'<w:b\s*/>|<w:b\s+w:val="(true|1)"', caseSensitive: false).hasMatch(paragraphXml);
        final italic = RegExp(r'<w:i\s*/>|<w:i\s+w:val="(true|1)"', caseSensitive: false).hasMatch(paragraphXml);
        final underline = RegExp(r'<w:u\s+w:val="(?!none")', caseSensitive: false).hasMatch(paragraphXml);
        final alignMatch = RegExp(r'<w:jc\s+w:val="([a-zA-Z]+)"', caseSensitive: false).firstMatch(paragraphXml);
        final alignment = switch (alignMatch?.group(1)?.toLowerCase()) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          'both' => TextAlign.justify,
          _ => TextAlign.left,
        };
        paragraphs.add(_DocxParagraph(text: text, bold: bold, italic: italic, underline: underline, alignment: alignment));
      }
      if (paragraphs.isEmpty) {
        paragraphs.add(_DocxParagraph(text: ''));
      }
      return paragraphs;
    } catch (_) {
      return [_DocxParagraph(text: '')];
    }
  }

  static String _unescapeXml(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Re-packages the (possibly edited) paragraphs into a fresh, valid DOCX -
  /// a brand-new export step, not a modification of the conversion engine.
  Uint8List _buildEditedDocxBytes() {
    final bodyXml = StringBuffer()..write('<w:body>');
    for (final paragraph in _paragraphs) {
      if (paragraph.text.trim().isEmpty) {
        continue;
      }
      final jc = switch (paragraph.alignment) {
        TextAlign.center => 'center',
        TextAlign.right => 'right',
        TextAlign.justify => 'both',
        _ => 'left',
      };
      bodyXml.write('<w:p><w:pPr><w:jc w:val="$jc"/></w:pPr><w:r><w:rPr>');
      if (paragraph.bold) bodyXml.write('<w:b/>');
      if (paragraph.italic) bodyXml.write('<w:i/>');
      if (paragraph.underline) bodyXml.write('<w:u w:val="single"/>');
      bodyXml.write('</w:rPr><w:t xml:space="preserve">${_escapeXml(paragraph.text)}</w:t></w:r></w:p>');
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

  // ── Formatting actions (apply to the active/focused paragraph) ─────────

  void _toggleBold() => _mutateActive((p) => p.bold = !p.bold);

  void _toggleItalic() => _mutateActive((p) => p.italic = !p.italic);

  void _toggleUnderline() => _mutateActive((p) => p.underline = !p.underline);

  void _setAlignment(TextAlign alignment) => _mutateActive((p) => p.alignment = alignment);

  void _mutateActive(void Function(_DocxParagraph paragraph) mutate) {
    if (_activeParagraphIndex < 0 || _activeParagraphIndex >= _paragraphs.length) {
      return;
    }
    setState(() => mutate(_paragraphs[_activeParagraphIndex]));
  }

  Future<void> _continueToDownload() async {
    final editedBytes = _buildEditedDocxBytes();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => DownloadResultDialog(
        outputFormat: widget.outputFormat,
        fileName: widget.outputFileName,
        outputBytes: editedBytes,
        originalFileSizeBytes: widget.originalPdfBytes.length,
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        title: const Text('Verify & Edit: PDF to Word'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              'Compare the original PDF with the converted Word document below. Make any quick corrections, then continue to download or share.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final leftPanel = _buildLeftPanel();
                final rightPanel = _buildRightPanel();
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: leftPanel),
                      const VerticalDivider(width: 1),
                      Expanded(child: rightPanel),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(child: leftPanel),
                    const Divider(height: 1),
                    Expanded(child: rightPanel),
                  ],
                );
              },
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child: const Text(
              'Original PDF',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: _pdfLoadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_pdfLoadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  )
                : (_isRenderingPage || _currentPagePng == null)
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Image.memory(_currentPagePng!, fit: BoxFit.contain),
                      ),
          ),
          if (_pageCount > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _pageIndex > 0 ? () => _renderPage(_pageIndex - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('Page ${_pageIndex + 1} of $_pageCount', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  IconButton(
                    onPressed: _pageIndex < _pageCount - 1 ? () => _renderPage(_pageIndex + 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Text(
            'Converted Word Document (editable)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF374151)),
          ),
        ),
        _buildFormattingToolbar(),
        Expanded(
          child: _paragraphs.isEmpty
              ? const Center(child: Text('No readable text found in the converted document.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _paragraphs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      maxLines: null,
                      textAlign: _paragraphs[index].alignment,
                      style: TextStyle(
                        fontWeight: _paragraphs[index].bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: _paragraphs[index].italic ? FontStyle.italic : FontStyle.normal,
                        decoration: _paragraphs[index].underline ? TextDecoration.underline : TextDecoration.none,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                      onChanged: (value) => _paragraphs[index].text = value,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar() {
    final active = (_activeParagraphIndex >= 0 && _activeParagraphIndex < _paragraphs.length) ? _paragraphs[_activeParagraphIndex] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _toolbarToggle(Icons.format_bold_rounded, active?.bold ?? false, _toggleBold, 'Bold'),
          _toolbarToggle(Icons.format_italic_rounded, active?.italic ?? false, _toggleItalic, 'Italic'),
          _toolbarToggle(Icons.format_underlined_rounded, active?.underline ?? false, _toggleUnderline, 'Underline'),
          Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
          _toolbarToggle(Icons.format_align_left_rounded, active?.alignment == TextAlign.left, () => _setAlignment(TextAlign.left), 'Align left'),
          _toolbarToggle(Icons.format_align_center_rounded, active?.alignment == TextAlign.center, () => _setAlignment(TextAlign.center), 'Align center'),
          _toolbarToggle(Icons.format_align_right_rounded, active?.alignment == TextAlign.right, () => _setAlignment(TextAlign.right), 'Align right'),
          _toolbarToggle(Icons.format_align_justify_rounded, active?.alignment == TextAlign.justify, () => _setAlignment(TextAlign.justify), 'Justify'),
        ],
      ),
    );
  }

  Widget _toolbarToggle(IconData icon, bool active, VoidCallback onTap, String tooltip) {
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

  Widget _buildBottomActionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back / Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _continueToDownload,
              icon: const Icon(Icons.download_done_rounded),
              label: const Text('Continue to Download / Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
