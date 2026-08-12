import 'dart:convert';

import '../Utils/web_safe_browser.dart';

class UnifiedPlan {
  const UnifiedPlan({
    required this.planId,
    required this.planName,
    required this.priceInr,
    required this.priceUsd,
    required this.voiceMinutesRemaining,
    required this.toolsUnlimited,
    required this.validityDays,
    required this.description,
  });

  final String planId;
  final String planName;
  final double priceInr;
  final double priceUsd;
  final int voiceMinutesRemaining;
  final bool toolsUnlimited;
  final int validityDays;
  final String description;
}

class ToolUsageGuideStep {
  const ToolUsageGuideStep({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class ToolUsageGuide {
  const ToolUsageGuide({
    required this.toolKey,
    required this.title,
    required this.subtitle,
    required this.launchUrl,
    required this.steps,
  });

  final String toolKey;
  final String title;
  final String subtitle;
  final String launchUrl;
  final List<ToolUsageGuideStep> steps;
}

class PlanCatalogConfig {
  static const String resumeBuilderToolName = 'AI Resume Builder';
  static const String legacyResumeBuilderToolName = 'Resume Builder';
  static const int freeTierMaxFileSizeMb = 25;
  static const int paidTierMaxFileSizeMb = 250;
  static const int freeTierDailyConversionLimit = 5;
  static const int unlimitedConversions = -1;

  static const Set<String> _paidPlans = <String>{
    'free',
    'starter_99',
    'pro_299',
    '7Days',
    'Monthly',
    'Yearly',
    'Lifetime',
  };

  // Master tool ID to feature-name mapping used by plan config sanitization.
  static const Map<String, String> registeredToolIdToName = <String, String>{
    'compress': 'Compress',
    'convert': 'Convert',
    'merge': 'Merge',
    'split': 'Split',
    'extract': 'Extract',
    'edit_pdf': 'Edit PDF',
    'ocr': 'OCR',
    'history': 'History',
    'pdf_compress_single': 'PDF Compress (Single File) - set exact KB or MB target',
    'pdf_compress_batch': 'Batch Compress (Multiple Files) - process many files',
    'micro_canva': 'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
    'resume_canvas': 'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
    'poster_studio': 'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
    'pdf_ocr': 'PDF OCR & Extract (Extract and search text from PDF pages)',
    'pdf_edit': 'Edit PDF (Edit PDF, then save and download)',
    'hd_photo': 'HD Photo Studio',
    'ai_resume': resumeBuilderToolName,
  };

  static const List<String> registeredToolNames = <String>[
    'Compress',
    'Convert',
    'Merge',
    'Split',
    'Extract',
    'Edit PDF',
    'OCR',
    'History',
    'PDF Compress (Single File) - set exact KB or MB target',
    'Batch Compress (Multiple Files) - process many files',
    'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
    'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
    'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
    'PDF OCR & Extract (Extract and search text from PDF pages)',
    'Edit PDF (Edit PDF, then save and download)',
    'HD Photo Studio',
    resumeBuilderToolName,
  ];

  static bool isPaidPlan(String plan) => _paidPlans.contains(plan);

  static int maxFileSizeMbForPlan(String plan) {
    return isPaidPlan(plan) ? paidTierMaxFileSizeMb : freeTierMaxFileSizeMb;
  }

  static int dailyConversionLimitForPlan(String plan) {
    return isPaidPlan(plan) ? unlimitedConversions : freeTierDailyConversionLimit;
  }

  final Map<String, double> inrPrices;
  final Map<String, double> usdPrices;
  final Map<String, List<String>> enabledToolsByPlan;
  final Map<String, String> userQuotasByPlan;

  const PlanCatalogConfig({
    required this.inrPrices,
    required this.usdPrices,
    required this.enabledToolsByPlan,
    this.userQuotasByPlan = const <String, String>{},
  });

  factory PlanCatalogConfig.defaults() {
    return const PlanCatalogConfig(
      inrPrices: {
        'free': 0,
        'starter_99': 99,
        'pro_299': 299,
        'Free': 0,
        '7Days': 99,
        'Monthly': 149,
        'Yearly': 999,
        'Lifetime': 9999,
      },
      usdPrices: {
        'free': 0,
        'starter_99': 99,
        'pro_299': 299,
        'Free': 0,
        '7Days': 2.99,
        'Monthly': 4.99,
        'Yearly': 29.99,
        'Lifetime': 120,
      },
      enabledToolsByPlan: {
        'free': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'PDF Compress (Single File) - set exact KB or MB target',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'starter_99': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'pro_299': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'History',
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'Free': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'PDF Compress (Single File) - set exact KB or MB target',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        '7Days': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'PDF Compress (Single File) - set exact KB or MB target',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'Monthly': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'Yearly': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'History',
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
        'Lifetime': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'History',
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
        ],
      },
      userQuotasByPlan: {
        'free': '5 minutes',
        'starter_99': '60 minutes / month',
        'pro_299': '500 minutes / month',
        'Free': '5/day',
        '7Days': 'Unlimited',
        'Monthly': 'Unlimited',
        'Yearly': 'Unlimited',
        'Lifetime': 'Unlimited',
      },
    );
  }

  static Set<String> get _v11AllowedTools => registeredToolNames.toSet();

  static String _canonicalToolName(String tool) {
    final trimmed = tool.trim();
    final mapped = registeredToolIdToName[trimmed] ?? trimmed;
    if (mapped == legacyResumeBuilderToolName) {
      return resumeBuilderToolName;
    }
    return mapped;
  }

  static List<String> _sanitizeTools(List<String> tools) {
    final sanitized = <String>{};
    for (final tool in tools) {
      final canonical = _canonicalToolName(tool);
      if (_v11AllowedTools.contains(canonical)) {
        sanitized.add(canonical);
      }
    }
    return sanitized.toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'inr_prices': inrPrices,
      'usd_prices': usdPrices,
      'enabled_tools_by_plan': enabledToolsByPlan,
      'user_quotas_by_plan': userQuotasByPlan,
    };
  }

  factory PlanCatalogConfig.fromMap(Map<String, dynamic> map) {
    final defaults = PlanCatalogConfig.defaults();

    Map<String, double> readPriceMap(dynamic raw, Map<String, double> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, double>{...fallback};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = double.tryParse(entry.value.toString());
        if (value != null) {
          merged[key] = value;
        }
      }
      return merged;
    }

    Map<String, List<String>> readToolsMap(dynamic raw, Map<String, List<String>> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, List<String>>{};
      for (final fallbackEntry in fallback.entries) {
        merged[fallbackEntry.key] = _sanitizeTools(List<String>.from(fallbackEntry.value));
      }

      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          final fallbackTools = merged[key] ?? const <String>[];
          final rawTools = value.map((item) => item.toString()).toList();
          merged[key] = _sanitizeTools(<String>[...fallbackTools, ...rawTools]);
        }
      }
      return merged;
    }

    Map<String, String> readQuotaMap(dynamic raw, Map<String, String> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, String>{...fallback};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value?.toString() ?? '';
        if (value.trim().isNotEmpty) {
          merged[key] = value;
        }
      }
      return merged;
    }

    return PlanCatalogConfig(
      inrPrices: readPriceMap(map['inr_prices'], defaults.inrPrices),
      usdPrices: readPriceMap(map['usd_prices'], defaults.usdPrices),
      enabledToolsByPlan: readToolsMap(map['enabled_tools_by_plan'], defaults.enabledToolsByPlan),
      userQuotasByPlan: readQuotaMap(map['user_quotas_by_plan'], defaults.userQuotasByPlan),
    );
  }
}

class PlanCatalogService {
  static const String _storageKey = 'jobready_plan_catalog_config_v1_1';

  static String formatPlanPriceLine(String plan, {required String currencyCode, String suffix = ''}) {
    final config = load();
    final normalized = PlanService.normalizePlanId(plan);
    final inrAmount = config.inrPrices[normalized] ?? config.inrPrices[plan] ?? 0.0;
    final usdAmount = config.usdPrices[normalized] ?? config.usdPrices[plan] ?? 0.0;

    if (normalized == 'free' || plan == 'Free') {
      return currencyCode == 'INR' ? '₹0$suffix' : '\$0$suffix';
    }

    if (currencyCode == 'INR') {
      return '₹${inrAmount.toStringAsFixed(inrAmount.truncateToDouble() == inrAmount ? 0 : 2)}$suffix';
    }

    return '\$${usdAmount.toStringAsFixed(usdAmount.truncateToDouble() == usdAmount ? 0 : 2)}$suffix';
  }

  static PlanCatalogConfig load() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return PlanCatalogConfig.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return PlanCatalogConfig.defaults();
      }
      return PlanCatalogConfig.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return PlanCatalogConfig.defaults();
    }
  }

  static Future<void> save(PlanCatalogConfig config) async {
    WebSafeBrowser.writeLocalStorage(_storageKey, jsonEncode(config.toMap()));
  }

  static Future<void> reset() async {
    WebSafeBrowser.removeLocalStorage(_storageKey);
  }
}

class PlanService {
  static const String freePlanId = 'free';
  static const String starterPlanId = 'starter_99';
  static const String proPlanId = 'pro_299';

  static const Map<String, UnifiedPlan> planRegistry = {
    freePlanId: UnifiedPlan(
      planId: freePlanId,
      planName: 'Free / Trial',
      priceInr: 0,
      priceUsd: 0,
      voiceMinutesRemaining: 5,
      toolsUnlimited: false,
      validityDays: 36500,
      description: 'One-time voice trial and 1 free resume download.',
    ),
    starterPlanId: UnifiedPlan(
      planId: starterPlanId,
      planName: 'Starter Plan',
      priceInr: 99,
      priceUsd: 99,
      voiceMinutesRemaining: 60,
      toolsUnlimited: true,
      validityDays: 30,
      description: '60 voice minutes per month and unlimited resume tools.',
    ),
    proPlanId: UnifiedPlan(
      planId: proPlanId,
      planName: 'Pro Unlimited',
      priceInr: 299,
      priceUsd: 299,
      voiceMinutesRemaining: 500,
      toolsUnlimited: true,
      validityDays: 30,
      description: 'Unlimited or fair-usage voice minutes and unlimited career tools.',
    ),
  };

  static String normalizePlanId(String? rawPlan) {
    final value = (rawPlan ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return freePlanId;
    }

    final aliasMap = {
      'free': freePlanId,
      'trial': freePlanId,
      'starter': starterPlanId,
      'starter_99': starterPlanId,
      'monthly': starterPlanId,
      'pro': proPlanId,
      'pro_299': proPlanId,
      'unlimited': proPlanId,
      'lifetime': proPlanId,
      'yearly': proPlanId,
      '7days': starterPlanId,
      '7_days': starterPlanId,
      '7days': starterPlanId,
    };

    return aliasMap[value] ?? value;
  }

  static UnifiedPlan resolvePlan(String? rawPlan) {
    return planRegistry[normalizePlanId(rawPlan)] ?? planRegistry[freePlanId]!;
  }

  static bool isAdminBypass({String? role, bool isAdmin = false}) {
    return isAdmin || (role ?? '').toLowerCase() == 'admin';
  }

  static bool hasUnlockedAccess({String? role, bool isAdmin = false, String? planId}) {
    if (isAdminBypass(role: role, isAdmin: isAdmin)) {
      return true;
    }
    final normalizedPlanId = normalizePlanId(planId);
    if (normalizedPlanId == freePlanId) {
      return false;
    }
    final plan = resolvePlan(planId);
    return plan.toolsUnlimited || plan.voiceMinutesRemaining > 0;
  }

  static bool hasActiveToolAccess({String? role, bool isAdmin = false, String? planId}) {
    return hasUnlockedAccess(role: role, isAdmin: isAdmin, planId: planId);
  }

  static List<ToolUsageGuide> getToolUsageGuides() {
    return const <ToolUsageGuide>[
      ToolUsageGuide(
        toolKey: 'voice_translator',
        title: 'AI Voice Translator',
        subtitle: 'Speak naturally, translate instantly, and save the conversation output in one flow.',
        launchUrl: 'https://voice.getreadyjob.com',
        steps: <ToolUsageGuideStep>[
          ToolUsageGuideStep(title: 'Step 1', description: 'Open the Voice app and choose the translator module.'),
          ToolUsageGuideStep(title: 'Step 2', description: 'Speak or upload your audio and pick the language pair.'),
          ToolUsageGuideStep(title: 'Step 3', description: 'Review the transcript, copy the translation, and share the result.'),
        ],
      ),
      ToolUsageGuide(
        toolKey: 'mock_interview',
        title: 'AI Mock Interview',
        subtitle: 'Practice realistic interview questions with instant feedback and stronger readiness.',
        launchUrl: 'https://voice.getreadyjob.com',
        steps: <ToolUsageGuideStep>[
          ToolUsageGuideStep(title: 'Step 1', description: 'Select the interview role or job type you want to practice.'),
          ToolUsageGuideStep(title: 'Step 2', description: 'Start the mock session and answer each question out loud.'),
          ToolUsageGuideStep(title: 'Step 3', description: 'Review the score summary and improve the weak areas before the real interview.'),
        ],
      ),
      ToolUsageGuide(
        toolKey: 'study_assistant',
        title: 'Study Assistant',
        subtitle: 'Turn notes, prompts, and revision goals into a guided study flow.',
        launchUrl: 'https://voice.getreadyjob.com',
        steps: <ToolUsageGuideStep>[
          ToolUsageGuideStep(title: 'Step 1', description: 'Choose a subject, topic, or exam goal from the dashboard.'),
          ToolUsageGuideStep(title: 'Step 2', description: 'Ask the assistant to breakdown concepts or quiz you on the topic.'),
          ToolUsageGuideStep(title: 'Step 3', description: 'Use the recap and follow-up prompt to keep learning with focus.'),
        ],
      ),
      ToolUsageGuide(
        toolKey: 'resume_builder',
        title: 'AI Resume Builder',
        subtitle: 'Build and refine ATS-friendly resumes faster with guided job-ready sections.',
        launchUrl: 'https://voice.getreadyjob.com',
        steps: <ToolUsageGuideStep>[
          ToolUsageGuideStep(title: 'Step 1', description: 'Pick a resume template and enter your profile details.'),
          ToolUsageGuideStep(title: 'Step 2', description: 'Use AI suggestions to tighten your summary, skills, and experience.'),
          ToolUsageGuideStep(title: 'Step 3', description: 'Preview, export, and reuse the polished resume for applications.'),
        ],
      ),
    ];
  }
}
