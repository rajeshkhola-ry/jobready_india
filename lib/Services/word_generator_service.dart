import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_template/docx_template.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

class WordGeneratorService {
  const WordGeneratorService();

  Future<Uint8List> createWordDocumentFromPdfLayout({
    required Uint8List pdfBytes,
    required String pdfFileName,
    int preferredTargetWidth = 1400,
    double maxScale = 2.2,
  }) async {
    final extractedText = _extractTextFromPdfSyncfusion(pdfBytes);
    return createWordDocument(
      pdfFileName: pdfFileName,
      extractedText: extractedText,
    );
  }

  String _extractTextFromPdfSyncfusion(Uint8List pdfBytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        final text = sfpdf.PdfTextExtractor(document).extractText().trim();
        if (text.isNotEmpty) {
          return text;
        }
      } finally {
        document.dispose();
      }
    } catch (_) {
      // Fall through to safe message.
    }

    return 'PDF text could not be extracted in layout mode on this build.';
  }

  Future<Uint8List> createWordDocument({
    required String pdfFileName,
    required String extractedText,
  }) async {
    final String cleanText = extractedText.trim().isEmpty
        ? 'No readable text was found in the uploaded PDF.'
        : _normalizePdfExtractedText(extractedText);

    try {
      debugPrint(
        'WORD STEP 1: Loading template.docx...',
      );

      final ByteData templateData =
          await rootBundle.load(
        'assets/template.docx',
      );

      debugPrint(
        'WORD STEP 2: Template loaded. '
        'Size: ${templateData.lengthInBytes} bytes',
      );

      // Create a completely independent
      // and growable List<int>.
      final Uint8List templateBytes =
          templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      );

      final Uint8List mutableTemplateBytes =
          Uint8List.fromList(templateBytes);

      debugPrint(
        'WORD STEP 3: Mutable byte list created. '
        'Size: ${mutableTemplateBytes.length} bytes',
      );

      final bool templateHasTag =
          _templateHasTag(mutableTemplateBytes, 'document_content');
      if (!templateHasTag) {
        debugPrint(
          'WORD STEP 4: Template missing document_content tag. '
          'Using plain DOCX builder fallback.',
        );

        return _buildSimpleDocx(cleanText, pdfFileName);
      }

      final DocxTemplate? docx =
          await DocxTemplate.fromBytes(
        mutableTemplateBytes,
      );

      if (docx == null) {
        throw Exception(
          'Unable to load assets/template.docx',
        );
      }

      debugPrint(
        'WORD STEP 4: DOCX template parsed successfully.',
      );

      debugPrint(
        'WORD STEP 5: Preparing document content...',
      );

      final Content content = Content();

      content.add(
        TextContent(
          'document_content',
          cleanText,
        ),
      );

      debugPrint(
        'WORD STEP 6: Calling docx.generate()...',
      );

      final List<int>? generatedBytes =
          await docx.generate(
        content,
      );

      debugPrint(
        'WORD STEP 7: docx.generate() completed.',
      );

      if (generatedBytes == null || generatedBytes.isEmpty) {
        debugPrint(
          'WORD STEP 8: Generated docx from template was empty. '
          'Falling back to plain DOCX builder.',
        );

        return _buildSimpleDocx(cleanText, pdfFileName);
      }

      debugPrint(
        'WORD STEP 8: Word document generated successfully. '
        'Size: ${generatedBytes.length} bytes',
      );

      return Uint8List.fromList(
        generatedBytes,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'WORD GENERATOR ERROR: $e',
      );

      debugPrint(
        'WORD GENERATOR STACK TRACE:\n$stackTrace',
      );

      // Final safety fallback: always return a valid DOCX instead of failing conversion.
      // This prevents web-specific JS/runtime issues from breaking user downloads.
      return _buildSimpleDocx(cleanText, pdfFileName);
    }
  }

  bool _templateHasTag(Uint8List bytes, String tagName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      for (final file in archive.files) {
        if (file.name == 'word/document.xml' && file.content is List<int>) {
          final String xml = utf8.decode(file.content as List<int>);
          return xml.contains(tagName);
        }
      }
    } catch (_) {
      // If we cannot inspect the template, fallback to plain DOCX.
    }
    return false;
  }

  String _normalizePdfExtractedText(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();

    final out = <String>[];
    final current = StringBuffer();

    bool isJoinableFragment(String line) {
      if (line.isEmpty) return false;
      if (RegExp(r'^[\-/,.:;]$').hasMatch(line)) return true;
      if (RegExp(r'^[0-9]+$').hasMatch(line)) return true;
      if (RegExp(r'^[A-Za-z]{1,3}$').hasMatch(line)) return true;
      return false;
    }

    bool shouldContinueParagraph(String line) {
      if (line.isEmpty) return false;
      if (current.isEmpty) return true;
      final cur = current.toString().trimRight();
      if (cur.isEmpty) return true;
      final endsSentence = RegExp(r'[.!?)]$').hasMatch(cur);
      if (endsSentence) return false;
      if (isJoinableFragment(line)) return true;
      if (RegExp(r'^[a-z0-9(]').hasMatch(line)) return true;
      return cur.length < 80;
    }

    void flush() {
      final value = current.toString().trim();
      if (value.isNotEmpty) {
        out.add(value);
      }
      current.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.isEmpty) {
        flush();
        continue;
      }

      if (!shouldContinueParagraph(line)) {
        flush();
      }

      if (current.isNotEmpty) {
        final prev = current.toString();
        if (RegExp(r'[\-/]$').hasMatch(prev) || isJoinableFragment(line)) {
          current.write(line);
        } else {
          current.write(' ');
          current.write(line);
        }
      } else {
        current.write(line);
      }
    }

    flush();
    return out.join('\n\n');
  }

  Uint8List _buildSimpleDocx(String text, String pdfFileName) {
    String escapeXml(String value) {
      return value
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
    }

    final escapedLines = text
        .split(RegExp(r'\r\n?|\n'))
        .map((line) => escapeXml(line))
        .toList();

    final buffer = StringBuffer();
    for (final line in escapedLines) {
      buffer.writeln(
        '    <w:p><w:r><w:t xml:space="preserve">$line</w:t></w:r></w:p>',
      );
    }

    final String sanitizedTitle = escapeXml(pdfFileName);
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="32"/>
        </w:rPr>
        <w:t xml:space="preserve">$sanitizedTitle</w:t>
      </w:r>
    </w:p>
    <w:p><w:r><w:t xml:space="preserve">Generated from PDF file: $sanitizedTitle</w:t></w:r></w:p>
    <w:p><w:r><w:t xml:space="preserve"/></w:r></w:p>
$buffer    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
    archive.addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypes).length, utf8.encode(contentTypes)));
    archive.addFile(ArchiveFile('_rels/.rels', utf8.encode(relsXml).length, utf8.encode(relsXml)));
    archive.addFile(ArchiveFile('word/document.xml', utf8.encode(documentXml).length, utf8.encode(documentXml)));

    final List<int>? encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  Uint8List _buildImageDocx(String pdfFileName, List<_RenderedPage> pages) {
    final contentTypes = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..writeln('  <Default Extension="xml" ContentType="application/xml"/>')
      ..writeln('  <Default Extension="png" ContentType="image/png"/>')
      ..writeln('  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>')
      ..writeln('</Types>');

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final docRels = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    for (var i = 0; i < pages.length; i++) {
      docRels.writeln(
        '  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${pages[i].fileName}"/>',
      );
    }
    docRels.writeln('</Relationships>');

    const maxContentWidthEmu = 5486400; // about 6.0 inch drawable area
    final safeTitle = pdfFileName
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    final body = StringBuffer();

    body.writeln(
      '<w:p><w:r><w:rPr><w:b/><w:sz w:val="30"/></w:rPr><w:t xml:space="preserve">$safeTitle</w:t></w:r></w:p>',
    );
    body.writeln('<w:p><w:r><w:t xml:space="preserve">Layout-preserved PDF to Word export</w:t></w:r></w:p>');
    body.writeln('<w:p><w:r><w:t xml:space="preserve"></w:t></w:r></w:p>');

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      var cx = page.widthPx * 9525;
      var cy = page.heightPx * 9525;
      if (cx > maxContentWidthEmu) {
        final scale = maxContentWidthEmu / cx;
        cx = maxContentWidthEmu;
        cy = (cy * scale).round();
      }

      body.writeln('''
<w:p>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="$cx" cy="$cy"/>
        <wp:docPr id="${i + 1}" name="PDF Page ${i + 1}"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="${i + 1}" name="${page.fileName}"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="rId${i + 1}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$cx" cy="$cy"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
''');

      if (i < pages.length - 1) {
        body.writeln('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final archive = Archive();
    final contentTypesBytes = utf8.encode(contentTypes.toString());
    final relsBytes = utf8.encode(relsXml);
    final docXmlBytes = utf8.encode(documentXml);
    final docRelsBytes = utf8.encode(docRels.toString());

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));
    archive.addFile(ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsBytes.length, docRelsBytes));

    for (final page in pages) {
      archive.addFile(ArchiveFile('word/media/${page.fileName}', page.bytes.length, page.bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? <int>[]);
  }
}

class _RenderedPage {
  final String fileName;
  final Uint8List bytes;
  final int widthPx;
  final int heightPx;

  const _RenderedPage({
    required this.fileName,
    required this.bytes,
    required this.widthPx,
    required this.heightPx,
  });
}
