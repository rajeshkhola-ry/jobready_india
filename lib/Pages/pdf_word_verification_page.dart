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

/// One element of the parsed document, in original reading order - either a
/// plain paragraph or a genuine table (rows/columns), never a flattened
/// text approximation of one.
sealed class _DocxBlock {}

class _DocxParagraphBlock extends _DocxBlock {
  _DocxParagraphBlock(this.paragraph);
  final _DocxParagraph paragraph;
}

/// A real DOCX table (`<w:tbl>`), parsed into rows/columns with their own
/// editable controllers per cell - never flattened into centered text lines.
class _DocxTableBlock extends _DocxBlock {
  _DocxTableBlock({required List<List<String>> rows, required this.columnWidthsTwips})
      : cellControllers = [
          for (final row in rows) [for (final cell in row) TextEditingController(text: cell)],
        ];

  final List<int> columnWidthsTwips;
  final List<List<TextEditingController>> cellControllers;
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

  late final List<_DocxBlock> _blocks;
  late final List<TextEditingController?> _controllers;
  late final List<FocusNode?> _focusNodes;
  int _activeBlockIndex = -1;
  final GlobalKey _livePreviewSectionKey = GlobalKey();

  // Tracks whether the user has actually changed anything. As long as this
  // stays false, "Continue to Download" sends `widget.convertedDocxBytes`
  // UNTOUCHED - the real, high-fidelity bytes pdf2docx/LibreOffice/Vision-OCR
  // produced (true tables, multi-column sections, embedded images/logos).
  // Only when the user genuinely edits something do we rebuild via the
  // simplified paragraph/table model below, which does NOT preserve images
  // or true multi-column layout - previously this rebuild ran unconditionally
  // on every single manual PDF-to-Word conversion, silently discarding a
  // perfectly good pdf2docx result even when nothing needed fixing.
  bool _hasEdits = false;

  _DocxParagraph? get _activeParagraph {
    if (_activeBlockIndex < 0 || _activeBlockIndex >= _blocks.length) return null;
    final block = _blocks[_activeBlockIndex];
    return block is _DocxParagraphBlock ? block.paragraph : null;
  }

  @override
  void initState() {
    super.initState();
    _blocks = _parseDocxBlocks(widget.convertedDocxBytes);
    _controllers = [
      for (final block in _blocks)
        block is _DocxParagraphBlock ? TextEditingController(text: block.paragraph.text) : null,
    ];
    _focusNodes = [for (final block in _blocks) block is _DocxParagraphBlock ? FocusNode() : null];
    for (var i = 0; i < _focusNodes.length; i++) {
      final focusNode = _focusNodes[i];
      if (focusNode == null) continue;
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() => _activeBlockIndex = i);
        }
      });
    }
    _activeBlockIndex = _blocks.indexWhere((block) => block is _DocxParagraphBlock);
    _openOriginalPdf();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller?.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode?.dispose();
    }
    for (final block in _blocks) {
      if (block is _DocxTableBlock) {
        for (final row in block.cellControllers) {
          for (final cellController in row) {
            cellController.dispose();
          }
        }
      }
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

  // Matches a real text run's text content, a tab run, or a line/page break -
  // in document order - so reconstructed text keeps genuine spacing (e.g.
  // "Date:" + tab + "15 Aug 2026") instead of concatenating with no gap.
  //
  // IMPORTANT: the text-run alternative requires the character right after
  // `<w:t` to be whitespace, `/`, or `>` - never a bare `[^>]*`. Table/tab
  // tags (`<w:tab/>`, `<w:tabs>`, `<w:tbl>`, `<w:tc>`, `<w:tr>`) all also
  // start with the literal substring "<w:t", so the previous loose
  // `<w:t[^>]*>` pattern wrongly matched THOSE tags as if they were opening
  // `<w:t>` text runs, then captured everything up to the next real
  // `</w:t>` - including raw XML - as if it were the run's text. That was
  // the root cause of raw XML leaking into the visible/editable text.
  static final RegExp _runPartPattern = RegExp(
    r'<w:t(?:\s[^>]*)?/?>([\s\S]*?)</w:t>|<w:tab(?:\s[^>]*)?/?>|<w:br(?:\s[^>]*)?/?>',
    caseSensitive: false,
  );

  // Paragraph PROPERTIES (alignment, tab-STOP definitions, etc.) live inside
  // <w:pPr> and must never be scanned for run content: a tab-stop definition
  // like `<w:tab w:val="right" w:pos="9360"/>` shares its tag name with a
  // genuine run-level tab CHARACTER (`<w:tab/>`, found later inside a
  // `<w:r>`), and would otherwise be double-counted as an extra `\t`.
  static final RegExp _paragraphPropertiesPattern = RegExp(r'<w:pPr[ >][\s\S]*?</w:pPr>', caseSensitive: false);

  static String _extractRunText(String xml) {
    final contentOnly = xml.replaceAll(_paragraphPropertiesPattern, '');
    final buffer = StringBuffer();
    for (final match in _runPartPattern.allMatches(contentOnly)) {
      final textGroup = match.group(1);
      if (textGroup != null) {
        buffer.write(_unescapeXml(textGroup));
      } else if ((match.group(0) ?? '').toLowerCase().contains('tab')) {
        buffer.write('\t');
      } else {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  static List<_DocxBlock> _parseDocxBlocks(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final xml = utf8.decode(documentFile.content as List<int>);
      // Tables and paragraphs are both top-level body children in real OOXML -
      // scanning for either in one ordered pass (rather than a paragraph-only
      // regex) means a table's OWN internal <w:p> cell paragraphs are
      // consumed as part of its <w:tbl> match and never double-counted as
      // separate, flattened top-level paragraphs.
      final blockMatches = RegExp(
        r'<w:tbl[ >][\s\S]*?</w:tbl>|<w:p[ >][\s\S]*?</w:p>',
        caseSensitive: false,
      ).allMatches(xml);
      final blocks = <_DocxBlock>[];
      for (final match in blockMatches) {
        final blockXml = match.group(0) ?? '';
        if (RegExp(r'^<w:tbl', caseSensitive: false).hasMatch(blockXml)) {
          final table = _parseDocxTable(blockXml);
          if (table != null) {
            blocks.add(_DocxTableBlock(rows: table.rows, columnWidthsTwips: table.columnWidthsTwips));
          }
          continue;
        }
        final paragraph = _parseDocxParagraph(blockXml);
        if (paragraph != null) {
          blocks.add(_DocxParagraphBlock(paragraph));
        }
      }
      if (blocks.isEmpty) {
        blocks.add(_DocxParagraphBlock(_DocxParagraph(text: '')));
      }
      return blocks;
    } catch (_) {
      return [_DocxParagraphBlock(_DocxParagraph(text: ''))];
    }
  }

  static _DocxParagraph? _parseDocxParagraph(String paragraphXml) {
    final text = _extractRunText(paragraphXml);
    if (text.trim().isEmpty) {
      return null;
    }
    final bold = RegExp(r'<w:b\s*/>|<w:b\s+w:val="(true|1)"', caseSensitive: false).hasMatch(paragraphXml);
    final italic = RegExp(r'<w:i\s*/>|<w:i\s+w:val="(true|1)"', caseSensitive: false).hasMatch(paragraphXml);
    final underline = RegExp(r'<w:u\s+w:val="(?!none")', caseSensitive: false).hasMatch(paragraphXml);
    final alignMatch = RegExp(r'<w:jc\s+w:val="([a-zA-Z]+)"', caseSensitive: false).firstMatch(paragraphXml);
    var alignment = switch (alignMatch?.group(1)?.toLowerCase()) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'both' => TextAlign.justify,
      _ => TextAlign.left,
    };
    // Defensive override: numbered/bulleted list items and long, clearly-
    // wrapped body paragraphs should never render centered even if the
    // source XML says so - upstream conversion heuristics can occasionally
    // mis-flag these (e.g. numbered list Points 8, 9, 10).
    final looksLikeListItem = RegExp(r'^\s*(?:\d+[.)]|[\u2022\-*])\s').hasMatch(text);
    if (alignment == TextAlign.center && (looksLikeListItem || text.trim().length > 60)) {
      alignment = TextAlign.left;
    }
    return _DocxParagraph(text: text, bold: bold, italic: italic, underline: underline, alignment: alignment);
  }

  static ({List<List<String>> rows, List<int> columnWidthsTwips})? _parseDocxTable(String tableXml) {
    final gridWidths = RegExp(r'<w:gridCol\s+w:w="(\d+)"', caseSensitive: false)
        .allMatches(tableXml)
        .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
        .toList();

    final rows = <List<String>>[];
    for (final rowMatch in RegExp(r'<w:tr[ >][\s\S]*?</w:tr>', caseSensitive: false).allMatches(tableXml)) {
      final rowXml = rowMatch.group(0) ?? '';
      final cells = <String>[
        for (final cellMatch in RegExp(r'<w:tc[ >][\s\S]*?</w:tc>', caseSensitive: false).allMatches(rowXml))
          _extractRunText(cellMatch.group(0) ?? '').trim(),
      ];
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
    if (rows.isEmpty) {
      return null;
    }

    // Word requires every row in a table to have the same cell count - pad
    // any short/ragged row (e.g. a genuinely merged source cell) with blanks
    // rather than letting a later Table widget crash on irregular rows.
    final columnCount = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    for (final row in rows) {
      while (row.length < columnCount) {
        row.add('');
      }
    }

    const contentWidthTwips = 9360;
    final columnWidthsTwips = (gridWidths.length == columnCount && gridWidths.isNotEmpty)
        ? gridWidths
        : List<int>.filled(columnCount, (contentWidthTwips / columnCount).round());
    return (rows: rows, columnWidthsTwips: columnWidthsTwips);
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
    for (final block in _blocks) {
      if (block is _DocxTableBlock) {
        bodyXml.write(_buildTableXml(block));
        continue;
      }
      final paragraph = (block as _DocxParagraphBlock).paragraph;
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

  /// Builds a genuine, structural `<w:tbl>` (real rows/cells/borders/column
  /// widths) for the export step - mirrors the server's table XML shape so
  /// an edited-and-re-downloaded table still opens as a real Word table.
  static String _buildTableXml(_DocxTableBlock block) {
    final columnCount = block.columnWidthsTwips.length;
    final totalWidth = block.columnWidthsTwips.fold<int>(0, (sum, w) => sum + w);
    const borderSides = ['top', 'left', 'bottom', 'right', 'insideH', 'insideV'];
    final borders = borderSides.map((side) => '<w:$side w:val="single" w:sz="4" w:space="0" w:color="999999"/>').join();
    final grid = block.columnWidthsTwips.map((w) => '<w:gridCol w:w="$w"/>').join();

    final rowsXml = StringBuffer();
    for (final row in block.cellControllers) {
      rowsXml.write('<w:tr>');
      for (var c = 0; c < columnCount; c++) {
        final text = c < row.length ? row[c].text : '';
        final width = block.columnWidthsTwips[c];
        rowsXml.write(
          '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>'
          '<w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p></w:tc>',
        );
      }
      rowsXml.write('</w:tr>');
    }

    return '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="$totalWidth" w:type="dxa"/>'
        '<w:tblBorders>$borders</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>'
        '<w:tblGrid>$grid</w:tblGrid>$rowsXml</w:tbl><w:p/>';
  }

  // ── Formatting actions (apply to the active/focused paragraph) ─────────

  void _toggleBold() => _mutateActive((p) => p.bold = !p.bold);

  void _toggleItalic() => _mutateActive((p) => p.italic = !p.italic);

  void _toggleUnderline() => _mutateActive((p) => p.underline = !p.underline);

  void _setAlignment(TextAlign alignment) => _mutateActive((p) => p.alignment = alignment);

  void _mutateActive(void Function(_DocxParagraph paragraph) mutate) {
    final paragraph = _activeParagraph;
    if (paragraph == null) {
      return;
    }
    setState(() {
      mutate(paragraph);
      _hasEdits = true;
    });
  }

  Future<void> _continueToDownload() async {
    // Only rebuild through the simplified model if something was actually
    // edited - otherwise hand over the ORIGINAL conversion bytes untouched,
    // preserving 100% of pdf2docx's/LibreOffice's real tables, multi-column
    // layout, and embedded images.
    final outputBytes = _hasEdits ? _buildEditedDocxBytes() : widget.convertedDocxBytes;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => DownloadResultDialog(
        outputFormat: widget.outputFormat,
        fileName: widget.outputFileName,
        outputBytes: outputBytes,
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
              'Compare the original PDF with the converted Word document below. Make any quick corrections, then continue to download or share. Your original formatting - including tables, columns, and images - stays fully intact unless you edit the text below.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * 0.62).clamp(480.0, 720.0).toDouble(),
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
                  _buildPreviewJumpBanner(),
                  _buildLivePreviewSection(),
                ],
              ),
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
          child: _blocks.isEmpty
              ? const Center(child: Text('No readable text found in the converted document.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _blocks.length,
                  itemBuilder: (context, index) {
                    final block = _blocks[index];
                    if (block is _DocxTableBlock) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildTableBlockWidget(block),
                      );
                    }
                    final paragraph = (block as _DocxParagraphBlock).paragraph;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        maxLines: null,
                        textAlign: paragraph.alignment,
                        style: TextStyle(
                          fontWeight: paragraph.bold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: paragraph.italic ? FontStyle.italic : FontStyle.normal,
                          decoration: paragraph.underline ? TextDecoration.underline : TextDecoration.none,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(10),
                        ),
                        onChanged: (value) {
                          paragraph.text = value;
                          _hasEdits = true;
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Renders a parsed `<w:tbl>` as a genuine bordered grid (not flattened,
  /// centered text) - each cell stays independently editable.
  Widget _buildTableBlockWidget(_DocxTableBlock block) {
    final totalWidth = block.columnWidthsTwips.fold<int>(0, (sum, w) => sum + w);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9CA3AF)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: const TableBorder.symmetric(inside: BorderSide(color: Color(0xFF9CA3AF))),
        columnWidths: {
          for (var c = 0; c < block.columnWidthsTwips.length; c++)
            c: FlexColumnWidth(totalWidth > 0 ? block.columnWidthsTwips[c].toDouble() : 1),
        },
        children: [
          for (final row in block.cellControllers)
            TableRow(
              children: [
                for (final controller in row)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      ),
                      onChanged: (_) {
                        _hasEdits = true;
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    final active = _activeParagraph;
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

  /// Smoothly scrolls the outer page so the live preview sheet comes into
  /// view - used by both the jump banner button and (implicitly) available
  /// to any future "scroll to preview" affordance.
  void _scrollToLivePreview() {
    final targetContext = _livePreviewSectionKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Divider/banner between the editable cards above and the live preview
  /// sheet below, with a button that smoothly scrolls straight to it.
  Widget _buildPreviewJumpBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard_double_arrow_down_rounded, color: Color(0xFFC2410C), size: 20),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  '\u2193 See Below: Live Preview of Your Word Document (.docx)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF9A3412)),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _scrollToLivePreview,
            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
            label: const Text('Jump to Live Preview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC2410C),
              side: const BorderSide(color: Color(0xFFFDBA74), width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// A4-style white page sheet that re-renders the CURRENT live state of
  /// every block (paragraph text/formatting, table cell text) on every
  /// rebuild - since edits above call `setState`, this always reflects the
  /// latest keystroke/formatting change with no extra sync step needed.
  Widget _buildLivePreviewSection() {
    return Container(
      key: _livePreviewSectionKey,
      width: double.infinity,
      color: const Color(0xFFE5E7EB),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Live Preview of Your Word Document (.docx)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Updates instantly as you edit above',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 794),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 64),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
                  ],
                ),
                child: _buildLivePreviewContent(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLivePreviewContent() {
    if (_blocks.isEmpty) {
      return const Text(
        'No readable text found in the converted document.',
        style: TextStyle(color: Color(0xFF9CA3AF)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in _blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: block is _DocxTableBlock
                ? _buildLivePreviewTable(block)
                : _buildLivePreviewParagraph((block as _DocxParagraphBlock).paragraph),
          ),
      ],
    );
  }

  Widget _buildLivePreviewParagraph(_DocxParagraph paragraph) {
    if (paragraph.text.trim().isEmpty) {
      return const SizedBox(height: 10);
    }
    return Text(
      paragraph.text,
      textAlign: paragraph.alignment,
      style: TextStyle(
        fontWeight: paragraph.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: paragraph.italic ? FontStyle.italic : FontStyle.normal,
        decoration: paragraph.underline ? TextDecoration.underline : TextDecoration.none,
        fontSize: 13.5,
        height: 1.5,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _buildLivePreviewTable(_DocxTableBlock block) {
    final totalWidth = block.columnWidthsTwips.fold<int>(0, (sum, w) => sum + w);
    return Table(
      border: TableBorder.all(color: const Color(0xFF9CA3AF), width: 1),
      columnWidths: {
        for (var c = 0; c < block.columnWidthsTwips.length; c++)
          c: FlexColumnWidth(totalWidth > 0 ? block.columnWidthsTwips[c].toDouble() : 1),
      },
      children: [
        for (final row in block.cellControllers)
          TableRow(
            children: [
              for (final controller in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    controller.text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF111827)),
                  ),
                ),
            ],
          ),
      ],
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
