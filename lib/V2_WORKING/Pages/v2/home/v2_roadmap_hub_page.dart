import 'package:flutter/material.dart';

import '../../../Services/public_brand_config.dart';

class V2RoadmapHubPage extends StatelessWidget {
  const V2RoadmapHubPage({super.key});

  static const List<_RoadmapModule> _modules = [
    _RoadmapModule(
      id: 'V2.1',
      title: 'AI Assistant For Documents',
      summary: 'Ask questions on uploaded files, get summaries, and compare content.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFF1D4ED8),
      route: '/ai-assistant',
    ),
    _RoadmapModule(
      id: 'V2.2',
      title: 'AI Writing Studio',
      summary: 'Generate cover letters, SOPs, emails, and polished application drafts.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFF7C3AED),
      route: '/ai-writing',
    ),
    _RoadmapModule(
      id: 'V2.3',
      title: 'Smart Resume Builder',
      summary: 'Create ATS friendly resumes with role specific suggestions.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFF0F766E),
      route: '/resume',
    ),
    _RoadmapModule(
      id: 'V2.4',
      title: 'Job Application Toolkit',
      summary: 'Match CVs to job descriptions and generate interview question sets.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFFB45309),
      route: '/job-toolkit',
    ),
    _RoadmapModule(
      id: 'V2.5',
      title: 'Academic Toolkit',
      summary: 'Support SOP, LOR, research proposal, and scholarship workflows.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFF0E7490),
      route: '/academic-toolkit',
    ),
    _RoadmapModule(
      id: 'V2.6',
      title: 'Document Intelligence OCR+',
      summary: 'Extract structured data from scans, forms, and mixed-format documents.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFFDC2626),
      route: '/document-intelligence',
    ),
    _RoadmapModule(
      id: 'V2.7',
      title: 'Smart Document Workspace',
      summary: 'Organize, search, and manage documents with history and favorites.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFF1D4ED8),
      route: '/document-workspace',
    ),
    _RoadmapModule(
      id: 'V2.8',
      title: 'Team and Business Workspace',
      summary: 'Shared folders, role access, and team-level controls.',
      priority: 'Medium-High',
      status: 'Active',
      color: Color(0xFF0F766E),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.9',
      title: 'Global Language Intelligence',
      summary: 'Multilingual translation and language-aware document operations.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFF7C3AED),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.10',
      title: 'Automation and Smart Workflows',
      summary: 'Automate repetitive tasks and batch document pipelines.',
      priority: 'Medium-High',
      status: 'Active',
      color: Color(0xFFB45309),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.11',
      title: 'API and Integrations',
      summary: 'Connect with cloud, office, and external integration platforms.',
      priority: 'Medium',
      status: 'Active',
      color: Color(0xFF0E7490),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.12',
      title: 'Enterprise Security and Admin',
      summary: 'Admin policies, audit controls, and secure governance foundation.',
      priority: 'High',
      status: 'Active',
      color: Color(0xFF334155),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.13',
      title: 'Global Payments and Monetization',
      summary: 'International plans, pricing controls, and monetization setup.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFFDC2626),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.14',
      title: 'Performance, QA and Beta',
      summary: 'Reliability validation and beta readiness controls.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFF2563EB),
      route: '/v2-endgame',
    ),
    _RoadmapModule(
      id: 'V2.15',
      title: 'Global Launch Program',
      summary: 'Phased rollout execution and post-launch operational control.',
      priority: 'Critical',
      status: 'Active',
      color: Color(0xFF059669),
      route: '/v2-endgame',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 3
        : width >= 720
            ? 2
            : 1;
    final childAspectRatio = width >= 720 ? 1.5 : 1.25;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'V2 Roadmap Hub',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Execution snapshot for V2 (former V3)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Use this page to track what is next, what is active, and what must remain in planning before implementation starts.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _MetaPill(label: 'Owner mode', value: 'Quality over speed'),
                        _MetaPill(label: 'Current focus', value: 'V2 core modules'),
                        _MetaPill(label: 'Support', value: PublicBrandConfig.supportEmail),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      itemCount: _modules.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final module = _modules[index];
                        return _ModuleCard(module: module);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _RoadmapModule module;

  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E5F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  module.id,
                  style: TextStyle(
                    color: module.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              _StatusBadge(status: module.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            module.title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              module.summary,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Priority: ${module.priority}',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (module.route.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, module.route),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Module'),
              style: TextButton.styleFrom(
                foregroundColor: module.color,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    switch (status) {
      case 'Active':
        textColor = const Color(0xFF166534);
        bgColor = const Color(0xFFECFDF3);
        break;
      case 'Foundation ready':
        textColor = const Color(0xFF1D4ED8);
        bgColor = const Color(0xFFEFF6FF);
        break;
      case 'In discovery':
        textColor = const Color(0xFFB45309);
        bgColor = const Color(0xFFFFF7ED);
        break;
      case 'Planned':
      default:
        textColor = const Color(0xFF1D4ED8);
        bgColor = const Color(0xFFEFF6FF);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RoadmapModule {
  final String id;
  final String title;
  final String summary;
  final String priority;
  final String status;
  final Color color;
  final String route;

  const _RoadmapModule({
    required this.id,
    required this.title,
    required this.summary,
    required this.priority,
    required this.status,
    required this.color,
    this.route = '',
  });
}
