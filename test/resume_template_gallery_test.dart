import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/resume_template_gallery.dart';

void main() {
  group('ResumeTemplateGallery', () {
    test('catalog covers every layout x color combination', () {
      final catalog = ResumeTemplateGallery.buildCatalog();
      expect(catalog.length, ResumeLayoutStyle.values.length * ResumeTemplateGallery.colorThemes.length);
      expect(catalog.map((option) => option.id).toSet().length, catalog.length, reason: 'template ids must be unique');
    });

    test('builds a valid PDF for every layout with fully populated fields', () async {
      const fields = ResumeFields(
        fullName: 'Rajesh Khola',
        email: 'rajesh@example.com',
        phone: '+91 9999999999',
        targetRole: 'Software Engineer',
        summary: 'Product-focused engineer with a strong delivery record.',
        experience: 'Built and shipped multiple production features.\nLed a small cross-functional team.',
        education: 'B.Tech in Computer Science.',
        skills: 'Dart, Flutter, PDF generation, testing.',
        projects: 'Resume template gallery.\nA4 auto-fit PDF export.',
      );

      for (final layout in ResumeLayoutStyle.values) {
        final option = ResumeTemplateOption(
          id: 'test_${layout.name}',
          layoutLabel: ResumeTemplateGallery.layoutLabels[layout]!,
          layout: layout,
          theme: ResumeTemplateGallery.colorThemes.first,
        );
        final bytes = await ResumeTemplateGallery.buildResumePdf(fields: fields, template: option);
        expect(bytes.length, greaterThan(200), reason: '${layout.name} produced suspiciously small output');
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: '${layout.name} did not produce a valid PDF header');
      }
    });

    test('builds a valid PDF when every field is left empty', () async {
      const emptyFields = ResumeFields();
      final option = ResumeTemplateOption(
        id: 'test_empty',
        layoutLabel: ResumeTemplateGallery.layoutLabels[ResumeLayoutStyle.classic]!,
        layout: ResumeLayoutStyle.classic,
        theme: ResumeTemplateGallery.colorThemes.first,
      );

      final bytes = await ResumeTemplateGallery.buildResumePdf(fields: emptyFields, template: option);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds a valid, longer PDF (multi-page auto-fit) with very long content', () async {
      final longExperience = List.generate(60, (i) => 'Line $i: delivered measurable impact through strategic execution.').join('\n');
      final fields = ResumeFields(
        fullName: 'Rajesh Khola',
        summary: 'Results-driven professional.',
        experience: longExperience,
      );
      final option = ResumeTemplateOption(
        id: 'test_long',
        layoutLabel: ResumeTemplateGallery.layoutLabels[ResumeLayoutStyle.classic]!,
        layout: ResumeLayoutStyle.classic,
        theme: ResumeTemplateGallery.colorThemes.first,
      );

      final bytes = await ResumeTemplateGallery.buildResumePdf(fields: fields, template: option);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // A multi-page document should be meaningfully larger than a near-empty one.
      expect(bytes.length, greaterThan(1500));
    });
  });
}
