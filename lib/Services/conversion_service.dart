import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render/pdf_render.dart' as pdf_render;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import 'compression_service.dart';
import 'word_generator_service.dart';

class ConversionResult {
  final bool success;
  final String message;
  final Uint8List? outputBytes;
  final String? outputFileName;

  const ConversionResult({
    required this.success,
    required this.message,
    this.outputBytes,
    this.outputFileName,
  });
}

class ConversionService {
  const ConversionService();

  Future<ConversionResult> convert({
    required Uint8List inputBytes,
    required String inputFileName,
    required String outputFormat,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      final format = outputFormat.toLowerCase();

      switch (format) {
        case 'word (.docx)':
          final lowerName = inputFileName.toLowerCase();
          if (lowerName.endsWith('.pdf')) {
            if (kIsWeb) {
              final extractedText = await _extractTextFromPdf(inputBytes, inputFileName);
              final fallbackWordBytes = await const WordGeneratorService().createWordDocument(
                pdfFileName: inputFileName,
                extractedText: extractedText,
              );

              return ConversionResult(
                success: true,
                message: 'Word document created in web compatibility mode.',
                outputBytes: fallbackWordBytes,
                outputFileName: _changeExtension(inputFileName, 'docx'),
              );
            }

            try {
              final wordLayoutBytes = await const WordGeneratorService().createWordDocumentFromPdfLayout(
                pdfBytes: inputBytes,
                pdfFileName: inputFileName,
              );

              return ConversionResult(
                success: true,
                message: 'Word document created with PDF pages embedded as images.',
                outputBytes: wordLayoutBytes,
                outputFileName: _changeExtension(inputFileName, 'docx'),
              );
            } catch (_) {
              try {
                final lowMemoryLayoutBytes = await const WordGeneratorService().createWordDocumentFromPdfLayout(
                  pdfBytes: inputBytes,
                  pdfFileName: inputFileName,
                  preferredTargetWidth: 900,
                  maxScale: 1.4,
                );

                return ConversionResult(
                  success: true,
                  message: 'Word document created with PDF pages embedded (optimized for memory).',
                  outputBytes: lowMemoryLayoutBytes,
                  outputFileName: _changeExtension(inputFileName, 'docx'),
                );
              } catch (_) {
                try {
                  final minimalMemoryLayoutBytes = await const WordGeneratorService().createWordDocumentFromPdfLayout(
                    pdfBytes: inputBytes,
                    pdfFileName: inputFileName,
                    preferredTargetWidth: 800,
                    maxScale: 1.0,
                  );

                  return ConversionResult(
                    success: true,
                    message: 'Word document created with PDF pages embedded (minimal memory mode).',
                    outputBytes: minimalMemoryLayoutBytes,
                    outputFileName: _changeExtension(inputFileName, 'docx'),
                  );
                } catch (_) {
                  try {
                    final extractedText = await _extractTextFromPdf(inputBytes, inputFileName);
                    final fallbackWordBytes = await const WordGeneratorService().createWordDocument(
                      pdfFileName: inputFileName,
                      extractedText: extractedText,
                    );

                    return ConversionResult(
                      success: true,
                      message: 'Word document created in fallback text mode.',
                      outputBytes: fallbackWordBytes,
                      outputFileName: _changeExtension(inputFileName, 'docx'),
                    );
                  } catch (_) {
                    return ConversionResult(
                      success: false,
                      message: 'PDF to Word conversion could not generate the document. The PDF file may be too complex or memory is insufficient. Try splitting the PDF into smaller files.',
                    );
                  }
                }
              }
            }
          } else {
            final extractedText = await _extractAnyText(inputBytes, inputFileName);

            final wordBytes = await const WordGeneratorService().createWordDocument(
              pdfFileName: inputFileName,
              extractedText: extractedText,
            );

            return ConversionResult(
              success: true,
              message: 'Word document created successfully.',
              outputBytes: wordBytes,
              outputFileName: _changeExtension(inputFileName, 'docx'),
            );
          }

        case 'text (.txt)':
          final extractedText = await _extractAnyText(inputBytes, inputFileName);

          return ConversionResult(
            success: true,
            message: 'Text file created successfully.',
            outputBytes: Uint8List.fromList(utf8.encode(extractedText)),
            outputFileName: _changeExtension(inputFileName, 'txt'),
          );

        case 'pdf (.pdf)':
          return await _convertToPdf(inputBytes, inputFileName);

        case 'csv (.csv)':
          return _convertToCsv(inputBytes, inputFileName);

        case 'jpg images':
          return await _convertToImage(inputBytes, inputFileName, 'jpg');

        case 'png images':
          return await _convertToImage(inputBytes, inputFileName, 'png');

        case 'webp (.webp)':
          return await _convertToImage(inputBytes, inputFileName, 'webp');

        case 'powerpoint (.pptx)':
          return await _convertToPowerPoint(inputBytes, inputFileName);

        case 'compress pdf':
          if (!inputFileName.toLowerCase().endsWith('.pdf')) {
            return const ConversionResult(
              success: false,
              message: 'PDF compression currently supports only PDF input.',
            );
          }

          final targetBytes = max(150 * 1024, (inputBytes.length * 0.6).round());

          final compressedBytes = await const CompressionService().compressPdf(
            inputBytes,
            targetBytes,
            inputFileName,
          );

          if (compressedBytes.isEmpty) {
            return const ConversionResult(
              success: false,
              message: 'PDF compression failed.',
            );
          }

          return ConversionResult(
            success: true,
            message: 'PDF compressed successfully.',
            outputBytes: compressedBytes,
            outputFileName: inputFileName,
          );

        default:
          return const ConversionResult(
            success: false,
            message: 'Unsupported conversion format.',
          );
      }
    } catch (e) {
      return ConversionResult(
        success: false,
        message: 'Conversion failed: $e',
      );
    }
  }

  Future<ConversionResult> _convertToPdf(
    Uint8List inputBytes,
    String inputFileName,
  ) async {
    final lowerName = inputFileName.toLowerCase();

    if (lowerName.endsWith('.pdf')) {
      return ConversionResult(
        success: true,
        message: 'PDF file is already ready.',
        outputBytes: inputBytes,
        outputFileName: _changeExtension(inputFileName, 'pdf'),
      );
    }

    if (_isImageName(lowerName)) {
      final pdfBytes = await _createPdfFromImage(inputBytes);
      return ConversionResult(
        success: true,
        message: 'PDF created from image successfully.',
        outputBytes: pdfBytes,
        outputFileName: _changeExtension(inputFileName, 'pdf'),
      );
    }

    if (lowerName.endsWith('.doc')) {
      return const ConversionResult(
        success: false,
        message:
            'Legacy Word (.doc) conversion is not supported reliably in this build. Please resave the file as .docx, then convert to PDF.',
      );
    }

    if (lowerName.endsWith('.docx')) {
      final pdfBytes = await _createPdfFromDocx(inputBytes, inputFileName);
      return ConversionResult(
        success: true,
        message: 'PDF created from Word document successfully.',
        outputBytes: pdfBytes,
        outputFileName: _changeExtension(inputFileName, 'pdf'),
      );
    }

    final text = await _extractAnyText(inputBytes, inputFileName);
    final pdfBytes = await _createPdfFromText(inputFileName, text);
    return ConversionResult(
      success: true,
      message: 'PDF created successfully.',
      outputBytes: pdfBytes,
      outputFileName: _changeExtension(inputFileName, 'pdf'),
    );
  }

  ConversionResult _convertToCsv(
    Uint8List inputBytes,
    String inputFileName,
  ) {
    final lowerName = inputFileName.toLowerCase();

    if (lowerName.endsWith('.csv')) {
      return ConversionResult(
        success: true,
        message: 'CSV is already ready.',
        outputBytes: inputBytes,
        outputFileName: _changeExtension(inputFileName, 'csv'),
      );
    }

    if (lowerName.endsWith('.xlsx')) {
      final csv = _extractCsvFromXlsx(inputBytes);
      if (csv.isEmpty) {
        return const ConversionResult(
          success: false,
          message: 'Unable to parse XLSX data. Please check the file and try again.',
        );
      }
      final normalizedCsv = csv
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')
          .join('\r\n');
      const bom = <int>[0xEF, 0xBB, 0xBF];
      final csvBytes = Uint8List.fromList(<int>[...bom, ...utf8.encode(normalizedCsv)]);
      return ConversionResult(
        success: true,
        message: 'CSV file created successfully.',
        outputBytes: csvBytes,
        outputFileName: _changeExtension(inputFileName, 'csv'),
      );
    }

    return const ConversionResult(
      success: false,
      message: 'CSV conversion supports .csv and .xlsx files.',
    );
  }

  Future<ConversionResult> _convertToImage(
    Uint8List inputBytes,
    String inputFileName,
    String targetType,
  ) async {
    final lowerName = inputFileName.toLowerCase();

    if (lowerName.endsWith('.pdf')) {
      if (kIsWeb) {
        try {
          final extractedText = await _extractTextFromPdf(inputBytes, inputFileName);
          final imageBytes = _createImageFromTextSummary(
            title: inputFileName,
            text: extractedText,
            targetType: targetType,
          );
          final archive = Archive();
          final extension = targetType == 'jpg' ? 'jpg' : 'png';
          final fallbackName = '${_baseName(inputFileName)}_summary.$extension';
          archive.addFile(ArchiveFile(fallbackName, imageBytes.length, imageBytes));
          final zip = ZipEncoder().encode(archive);

          return ConversionResult(
            success: true,
            message: '${targetType.toUpperCase()} summary image created in web compatibility mode.',
            outputBytes: zip == null ? imageBytes : Uint8List.fromList(zip),
            outputFileName: '${_baseName(inputFileName)}_${targetType}_pages.zip',
          );
        } catch (e) {
          return ConversionResult(
            success: false,
            message: 'Unable to export PDF pages as ${targetType.toUpperCase()} images on web: $e',
          );
        }
      }

      try {
        final imageBytes = await _renderPdfPagesAsArchive(
          pdfBytes: inputBytes,
          inputFileName: inputFileName,
          targetType: targetType,
        );

        return ConversionResult(
          success: true,
          message: '${targetType.toUpperCase()} pages exported from PDF.',
          outputBytes: imageBytes,
          outputFileName: '${_baseName(inputFileName)}_${targetType}_pages.zip',
        );
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (_isLikelyPasswordProtectedError(message)) {
          return const ConversionResult(
            success: false,
            message:
                'This PDF appears to be password-protected. Please remove the password first, then try conversion again.',
          );
        }

        return ConversionResult(
          success: false,
          message: 'Unable to export PDF pages as images: $e',
        );
      }
    }

    if (_isImageName(lowerName)) {
      final imageBytes = _convertImageBytes(inputBytes, targetType);
      return ConversionResult(
        success: true,
        message: '${targetType.toUpperCase()} image created successfully.',
        outputBytes: imageBytes,
        outputFileName: _changeExtension(inputFileName, targetType == 'jpg' ? 'jpg' : targetType),
      );
    }

    return ConversionResult(
      success: false,
      message: '${targetType.toUpperCase()} conversion supports PDF or image inputs.',
    );
  }

  Future<ConversionResult> _convertToPowerPoint(
    Uint8List inputBytes,
    String inputFileName,
  ) async {
    final lowerName = inputFileName.toLowerCase();

    if (lowerName.endsWith('.pptx')) {
      return ConversionResult(
        success: true,
        message: 'PowerPoint file is already ready.',
        outputBytes: inputBytes,
        outputFileName: _changeExtension(inputFileName, 'pptx'),
      );
    }

    try {
      final text = await _extractAnyText(inputBytes, inputFileName);
      final pptxBytes = _buildSimplePptx(
        title: _baseName(inputFileName),
        sourceFileName: inputFileName,
        content: text,
      );

      return ConversionResult(
        success: true,
        message: 'PowerPoint created successfully.',
        outputBytes: pptxBytes,
        outputFileName: _changeExtension(inputFileName, 'pptx'),
      );
    } catch (e) {
      return ConversionResult(
        success: false,
        message: 'PowerPoint conversion failed: $e',
      );
    }
  }

  Uint8List _buildSimplePptx({
    required String title,
    required String sourceFileName,
    required String content,
  }) {
    String xmlEscape(String value) {
      return value
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
    }

    final normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    final lines = normalized.isEmpty
        ? <String>['No readable content found for conversion.']
        : normalized
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .take(48)
            .toList(growable: false);

    final slideTitle = xmlEscape('$title (from $sourceFileName)');
    final slideGroups = <List<String>>[];
    for (var i = 0; i < lines.length; i += 8) {
      slideGroups.add(lines.sublist(i, min(i + 8, lines.length)));
    }
    if (slideGroups.isEmpty) {
      slideGroups.add(const <String>['No readable content found for conversion.']);
    }

    String buildTextBody(List<String> parts) {
      return parts
          .map((part) => '<a:p><a:r><a:t>${xmlEscape(part)}</a:t></a:r></a:p>')
          .join();
    }

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>
  <Override PartName="/ppt/viewProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"/>
  <Override PartName="/ppt/tableStyles.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
${List<String>.generate(slideGroups.length, (index) => '  <Override PartName="/ppt/slides/slide${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n')}
</Types>''';

    final rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

    final appXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>JOBREADY</Application>
  <PresentationFormat>On-screen Show (4:3)</PresentationFormat>
  <Slides>${slideGroups.length}</Slides>
  <Notes>0</Notes>
  <HiddenSlides>0</HiddenSlides>
  <MMClips>0</MMClips>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Theme</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>1</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="1" baseType="lpstr">
      <vt:lpstr>Office Theme</vt:lpstr>
    </vt:vector>
  </TitlesOfParts>
  <Company>JOBREADY</Company>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>1.0</AppVersion>
</Properties>''';

    final coreXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${xmlEscape(title)}</dc:title>
  <dc:creator>JOBREADY</dc:creator>
  <cp:lastModifiedBy>JOBREADY</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">2026-07-18T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">2026-07-18T00:00:00Z</dcterms:modified>
</cp:coreProperties>''';

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId1"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
${List<String>.generate(slideGroups.length, (index) => '    <p:sldId id="${256 + index}" r:id="rId${index + 2}"/>').join('\n')}
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:defaultTextStyle/>
</p:presentation>''';

    final presentationRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
${List<String>.generate(slideGroups.length, (index) => '  <Relationship Id="rId${index + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${index + 1}.xml"/>').join('\n')}
  <Relationship Id="rId${slideGroups.length + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps" Target="presProps.xml"/>
  <Relationship Id="rId${slideGroups.length + 3}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps" Target="viewProps.xml"/>
  <Relationship Id="rId${slideGroups.length + 4}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles" Target="tableStyles.xml"/>
</Relationships>''';

    final presPropsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentationPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" showSpecialPlsOnTitleSld="0" rtl="0" removePersonalInfoOnSave="0" compatMode="1" strictFirstAndLastChars="0"/>
''';

    final viewPropsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:viewPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:normalViewPr/>
  <p:slideViewPr/>
  <p:notesTextViewPr/>
  <p:gridSpacing cx="780288" cy="780288"/>
</p:viewPr>''';

    final tableStylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>
''';

    final slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld name="Office Theme">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
  <p:txStyles>
    <p:titleStyle/><p:bodyStyle/><p:otherStyle/>
  </p:txStyles>
</p:sldMaster>''';

    final slideMasterRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';

    final slideLayoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="titleAndText" preserve="1">
  <p:cSld name="Title and Content">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title Placeholder 1"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:spPr/>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content Placeholder 2"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
        <p:spPr/>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''';

    final themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F1F1F"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
  <a:objectDefaults/>
  <a:extraClrSchemeLst/>
</a:theme>''';

    String buildSlideXml(int slideNumber, List<String> bodyLines) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="274320"/><a:ext cx="8229600" cy="914400"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>${slideNumber == 1 ? slideTitle : xmlEscape('$title - Part $slideNumber')}</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr/><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="1371600"/><a:ext cx="8229600" cy="4572000"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr wrap="square"/><a:lstStyle/>${buildTextBody(bodyLines)}</p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''';

    final slideRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';

    final archive = Archive()
      ..addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypes).length, utf8.encode(contentTypes)))
      ..addFile(ArchiveFile('_rels/.rels', utf8.encode(rootRels).length, utf8.encode(rootRels)))
      ..addFile(ArchiveFile('docProps/app.xml', utf8.encode(appXml).length, utf8.encode(appXml)))
      ..addFile(ArchiveFile('docProps/core.xml', utf8.encode(coreXml).length, utf8.encode(coreXml)))
      ..addFile(ArchiveFile('ppt/presentation.xml', utf8.encode(presentationXml).length, utf8.encode(presentationXml)))
      ..addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode(presentationRels).length, utf8.encode(presentationRels)))
      ..addFile(ArchiveFile('ppt/presProps.xml', utf8.encode(presPropsXml).length, utf8.encode(presPropsXml)))
      ..addFile(ArchiveFile('ppt/viewProps.xml', utf8.encode(viewPropsXml).length, utf8.encode(viewPropsXml)))
      ..addFile(ArchiveFile('ppt/tableStyles.xml', utf8.encode(tableStylesXml).length, utf8.encode(tableStylesXml)))
      ..addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', utf8.encode(slideMasterXml).length, utf8.encode(slideMasterXml)))
      ..addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', utf8.encode(slideMasterRelsXml).length, utf8.encode(slideMasterRelsXml)))
      ..addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', utf8.encode(slideLayoutXml).length, utf8.encode(slideLayoutXml)))
      ..addFile(ArchiveFile('ppt/theme/theme1.xml', utf8.encode(themeXml).length, utf8.encode(themeXml)));

    for (var i = 0; i < slideGroups.length; i++) {
      final slideXml = buildSlideXml(i + 1, slideGroups[i]);
      archive
        ..addFile(ArchiveFile('ppt/slides/slide${i + 1}.xml', utf8.encode(slideXml).length, utf8.encode(slideXml)))
        ..addFile(ArchiveFile('ppt/slides/_rels/slide${i + 1}.xml.rels', utf8.encode(slideRelsXml).length, utf8.encode(slideRelsXml)));
    }

    final zip = ZipEncoder().encode(archive);
    if (zip == null) {
      throw Exception('Unable to build PPTX package.');
    }

    return Uint8List.fromList(zip);
  }

  String _changeExtension(
    String fileName,
    String newExtension,
  ) {
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1) {
      return '$fileName.$newExtension';
    }

    return '${fileName.substring(0, dotIndex)}.$newExtension';
  }

  Future<String> _extractTextFromPdf(
    Uint8List pdfBytes,
    String pdfName,
  ) async {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        final extractedText = sfpdf.PdfTextExtractor(document).extractText();
        final normalizedText = extractedText.trim();
        if (normalizedText.isEmpty) {
          return 'No readable text was found in the selected PDF file.';
        }
        return normalizedText;
      } finally {
        document.dispose();
      }
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (_isLikelyPasswordProtectedError(message)) {
        return 'This PDF appears to be password-protected. Remove password and try again.';
      }
      return 'Unable to extract text from the selected PDF. Error: $e';
    }
  }

  bool _isLikelyPasswordProtectedError(String message) {
    return message.contains('password') ||
        message.contains('encrypted') ||
        message.contains('security') ||
        message.contains('permission');
  }

  Future<String> _extractAnyText(Uint8List inputBytes, String inputFileName) async {
    final lowerName = inputFileName.toLowerCase();

    if (lowerName.endsWith('.pdf')) {
      return _extractTextFromPdf(inputBytes, inputFileName);
    }

    if (lowerName.endsWith('.doc')) {
      return 'Legacy Word (.doc) source detected: $inputFileName. For best text fidelity, resave as .docx before converting.';
    }

    if (lowerName.endsWith('.docx')) {
      return _extractTextFromDocx(inputBytes);
    }

    if (lowerName.endsWith('.xls')) {
      return 'Legacy Excel (.xls) source detected: $inputFileName. For best table extraction, resave as .xlsx before converting.';
    }

    if (lowerName.endsWith('.csv') || lowerName.endsWith('.xlsx')) {
      return _extractTextFromExcel(inputBytes, inputFileName);
    }

    if (lowerName.endsWith('.pptx')) {
      return _extractTextFromPptx(inputBytes);
    }

    if (_isImageName(lowerName)) {
      return 'Image conversion source: $inputFileName';
    }

    return 'Unable to parse structured text from this file. Source file: $inputFileName';
  }

  String _extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final file = archive.files.firstWhere(
        (entry) => entry.name == 'word/document.xml',
      );
      final xmlText = utf8.decode(file.content as List<int>, allowMalformed: true);
      return _cleanXmlText(xmlText).trim();
    } catch (_) {
      return 'Unable to parse DOCX content.';
    }
  }

  String _extractTextFromPptx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final slideFiles = archive.files
          .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));

      if (slideFiles.isEmpty) {
        return 'No slide text found in PPTX.';
      }

      final parts = <String>[];
      for (var i = 0; i < slideFiles.length; i++) {
        final xmlText = utf8.decode(slideFiles[i].content as List<int>, allowMalformed: true);
        final clean = _cleanXmlText(xmlText).trim();
        if (clean.isNotEmpty) {
          parts.add('Slide ${i + 1}: $clean');
        }
      }

      if (parts.isEmpty) {
        return 'No readable text found in PPTX slides.';
      }

      return parts.join('\n\n');
    } catch (_) {
      return 'Unable to parse PPTX content.';
    }
  }

  String _extractTextFromExcel(Uint8List bytes, String inputFileName) {
    final lowerName = inputFileName.toLowerCase();
    if (lowerName.endsWith('.csv')) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (lowerName.endsWith('.xlsx')) {
      return _extractCsvFromXlsx(bytes);
    }
    return 'Excel text extraction currently supports CSV and XLSX.';
  }

  String _extractCsvFromXlsx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);

      final sharedFile = archive.files.where((f) => f.name == 'xl/sharedStrings.xml').toList();
      final sharedStrings = <String>[];
      if (sharedFile.isNotEmpty) {
        final sharedXml = utf8.decode(sharedFile.first.content as List<int>, allowMalformed: true);
        final sharedMatches = RegExp(r'<si[^>]*>([\\s\\S]*?)</si>').allMatches(sharedXml);
        for (final match in sharedMatches) {
          final si = match.group(1) ?? '';
          final textMatches = RegExp(r'<t[^>]*>([\\s\\S]*?)</t>').allMatches(si);
          final value = textMatches.map((m) => _decodeXmlEntities(m.group(1) ?? '')).join();
          sharedStrings.add(value);
        }
      }

      final sheet = archive.files.firstWhere(
        (f) => f.name == 'xl/worksheets/sheet1.xml',
        orElse: () => archive.files.firstWhere(
          (f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'),
        ),
      );

      final sheetXml = utf8.decode(sheet.content as List<int>, allowMalformed: true);
      final rows = RegExp(r'<row[^>]*>([\\s\\S]*?)</row>').allMatches(sheetXml);
      final csvRows = <String>[];

      for (final row in rows) {
        final rowXml = row.group(1) ?? '';
        final cells = RegExp(r'<c([^>]*)>([\\s\\S]*?)</c>').allMatches(rowXml);

        final ordered = <int, String>{};
        var maxCol = 0;

        for (final cell in cells) {
          final attrs = cell.group(1) ?? '';
          final body = cell.group(2) ?? '';
          final rAttr = RegExp(r'r="([A-Z]+)\\d+"').firstMatch(attrs)?.group(1);
          final colIndex = rAttr == null ? ordered.length : _columnIndexFromRef(rAttr);
          maxCol = max(maxCol, colIndex);

          final type = RegExp(r't="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final v = RegExp(r'<v[^>]*>([\\s\\S]*?)</v>').firstMatch(body)?.group(1) ?? '';

          String value;
          if (type == 's') {
            final sharedIndex = int.tryParse(v) ?? -1;
            value = (sharedIndex >= 0 && sharedIndex < sharedStrings.length)
                ? sharedStrings[sharedIndex]
                : '';
          } else {
            value = _decodeXmlEntities(v);
          }

          ordered[colIndex] = value;
        }

        if (ordered.isEmpty) {
          continue;
        }

        final values = List<String>.generate(maxCol + 1, (i) => ordered[i] ?? '');
        csvRows.add(values.map(_escapeCsv).join(','));
      }

      if (csvRows.isEmpty) {
        return '';
      }

      return csvRows.join('\n');
    } catch (_) {
      return '';
    }
  }

  int _columnIndexFromRef(String ref) {
    var index = 0;
    for (final codeUnit in ref.codeUnits) {
      index = (index * 26) + (codeUnit - 64);
    }
    return max(0, index - 1);
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _cleanXmlText(String xmlText) {
    final withLineBreaks = xmlText
        .replaceAll(RegExp(r'</w:p>|</a:p>|</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\\s*/?>', caseSensitive: false), '\n');

    final noTags = withLineBreaks.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalized = _decodeXmlEntities(noTags)
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s+'), '\n')
        .trim();
    return normalized;
  }

  String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#10;', '\n')
        .replaceAll('&#13;', '\r')
        .replaceAll('&#9;', '\t');
  }

  bool _isImageName(String lowerName) {
    return lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.bmp');
  }

  String _baseName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  Future<Uint8List> createPdfFromImages({
    required List<Uint8List> imageBytesList,
    List<String>? imageNames,
  }) async {
    if (imageBytesList.isEmpty) {
      return _createPdfFromText('images', 'No image content found.');
    }

    final doc = pw.Document();

    for (var i = 0; i < imageBytesList.length; i++) {
      final bytes = imageBytesList[i];
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        final fallbackName = (imageNames != null && i < imageNames.length)
            ? imageNames[i]
            : 'Image ${i + 1}';
        doc.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text('Unable to decode $fallbackName'),
            ),
          ),
        );
        continue;
      }

      final normalizedJpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      final image = pw.MemoryImage(normalizedJpg);

      doc.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<Uint8List> _createPdfFromText(String fileName, String text) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Converted from: $fileName',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(text.isEmpty ? 'No readable content found.' : text),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _createPdfFromDocx(Uint8List bytes, String fileName) async {
    final doc = pw.Document();
    final blocks = _extractDocxBlocks(bytes);

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Converted from: $fileName',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
          ];

          if (blocks.isEmpty) {
            widgets.add(pw.Text('No readable DOCX content found.'));
            return widgets;
          }

          for (final block in blocks) {
            if (block.isEmpty) {
              widgets.add(pw.SizedBox(height: 8));
              continue;
            }

            final isLikelyHeading = block.length <= 80 && !block.contains('|');
            widgets.add(
              pw.Text(
                block,
                style: pw.TextStyle(
                  fontSize: isLikelyHeading ? 12.5 : 11,
                  fontWeight: isLikelyHeading ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: isLikelyHeading ? 8 : 5));
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  List<String> _extractDocxBlocks(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final file = archive.files.firstWhere(
        (entry) => entry.name == 'word/document.xml',
      );
      final xmlText = utf8.decode(file.content as List<int>, allowMalformed: true);

      final paragraphs = RegExp(r'<w:p[\s\S]*?</w:p>', caseSensitive: false)
          .allMatches(xmlText)
          .map((match) => match.group(0) ?? '')
          .toList(growable: false);

      final blocks = <String>[];
      for (final paragraphXml in paragraphs) {
        final tableCells = RegExp(r'<w:tc[\s\S]*?</w:tc>', caseSensitive: false)
            .allMatches(paragraphXml)
            .map((cell) => _cleanXmlText(cell.group(0) ?? '').trim())
            .where((cell) => cell.isNotEmpty)
            .toList(growable: false);

        if (tableCells.isNotEmpty) {
          blocks.add(tableCells.join(' | '));
          continue;
        }

        final clean = _cleanXmlText(paragraphXml).trim();
        if (clean.isNotEmpty) {
          blocks.add(clean);
        } else {
          blocks.add('');
        }
      }

      return blocks;
    } catch (_) {
      final fallback = _extractTextFromDocx(bytes).trim();
      if (fallback.isEmpty) {
        return const <String>[];
      }
      return fallback.split(RegExp(r'\n{2,}|\r\n\r\n')).map((part) => part.trim()).toList(growable: false);
    }
  }

  Future<Uint8List> _createPdfFromImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _createPdfFromText('image', 'Unable to decode image.');
    }

    final jpegBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    final image = pw.MemoryImage(jpegBytes);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _renderPdfPagesAsArchive({
    required Uint8List pdfBytes,
    required String inputFileName,
    required String targetType,
  }) async {
    final doc = await pdf_render.PdfDocument.openData(pdfBytes);
    try {
      final archive = Archive();
      final baseName = _baseName(inputFileName);

      for (var pageIndex = 1; pageIndex <= doc.pageCount; pageIndex++) {
        final page = await doc.getPage(pageIndex);
        final sourceWidth = max(1, page.width.round());
        final sourceHeight = max(1, page.height.round());
        const maxSide = 1600;
        final largestSide = max(sourceWidth, sourceHeight);
        final scale = largestSide > maxSide ? (maxSide / largestSide) : 1.0;
        final width = max(1, (sourceWidth * scale).round());
        final height = max(1, (sourceHeight * scale).round());

        final rendered = await page.render(
          width: width,
          height: height,
          backgroundFill: true,
        );

        final image = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: rendered.pixels.buffer,
          bytesOffset: rendered.pixels.offsetInBytes,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );

        rendered.dispose();

        final extension = targetType == 'jpg' ? 'jpg' : 'png';
        final fileName = '${baseName}_page_${pageIndex.toString().padLeft(3, '0')}.$extension';
        final bytes = targetType == 'jpg'
            ? Uint8List.fromList(img.encodeJpg(image, quality: 88))
            : Uint8List.fromList(img.encodePng(image, level: 6));

        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }

      final zip = ZipEncoder().encode(archive);
      if (zip == null) {
        throw Exception('Unable to create page archive.');
      }

      return Uint8List.fromList(zip);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (_isLikelyPasswordProtectedError(message)) {
        throw Exception('Password protected PDF is not supported for image export.');
      }

      // Keep conversion available on runtimes where PDF page rendering is restricted.
      final extractedText = await _extractTextFromPdf(pdfBytes, inputFileName);
      final imageBytes = _createImageFromTextSummary(
        title: inputFileName,
        text: extractedText,
        targetType: targetType,
      );

      final archive = Archive();
      final extension = targetType == 'jpg' ? 'jpg' : 'png';
      final fallbackName = '${_baseName(inputFileName)}_summary.$extension';
      archive.addFile(ArchiveFile(fallbackName, imageBytes.length, imageBytes));
      final zip = ZipEncoder().encode(archive);
      if (zip == null) {
        return imageBytes;
      }
      return Uint8List.fromList(zip);
    } finally {
      await doc.dispose();
    }
  }

  Uint8List _convertImageBytes(Uint8List bytes, String targetType) {
    final source = img.decodeImage(bytes);
    if (source == null) {
      return bytes;
    }

    if (targetType == 'jpg') {
      return Uint8List.fromList(img.encodeJpg(source, quality: 90));
    }
    if (targetType == 'webp') {
      return Uint8List.fromList(img.encodePng(source, level: 6));
    }
    return Uint8List.fromList(img.encodePng(source, level: 6));
  }

  Uint8List _createImageFromTextSummary({
    required String title,
    required String text,
    required String targetType,
  }) {
    final canvas = img.Image(width: 1400, height: 1800);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    img.drawString(
      canvas,
      'JOBREADY PDF IMAGE PREVIEW',
      font: img.arial24,
      x: 30,
      y: 30,
      color: img.ColorRgb8(20, 40, 90),
    );

    img.drawString(
      canvas,
      'Source: $title',
      font: img.arial14,
      x: 30,
      y: 75,
      color: img.ColorRgb8(60, 60, 60),
    );

    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final previewText = normalized.isEmpty
        ? 'No readable text was found in this PDF on web-safe mode.'
        : normalized;

    final chunk = 95;
    var line = 0;
    for (var i = 0; i < previewText.length; i += chunk) {
      final end = min(i + chunk, previewText.length);
      final segment = previewText.substring(i, end);
      final y = 120 + (line * 22);
      if (y > canvas.height - 40) {
        break;
      }
      img.drawString(
        canvas,
        segment,
        font: img.arial14,
        x: 30,
        y: y,
        color: img.ColorRgb8(20, 20, 20),
      );
      line += 1;
    }

    if (targetType == 'jpg') {
      return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    }

    return Uint8List.fromList(img.encodePng(canvas, level: 6));
  }
}
