/// Single source of truth for every user-facing tool/sub-tool name shown as
/// an Admin "Tool Access" chip and (where wired) as a row in the Pricing
/// feature comparison table. Adding a tool here automatically creates a new
/// Admin chip (see `_PricingDialogState._allTools` in admin_dashboard_page.dart,
/// which reads `PlanCatalogConfig.registeredToolNames` = `AppToolsRegistry.allTools`).
class AppToolsRegistry {
  AppToolsRegistry._();

  static const String resumeBuilder = 'AI Resume Builder';
  static const String legacyResumeBuilder = 'Resume Builder';

  static const String govtVerifier =
      'Govt-Rule Auto-Verifier & Redactor (Exact KB, 4x6 Sheet, B&W Clean)';
  static const String legacyGovtResizer =
      'Govt Exam Photo & Signature Resizer (SSC, IBPS, Passport)';

  static const String qrLocationGenerator = 'Smart Location / Navigation QR Generator';
  static const String visionOcr = 'AI Scanned PDF OCR (Google Vision Engine)';

  static const List<String> allTools = <String>[
    'Compress',
    'Convert',
    'Merge',
    'Split',
    'Extract',
    'Edit PDF',
    'OCR',
    'History',
    'CSV to Excel',
    'AI Voice Command',
    govtVerifier,
    'PDF Compress (Single File) - set exact KB or MB target',
    'Batch Compress (Multiple Files) - process many files',
    'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
    'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
    'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
    'PDF OCR & Extract (Extract and search text from PDF pages)',
    'Edit PDF (Edit PDF, then save and download)',
    'HD Photo Studio',
    resumeBuilder,
    qrLocationGenerator,
    visionOcr,
  ];

  /// Tool names that were renamed - old persisted admin configs (or stray
  /// browser-cached selections) referencing these must still map to the
  /// current canonical name instead of being silently dropped.
  static const Map<String, String> legacyNameAliases = <String, String>{
    legacyResumeBuilder: resumeBuilder,
    legacyGovtResizer: govtVerifier,
  };

  static String canonicalName(String tool) {
    final trimmed = tool.trim();
    return legacyNameAliases[trimmed] ?? trimmed;
  }
}
