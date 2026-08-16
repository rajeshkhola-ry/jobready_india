import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Parses CSV text and writes a real Microsoft Excel (.xlsx) workbook by
/// building the Open Packaging Conventions zip directly (same technique
/// [Services/word_generator_service.dart] uses for .docx) - no third-party
/// spreadsheet-writer dependency required.
class CsvToExcelService {
  const CsvToExcelService._();

  /// RFC4180-style parser: supports quoted fields (with embedded commas and
  /// newlines), the `""` escaped-quote sequence, and both `\n`/`\r\n` line
  /// endings. A leading UTF-8 BOM is stripped if present.
  static List<List<String>> parseCsv(String csvText) {
    final text = csvText.startsWith('\uFEFF') ? csvText.substring(1) : csvText;
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentField = StringBuffer();
    var inQuotes = false;
    var i = 0;
    final length = text.length;

    void endField() {
      currentRow.add(currentField.toString());
      currentField.clear();
    }

    void endRow() {
      endField();
      rows.add(currentRow);
      currentRow = <String>[];
    }

    while (i < length) {
      final char = text[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < length && text[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        currentField.write(char);
        i++;
        continue;
      }

      if (char == '"' && currentField.isEmpty) {
        inQuotes = true;
        i++;
        continue;
      }

      if (char == ',') {
        endField();
        i++;
        continue;
      }

      if (char == '\r') {
        if (i + 1 < length && text[i + 1] == '\n') {
          i++;
        }
        endRow();
        i++;
        continue;
      }

      if (char == '\n') {
        endRow();
        i++;
        continue;
      }

      currentField.write(char);
      i++;
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      endRow();
    }

    // A trailing newline produces one extra fully-empty row - drop just that.
    if (rows.isNotEmpty && rows.last.length == 1 && rows.last.first.isEmpty) {
      rows.removeLast();
    }

    return rows;
  }

  /// Builds a minimal, valid .xlsx workbook containing a single sheet with
  /// [rows] of cell text. Values that look like plain numbers become real
  /// numeric cells (so they sort/sum correctly in Excel); everything else -
  /// including numbers with leading zeros such as zip codes - is written as
  /// inline text so no formatting/precision is silently lost.
  static Uint8List buildXlsxBytes(List<List<String>> rows, {String sheetName = 'Sheet1'}) {
    final safeSheetName = _sanitizeSheetName(sheetName);

    final archive = Archive();
    void addXmlFile(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addXmlFile('[Content_Types].xml', _contentTypesXml);
    addXmlFile('_rels/.rels', _packageRelsXml);
    addXmlFile('xl/workbook.xml', _workbookXml(safeSheetName));
    addXmlFile('xl/_rels/workbook.xml.rels', _workbookRelsXml);
    addXmlFile('xl/styles.xml', _stylesXml);
    addXmlFile('xl/worksheets/sheet1.xml', _sheetXml(rows));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

  static const String _packageRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static const String _workbookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>''';

  static String _workbookXml(String sheetName) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_escapeXml(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
  }

  static String _sheetXml(List<List<String>> rows) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..writeln('<sheetData>');

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      buffer.writeln('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final rawValue = row[c];
        if (rawValue.isEmpty) {
          continue;
        }
        final cellRef = '${_columnLetters(c)}${r + 1}';
        if (_looksNumeric(rawValue)) {
          buffer.writeln('<c r="$cellRef"><v>$rawValue</v></c>');
        } else {
          final safeValue = _escapeXml(_sanitizeXmlText(rawValue));
          buffer.writeln('<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$safeValue</t></is></c>');
        }
      }
      buffer.writeln('</row>');
    }

    buffer
      ..writeln('</sheetData>')
      ..writeln('</worksheet>');
    return buffer.toString();
  }

  /// Converts a 0-based column index to Excel-style letters (0 -> A, 25 -> Z, 26 -> AA...).
  static String _columnLetters(int index) {
    var n = index + 1;
    final letters = <String>[];
    while (n > 0) {
      final remainder = (n - 1) % 26;
      letters.add(String.fromCharCode(65 + remainder));
      n = (n - 1) ~/ 26;
    }
    return letters.reversed.join();
  }

  /// Plain integers/decimals become numeric cells; values with a leading
  /// zero (zip codes, IDs) stay text so Excel never strips the leading zero.
  static bool _looksNumeric(String value) {
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) {
      return false;
    }
    final digits = value.startsWith('-') ? value.substring(1) : value;
    if (digits.length > 1 && digits.startsWith('0') && !digits.startsWith('0.')) {
      return false;
    }
    return true;
  }

  static String _sanitizeSheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'''[\\/?*\[\]:]'''), ' ').trim();
    final trimmed = cleaned.isEmpty ? 'Sheet1' : cleaned;
    return trimmed.length > 31 ? trimmed.substring(0, 31) : trimmed;
  }

  /// Drops XML 1.0-invalid control characters (keeps tab/CR/LF) so a stray
  /// byte in the source CSV can never produce a corrupt .xlsx file.
  static String _sanitizeXmlText(String value) {
    final buffer = StringBuffer();
    for (final unit in value.codeUnits) {
      final isValid = unit == 0x9 ||
          unit == 0xA ||
          unit == 0xD ||
          (unit >= 0x20 && unit <= 0xD7FF) ||
          (unit >= 0xE000 && unit <= 0xFFFD);
      buffer.writeCharCode(isValid ? unit : 0x20);
    }
    return buffer.toString();
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
