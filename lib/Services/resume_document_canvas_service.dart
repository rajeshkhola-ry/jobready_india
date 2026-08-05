import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CanvasTemplate {
  final String id;
  final String title;
  final String category;
  final String description;
  final List<String> sections;

  const CanvasTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.sections,
  });
}

class ResumeDocumentCanvasService {
  const ResumeDocumentCanvasService._();

  static const List<CanvasTemplate> templates = <CanvasTemplate>[
    CanvasTemplate(
      id: 'resume_classic',
      title: 'Resume Classic ATS',
      category: 'Resume',
      description: 'Single-column ATS layout for jobs in govt/private sectors.',
      sections: <String>['Header', 'Summary', 'Skills', 'Experience', 'Education', 'Certifications'],
    ),
    CanvasTemplate(
      id: 'resume_modern',
      title: 'Resume Modern Dual-Panel',
      category: 'Resume',
      description: 'Readable modern style with compact sidebar sections.',
      sections: <String>['Header', 'Highlights', 'Experience', 'Projects', 'Education', 'Keywords'],
    ),
    CanvasTemplate(
      id: 'cover_letter_formal',
      title: 'Cover Letter Formal',
      category: 'Document',
      description: 'Formal role-targeted cover letter template.',
      sections: <String>['Sender', 'Recipient', 'Opening', 'Body', 'Closing', 'Signature'],
    ),
    CanvasTemplate(
      id: 'sop_higher_studies',
      title: 'Statement of Purpose (SOP)',
      category: 'Document',
      description: 'Higher studies SOP structure for admissions.',
      sections: <String>['Introduction', 'Academic Background', 'Goals', 'Why This Program', 'Conclusion'],
    ),
  ];

  static String buildTemplateJson(CanvasTemplate template) {
    final payload = <String, Object?>{
      'template_id': template.id,
      'title': template.title,
      'category': template.category,
      'description': template.description,
      'sections': template.sections,
      'fields': <Map<String, String>>[
        <String, String>{'key': 'full_name', 'label': 'Full Name'},
        <String, String>{'key': 'email', 'label': 'Email'},
        <String, String>{'key': 'phone', 'label': 'Phone'},
        <String, String>{'key': 'location', 'label': 'Location'},
      ],
      'generated_local_only': true,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String buildTemplateMarkdown(CanvasTemplate template) {
    final lines = <String>[
      '# ${template.title}',
      '',
      '> Category: ${template.category}',
      '',
      template.description,
      '',
      '## Sections',
      for (final section in template.sections) '- $section',
      '',
      '## Notes',
      '- Fill this template as per job/admission requirement.',
      '- Keep content concise and role-specific.',
      '- Export final output to PDF once completed.',
    ];
    return lines.join('\n');
  }

  static Future<Uint8List> buildTemplatePreviewPdf(CanvasTemplate template) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                template.title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.91, 0.95, 1.0),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('Category: ${template.category}', style: pw.TextStyle(fontSize: 11)),
              ),
              pw.SizedBox(height: 12),
              pw.Text(template.description, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              pw.Text('Template Sections', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...template.sections.map(
                (section) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    children: <pw.Widget>[
                      pw.Container(
                        width: 6,
                        height: 6,
                        decoration: const pw.BoxDecoration(
                          color: PdfColor(0.05, 0.22, 0.41),
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(section, style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Generated locally in GETREADYJOB canvas templates module.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColor(0.42, 0.46, 0.53)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
