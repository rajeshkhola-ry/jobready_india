// Scalable resume template gallery: layout style x color theme combinations.
// Each layout uses pw.MultiPage so content always auto-paginates to fit A4,
// no matter how many fields are filled in or left empty.
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

enum ResumeLayoutStyle {
  classic,
  modern,
  minimal,
  twoColumn,
  sidebar,
  timeline,
  compact,
  executive,
}

class ResumeColorTheme {
  final String name;
  final int primaryArgb;
  final int tintArgb;

  const ResumeColorTheme(this.name, this.primaryArgb, this.tintArgb);

  pdf.PdfColor get primary => pdf.PdfColor.fromInt(primaryArgb);
  pdf.PdfColor get tint => pdf.PdfColor.fromInt(tintArgb);
}

class ResumeFields {
  final String fullName;
  final String email;
  final String phone;
  final String targetRole;
  final String summary;
  final String experience;
  final String education;
  final String skills;
  final String projects;

  const ResumeFields({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.targetRole = '',
    this.summary = '',
    this.experience = '',
    this.education = '',
    this.skills = '',
    this.projects = '',
  });
}

class ResumeTemplateOption {
  final String id;
  final String layoutLabel;
  final ResumeLayoutStyle layout;
  final ResumeColorTheme theme;

  const ResumeTemplateOption({
    required this.id,
    required this.layoutLabel,
    required this.layout,
    required this.theme,
  });

  String get displayName => '$layoutLabel \u2014 ${theme.name}';
}

class ResumeTemplateGallery {
  static const List<ResumeColorTheme> colorThemes = [
    ResumeColorTheme('Navy Blue', 0xFF0E3A66, 0xFFEFF4FA),
    ResumeColorTheme('Ocean Blue', 0xFF0A84FF, 0xFFEAF4FF),
    ResumeColorTheme('Emerald Green', 0xFF0F766E, 0xFFE6F5F3),
    ResumeColorTheme('Charcoal Gray', 0xFF374151, 0xFFF1F2F4),
    ResumeColorTheme('Royal Purple', 0xFF6D28D9, 0xFFF1EBFC),
    ResumeColorTheme('Crimson Red', 0xFFB91C1C, 0xFFFBEAEA),
    ResumeColorTheme('Slate Teal', 0xFF0E7490, 0xFFE6F3F6),
    ResumeColorTheme('Amber Gold', 0xFFB45309, 0xFFFCF0E0),
    ResumeColorTheme('Rose Pink', 0xFFBE185D, 0xFFFBE9F1),
    ResumeColorTheme('Indigo', 0xFF4338CA, 0xFFEBEAFB),
    ResumeColorTheme('Forest Green', 0xFF166534, 0xFFE7F3EA),
    ResumeColorTheme('Graphite Black', 0xFF111827, 0xFFEDEEF0),
    ResumeColorTheme('Sunset Orange', 0xFFC2410C, 0xFFFCEAE0),
  ];

  static const Map<ResumeLayoutStyle, String> layoutLabels = {
    ResumeLayoutStyle.classic: 'Classic',
    ResumeLayoutStyle.modern: 'Modern Header',
    ResumeLayoutStyle.minimal: 'Minimal',
    ResumeLayoutStyle.twoColumn: 'Two-Column',
    ResumeLayoutStyle.sidebar: 'Sidebar',
    ResumeLayoutStyle.timeline: 'Timeline',
    ResumeLayoutStyle.compact: 'Compact',
    ResumeLayoutStyle.executive: 'Executive',
  };

  static List<ResumeTemplateOption> buildCatalog() {
    final options = <ResumeTemplateOption>[];
    for (final layout in ResumeLayoutStyle.values) {
      final label = layoutLabels[layout]!;
      for (final theme in colorThemes) {
        options.add(
          ResumeTemplateOption(
            id: '${layout.name}_${theme.name.toLowerCase().replaceAll(' ', '_')}',
            layoutLabel: label,
            layout: layout,
            theme: theme,
          ),
        );
      }
    }
    return options;
  }

  static Future<Uint8List> buildResumePdf({
    required ResumeFields fields,
    required ResumeTemplateOption template,
    Uint8List? photoBytes,
  }) async {
    final photo = (photoBytes != null && photoBytes.isNotEmpty) ? pw.MemoryImage(photoBytes) : null;
    final doc = pw.Document();

    switch (template.layout) {
      case ResumeLayoutStyle.classic:
        doc.addPage(_classicLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.modern:
        doc.addPage(_modernLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.minimal:
        doc.addPage(_minimalLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.twoColumn:
        doc.addPage(_columnLayout(fields, template.theme, photo, sidebarOnRight: false));
        break;
      case ResumeLayoutStyle.sidebar:
        doc.addPage(_columnLayout(fields, template.theme, photo, sidebarOnRight: true));
        break;
      case ResumeLayoutStyle.timeline:
        doc.addPage(_timelineLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.compact:
        doc.addPage(_compactLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.executive:
        doc.addPage(_executiveLayout(fields, template.theme, photo));
        break;
    }

    return doc.save();
  }

  // ---- shared helpers ----

  static List<pw.Widget> _section(String title, String body, pdf.PdfColor accent, {double fontSize = 10, double gap = 12}) {
    if (body.trim().isEmpty) {
      return const [];
    }
    return [
      pw.SizedBox(height: gap),
      pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 1.1)),
      pw.SizedBox(height: 4),
      pw.Text(body.trim(), style: pw.TextStyle(fontSize: fontSize, lineSpacing: 4)),
    ];
  }

  static List<pw.Widget> _bulletSection(String title, String body, pdf.PdfColor accent) {
    if (body.trim().isEmpty) {
      return const [];
    }
    final lines = body.trim().split('\n').where((line) => line.trim().isNotEmpty).toList();
    return [
      pw.SizedBox(height: 12),
      pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 1.1)),
      pw.SizedBox(height: 6),
      ...lines.map(
        (line) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, right: 8),
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(child: pw.Text(line.trim(), style: const pw.TextStyle(fontSize: 10, lineSpacing: 4))),
            ],
          ),
        ),
      ),
    ];
  }

  static String _contactLine(ResumeFields f) {
    final parts = <String>[
      if (f.email.trim().isNotEmpty) f.email.trim(),
      if (f.phone.trim().isNotEmpty) f.phone.trim(),
    ];
    // Plain ASCII separator: the default PDF font has no glyph for U+2022 (bullet).
    return parts.join('   |   ');
  }

  static pw.Widget? _photoWidget(pw.MemoryImage? photo, {double size = 78}) {
    if (photo == null) {
      return null;
    }
    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Image(photo, width: size, height: size, fit: pw.BoxFit.cover),
    );
  }

  // ---- layouts ----

  static pw.Page _classicLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 46),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                  if (f.targetRole.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 12, color: pdf.PdfColors.grey700)),
                  ],
                  if (_contactLine(f).isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey600)),
                  ],
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: theme.primary, thickness: 1.3),
        ..._section('Profile', f.summary, theme.primary),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
      ],
    );
  }

  static pw.Page _modernLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 66);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: pw.BoxDecoration(color: theme.primary, borderRadius: pw.BorderRadius.circular(14)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.white)),
                    if (f.targetRole.trim().isNotEmpty) pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 12, color: pdf.PdfColors.white)),
                    if (_contactLine(f).isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.white)),
                    ],
                  ],
                ),
              ),
              if (photoWidget != null) photoWidget,
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        ..._section('Profile', f.summary, theme.primary),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
      ],
    );
  }

  static pw.Page _minimalLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 60);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 64, vertical: 56),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  if (f.targetRole.trim().isNotEmpty) pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.grey600)),
                  if (_contactLine(f).isNotEmpty) pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey500)),
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: pdf.PdfColors.grey400, thickness: 0.7),
        ..._section('Profile', f.summary, theme.primary, fontSize: 9.5),
        ..._section('Experience', f.experience, theme.primary, fontSize: 9.5),
        ..._section('Education', f.education, theme.primary, fontSize: 9.5),
        ..._section('Skills', f.skills, theme.primary, fontSize: 9.5),
        ..._section('Projects / Achievements', f.projects, theme.primary, fontSize: 9.5),
      ],
    );
  }

  static pw.Page _columnLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo, {required bool sidebarOnRight}) {
    final photoWidget = _photoWidget(photo, size: 84);

    final sidebar = pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: theme.tint, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (photoWidget != null) ...[
            pw.Center(child: photoWidget),
            pw.SizedBox(height: 12),
          ],
          pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: theme.primary)),
          if (f.targetRole.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey700)),
          ],
          if (f.email.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(f.email.trim(), style: const pw.TextStyle(fontSize: 9)),
          ],
          if (f.phone.trim().isNotEmpty) pw.Text(f.phone.trim(), style: const pw.TextStyle(fontSize: 9)),
          ..._section('Skills', f.skills, theme.primary, fontSize: 9, gap: 14),
        ],
      ),
    );

    final main = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ..._section('Profile', f.summary, theme.primary, gap: 0),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
      ],
    );

    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: sidebarOnRight
              ? [
                  pw.Expanded(flex: 2, child: main),
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 1, child: sidebar),
                ]
              : [
                  pw.Expanded(flex: 1, child: sidebar),
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 2, child: main),
                ],
        ),
      ],
    );
  }

  static pw.Page _timelineLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 46),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                  if (f.targetRole.trim().isNotEmpty) pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 12, color: pdf.PdfColors.grey700)),
                  if (_contactLine(f).isNotEmpty) pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey600)),
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: theme.primary, thickness: 1.3),
        ..._section('Profile', f.summary, theme.primary),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
      ],
    );
  }

  static pw.Page _compactLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 56);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 34),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                  if (f.targetRole.trim().isNotEmpty) pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey700)),
                  if (_contactLine(f).isNotEmpty) pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 8.5, color: pdf.PdfColors.grey600)),
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: theme.primary, thickness: 1),
        ..._section('Profile', f.summary, theme.primary, fontSize: 8.5, gap: 8),
        ..._section('Experience', f.experience, theme.primary, fontSize: 8.5, gap: 8),
        ..._section('Education', f.education, theme.primary, fontSize: 8.5, gap: 8),
        ..._section('Skills', f.skills, theme.primary, fontSize: 8.5, gap: 8),
        ..._section('Projects / Achievements', f.projects, theme.primary, fontSize: 8.5, gap: 8),
      ],
    );
  }

  static pw.Page _executiveLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 48),
      build: (context) => [
        pw.Container(height: 5, width: double.infinity, color: theme.primary),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    f.fullName.trim().toUpperCase(),
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: 1.4),
                  ),
                  if (f.targetRole.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(f.targetRole.trim().toUpperCase(), style: pw.TextStyle(fontSize: 11, color: theme.primary, letterSpacing: 1.2)),
                  ],
                  if (_contactLine(f).isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey600)),
                  ],
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 16),
        ..._section('Profile', f.summary, theme.primary),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
      ],
    );
  }
}
