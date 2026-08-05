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
  modernTwoColumn,
  creativeSidebar,
  techMinimalist,
  compactAts,
  academic,
  boldProfessional,
  cleanDivider,
  modernBand,
  elegantMono,
  strategicLeader,
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
    ResumeLayoutStyle.modernTwoColumn: 'Modern Two-Column',
    ResumeLayoutStyle.creativeSidebar: 'Creative Sidebar',
    ResumeLayoutStyle.techMinimalist: 'Tech Minimalist',
    ResumeLayoutStyle.compactAts: 'Compact ATS',
    ResumeLayoutStyle.academic: 'Academic Research',
    ResumeLayoutStyle.boldProfessional: 'Bold Professional',
    ResumeLayoutStyle.cleanDivider: 'Clean Divider',
    ResumeLayoutStyle.modernBand: 'Modern Band Header',
    ResumeLayoutStyle.elegantMono: 'Elegant Mono',
    ResumeLayoutStyle.strategicLeader: 'Strategic Leader',
  };

  static List<ResumeTemplateOption> buildCatalog() {
    ResumeColorTheme theme(String name) {
      return colorThemes.firstWhere(
        (value) => value.name == name,
        orElse: () => colorThemes.first,
      );
    }

    ResumeTemplateOption option({
      required String id,
      required ResumeLayoutStyle layout,
      required String themeName,
    }) {
      return ResumeTemplateOption(
        id: id,
        layoutLabel: layoutLabels[layout]!,
        layout: layout,
        theme: theme(themeName),
      );
    }

    return [
      option(id: 'classic_navy', layout: ResumeLayoutStyle.classic, themeName: 'Navy Blue'),
      option(id: 'modern_header_ocean', layout: ResumeLayoutStyle.modern, themeName: 'Ocean Blue'),
      option(id: 'minimal_graphite', layout: ResumeLayoutStyle.minimal, themeName: 'Graphite Black'),
      option(id: 'two_column_emerald', layout: ResumeLayoutStyle.twoColumn, themeName: 'Emerald Green'),
      option(id: 'sidebar_indigo', layout: ResumeLayoutStyle.sidebar, themeName: 'Indigo'),
      option(id: 'timeline_royal', layout: ResumeLayoutStyle.timeline, themeName: 'Royal Purple'),
      option(id: 'compact_charcoal', layout: ResumeLayoutStyle.compact, themeName: 'Charcoal Gray'),
      option(id: 'executive_crimson', layout: ResumeLayoutStyle.executive, themeName: 'Crimson Red'),
      option(id: 'modern_two_column_teal', layout: ResumeLayoutStyle.modernTwoColumn, themeName: 'Slate Teal'),
      option(id: 'creative_sidebar_rose', layout: ResumeLayoutStyle.creativeSidebar, themeName: 'Rose Pink'),
      option(id: 'tech_minimal_navy', layout: ResumeLayoutStyle.techMinimalist, themeName: 'Navy Blue'),
      option(id: 'compact_ats_graphite', layout: ResumeLayoutStyle.compactAts, themeName: 'Graphite Black'),
      option(id: 'academic_forest', layout: ResumeLayoutStyle.academic, themeName: 'Forest Green'),
      option(id: 'bold_professional_amber', layout: ResumeLayoutStyle.boldProfessional, themeName: 'Amber Gold'),
      option(id: 'clean_divider_ocean', layout: ResumeLayoutStyle.cleanDivider, themeName: 'Ocean Blue'),
      option(id: 'modern_band_sunset', layout: ResumeLayoutStyle.modernBand, themeName: 'Sunset Orange'),
      option(id: 'elegant_mono_black', layout: ResumeLayoutStyle.elegantMono, themeName: 'Graphite Black'),
      option(id: 'strategic_leader_royal', layout: ResumeLayoutStyle.strategicLeader, themeName: 'Royal Purple'),
    ];
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
      case ResumeLayoutStyle.modernTwoColumn:
        doc.addPage(_modernTwoColumnLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.creativeSidebar:
        doc.addPage(_creativeSidebarLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.techMinimalist:
        doc.addPage(_techMinimalistLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.compactAts:
        doc.addPage(_compactAtsLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.academic:
        doc.addPage(_academicLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.boldProfessional:
        doc.addPage(_boldProfessionalLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.cleanDivider:
        doc.addPage(_cleanDividerLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.modernBand:
        doc.addPage(_modernBandLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.elegantMono:
        doc.addPage(_elegantMonoLayout(fields, template.theme, photo));
        break;
      case ResumeLayoutStyle.strategicLeader:
        doc.addPage(_strategicLeaderLayout(fields, template.theme, photo));
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

  static pw.Page _modernTwoColumnLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 74);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: pw.BoxDecoration(
            color: theme.primary,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.white)),
                    if (f.targetRole.trim().isNotEmpty)
                      pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.white)),
                    if (_contactLine(f).isNotEmpty)
                      pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.white)),
                  ],
                ),
              ),
              if (photoWidget != null) photoWidget,
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  ..._bulletSection('Experience', f.experience, theme.primary),
                  ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  ..._section('Profile', f.summary, theme.primary, gap: 0),
                  ..._section('Education', f.education, theme.primary),
                  ..._section('Skills', f.skills, theme.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Page _creativeSidebarLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 80);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                  if (f.targetRole.trim().isNotEmpty)
                    pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  ..._section('Profile', f.summary, theme.primary, gap: 0),
                  ..._bulletSection('Experience', f.experience, theme.primary),
                  ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(color: theme.tint, borderRadius: pw.BorderRadius.circular(12)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (photoWidget != null) ...[
                      pw.Center(child: photoWidget),
                      pw.SizedBox(height: 10),
                    ],
                    if (_contactLine(f).isNotEmpty) pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.5)),
                    ..._section('Education', f.education, theme.primary),
                    ..._section('Skills', f.skills, theme.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Page _techMinimalistLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 58);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 36),
      build: (context) => [
        pw.Container(height: 3, width: double.infinity, color: theme.primary),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        if (f.targetRole.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(f.targetRole.trim(), style: pw.TextStyle(fontSize: 10, color: theme.primary)),
          ),
        if (_contactLine(f).isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.2, color: pdf.PdfColors.grey700)),
          ),
        ..._section('Summary', f.summary, theme.primary, fontSize: 9.4),
        ..._section('Experience', f.experience, theme.primary, fontSize: 9.4),
        ..._section('Projects', f.projects, theme.primary, fontSize: 9.4),
        ..._section('Skills', f.skills, theme.primary, fontSize: 9.4),
        ..._section('Education', f.education, theme.primary, fontSize: 9.4),
      ],
    );
  }

  static pw.Page _compactAtsLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
      build: (context) => [
        pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: theme.primary)),
        if (f.targetRole.trim().isNotEmpty)
          pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey700)),
        if (_contactLine(f).isNotEmpty)
          pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 8.5, color: pdf.PdfColors.grey600)),
        pw.SizedBox(height: 8),
        pw.Divider(color: pdf.PdfColors.grey400, thickness: 0.8),
        ..._section('Profile', f.summary, theme.primary, fontSize: 8.5, gap: 6),
        ..._section('Skills', f.skills, theme.primary, fontSize: 8.5, gap: 6),
        ..._section('Experience', f.experience, theme.primary, fontSize: 8.5, gap: 6),
        ..._section('Education', f.education, theme.primary, fontSize: 8.5, gap: 6),
        ..._section('Projects / Achievements', f.projects, theme.primary, fontSize: 8.5, gap: 6),
      ],
    );
  }

  static pw.Page _academicLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 44),
      build: (context) => [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold, color: theme.primary)),
              if (f.targetRole.trim().isNotEmpty)
                pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.grey700)),
              if (_contactLine(f).isNotEmpty)
                pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey600)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: theme.primary, thickness: 1.1),
        ..._section('Research Summary', f.summary, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Experience', f.experience, theme.primary),
        ..._section('Projects / Publications', f.projects, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
      ],
    );
  }

  static pw.Page _boldProfessionalLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 70);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          color: theme.primary,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(f.fullName.trim().toUpperCase(), style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.white)),
                    if (f.targetRole.trim().isNotEmpty)
                      pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.white)),
                    if (_contactLine(f).isNotEmpty)
                      pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.white)),
                  ],
                ),
              ),
              if (photoWidget != null) photoWidget,
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._bulletSection('Projects / Achievements', f.projects, theme.primary),
        ..._section('Profile', f.summary, theme.primary),
      ],
    );
  }

  static pw.Page _cleanDividerLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 42),
      build: (context) => [
        pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        if (f.targetRole.trim().isNotEmpty)
          pw.Text(f.targetRole.trim(), style: pw.TextStyle(fontSize: 10.5, color: theme.primary)),
        if (_contactLine(f).isNotEmpty)
          pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey700)),
        pw.SizedBox(height: 10),
        pw.Container(height: 1.2, width: double.infinity, color: theme.primary),
        ..._section('Profile', f.summary, theme.primary),
        pw.Divider(color: pdf.PdfColors.grey300),
        ..._section('Experience', f.experience, theme.primary),
        pw.Divider(color: pdf.PdfColors.grey300),
        ..._section('Education', f.education, theme.primary),
        pw.Divider(color: pdf.PdfColors.grey300),
        ..._section('Skills', f.skills, theme.primary),
        ..._section('Projects / Achievements', f.projects, theme.primary),
      ],
    );
  }

  static pw.Page _modernBandLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 66);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            color: theme.tint,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: theme.primary, width: 1.1),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                    if (f.targetRole.trim().isNotEmpty)
                      pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 10.5)),
                  ],
                ),
              ),
              if (photoWidget != null) photoWidget,
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        if (_contactLine(f).isNotEmpty)
          pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.5, color: pdf.PdfColors.grey700)),
        ..._bulletSection('Experience', f.experience, theme.primary),
        ..._section('Projects / Achievements', f.projects, theme.primary),
        ..._section('Skills', f.skills, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Profile', f.summary, theme.primary),
      ],
    );
  }

  static pw.Page _elegantMonoLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 58, vertical: 52),
      build: (context) => [
        pw.Text(f.fullName.trim().toUpperCase(), style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.3)),
        if (f.targetRole.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(f.targetRole.trim(), style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey700)),
          ),
        if (_contactLine(f).isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey600)),
          ),
        pw.SizedBox(height: 12),
        pw.Divider(color: pdf.PdfColors.grey700, thickness: 0.8),
        ..._section('Profile', f.summary, pdf.PdfColors.black),
        ..._section('Experience', f.experience, pdf.PdfColors.black),
        ..._section('Education', f.education, pdf.PdfColors.black),
        ..._section('Skills', f.skills, pdf.PdfColors.black),
        ..._section('Projects / Achievements', f.projects, pdf.PdfColors.black),
      ],
    );
  }

  static pw.Page _strategicLeaderLayout(ResumeFields f, ResumeColorTheme theme, pw.MemoryImage? photo) {
    final photoWidget = _photoWidget(photo, size: 72);
    return pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(f.fullName.trim(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: theme.primary)),
                  if (f.targetRole.trim().isNotEmpty)
                    pw.Text(f.targetRole.trim().toUpperCase(), style: pw.TextStyle(fontSize: 10.5, color: theme.primary, letterSpacing: 1.1)),
                  if (_contactLine(f).isNotEmpty)
                    pw.Text(_contactLine(f), style: const pw.TextStyle(fontSize: 9.2, color: pdf.PdfColors.grey700)),
                ],
              ),
            ),
            if (photoWidget != null) photoWidget,
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 4, width: 120, color: theme.primary),
        ..._section('Leadership Summary', f.summary, theme.primary),
        ..._bulletSection('Key Experience', f.experience, theme.primary),
        ..._section('Strategic Projects', f.projects, theme.primary),
        ..._section('Education', f.education, theme.primary),
        ..._section('Core Skills', f.skills, theme.primary),
      ],
    );
  }
}
