import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ResumeTemplate { classic, modern, minimal }

class ResumePdfExport {
  static const String _footerText = 'Created with GETREADYJOB  ·  www.getreadyjob.com';

  static Future<Uint8List> buildPdf({
    required String name,
    required String title,
    required String summary,
    required ResumeTemplate template,
  }) async {
    final doc = pw.Document();

    switch (template) {
      case ResumeTemplate.classic:
        doc.addPage(_classicPage(name: name, title: title, summary: summary));
        break;
      case ResumeTemplate.modern:
        doc.addPage(_modernPage(name: name, title: title, summary: summary));
        break;
      case ResumeTemplate.minimal:
        doc.addPage(_minimalPage(name: name, title: title, summary: summary));
        break;
    }

    return doc.save();
  }

  // Returns the display value or a styled italic placeholder when empty.
  static pw.Widget _field(
    String value,
    String placeholder,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    if (value.isNotEmpty) {
      return pw.Text(value, style: style, textAlign: align);
    }
    return pw.Text(
      placeholder,
      style: style.copyWith(
        color: PdfColors.grey500,
        fontStyle: pw.FontStyle.italic,
      ),
      textAlign: align,
    );
  }

  static pw.Widget _footer() => pw.Text(
        _footerText,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
      );

  // ── Classic ──────────────────────────────────────────────────────────────
  static pw.Page _classicPage({
    required String name,
    required String title,
    required String summary,
  }) {
    const accent = PdfColor.fromInt(0xFF0E3A66);
    const bodyStyle = pw.TextStyle(fontSize: 11, lineSpacing: 6);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 60, vertical: 52),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _field(
            name,
            'Your Name',
            pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: accent),
          ),
          pw.SizedBox(height: 5),
          _field(
            title,
            'Job Title',
            pw.TextStyle(fontSize: 13, color: PdfColors.grey700, letterSpacing: 0.3),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: accent, thickness: 1.5),
          pw.SizedBox(height: 16),
          pw.Text(
            'PROFESSIONAL SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          _field(
            summary,
            'Add your professional summary here.',
            bodyStyle,
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          _footer(),
        ],
      ),
    );
  }

  // ── Modern ────────────────────────────────────────────────────────────────
  static pw.Page _modernPage({
    required String name,
    required String title,
    required String summary,
  }) {
    const headerBg = PdfColor.fromInt(0xFF0A84FF);
    const bodyStyle = pw.TextStyle(fontSize: 11, lineSpacing: 6);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: headerBg,
            padding: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _field(
                  name,
                  'Your Name',
                  pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                _field(
                  title,
                  'Job Title',
                  const pw.TextStyle(fontSize: 13, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(52, 36, 52, 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ABOUT ME',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: headerBg,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _field(
                    summary,
                    'Add your professional summary here.',
                    bodyStyle,
                  ),
                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                  pw.SizedBox(height: 4),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Minimal ───────────────────────────────────────────────────────────────
  static pw.Page _minimalPage({
    required String name,
    required String title,
    required String summary,
  }) {
    const bodyStyle = pw.TextStyle(fontSize: 11, lineSpacing: 6);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 72, vertical: 60),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _field(
            name,
            'Your Name',
            pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _field(
            title,
            'Job Title',
            const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey400, thickness: 0.8),
          pw.SizedBox(height: 14),
          _field(
            summary,
            'Add your professional summary here.',
            bodyStyle,
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          _footer(),
        ],
      ),
    );
  }
}
