import 'package:flutter/material.dart';

class V2GrowthModulesPage extends StatelessWidget {
  const V2GrowthModulesPage({super.key});

  static const List<_GrowthModule> _modules = [
    _GrowthModule(
      id: 'V2.7',
      title: 'Smart Document Workspace',
      summary: 'Organize recent files, favorites, and AI history in one place.',
      status: 'Active',
      priority: 'High',
      color: Color(0xFF1D4ED8),
      nextStep: 'Continue with file tagging and pinned folders.',
    ),
    _GrowthModule(
      id: 'V2.8',
      title: 'Team and Business Workspace',
      summary: 'Prepare shared folders, role access, and collaboration controls.',
      status: 'Active (Execution)',
      priority: 'Medium-High',
      color: Color(0xFF0F766E),
      nextStep: 'Add team roles and shared workspace access model.',
    ),
    _GrowthModule(
      id: 'V2.9',
      title: 'Global Language Intelligence',
      summary: 'Support multilingual drafting and translation-aware flows.',
      status: 'Active (Execution)',
      priority: 'High',
      color: Color(0xFF7C3AED),
      nextStep: 'Add language selector and translation pipeline.',
    ),
    _GrowthModule(
      id: 'V2.10',
      title: 'Automation and Smart Workflows',
      summary: 'Batch actions for repetitive document operations.',
      status: 'Active (Execution)',
      priority: 'Medium-High',
      color: Color(0xFFB45309),
      nextStep: 'Build queue runner and batch templates.',
    ),
    _GrowthModule(
      id: 'V2.11',
      title: 'API and Integrations',
      summary: 'Connect external tools and cloud platforms into V2.',
      status: 'Active (Execution)',
      priority: 'Medium',
      color: Color(0xFF0E7490),
      nextStep: 'Define connector contracts and auth workflows.',
    ),
    _GrowthModule(
      id: 'V2.12',
      title: 'Enterprise Security and Admin',
      summary: 'Admin controls, audit logs, and policy enforcement foundation.',
      status: 'Active (Execution)',
      priority: 'High',
      color: Color(0xFF334155),
      nextStep: 'Ship admin roles, activity logs, and policy settings.',
    ),
    _GrowthModule(
      id: 'V2.13',
      title: 'Global Payments and Monetization',
      summary: 'Scale plans and billing controls for international users.',
      status: 'Active (Execution)',
      priority: 'Critical',
      color: Color(0xFFDC2626),
      nextStep: 'Add plan entitlements and region-aware pricing.',
    ),
    _GrowthModule(
      id: 'V2.14',
      title: 'Performance, QA and Beta',
      summary: 'Stress validation and reliability gates before launch.',
      status: 'Active (Execution)',
      priority: 'Critical',
      color: Color(0xFF2563EB),
      nextStep: 'Create benchmark runs and beta readiness checklist.',
    ),
    _GrowthModule(
      id: 'V2.15',
      title: 'Global Launch Program',
      summary: 'Release execution for international rollout and operations.',
      status: 'Active (Execution)',
      priority: 'Critical',
      color: Color(0xFF059669),
      nextStep: 'Finalize launch gate, support runbook, and phased rollout.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1200
        ? 3
        : width >= 740
            ? 2
            : 1;
    final childAspectRatio = width >= 740 ? 1.35 : 1.15;

    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Growth Hub (7-15)'),
        backgroundColor: const Color(0xFF0E3A66),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roadmap continuation to V2.15',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Core modules V2.1 to V2.6 are active. This hub captures expansion modules V2.7 to V2.15 with immediate next implementation steps so execution can continue without waiting.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      itemCount: _modules.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final module = _modules[index];
                        return _GrowthModuleCard(module: module);
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8E5F5)),
                      ),
                      child: const Text(
                        'Execution note: This page is the continuity bridge from active core modules to final launch program. Build order recommendation: V2.7 -> V2.10 -> V2.12 -> V2.14 -> V2.15.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _GrowthModuleCard extends StatelessWidget {
  final _GrowthModule module;

  const _GrowthModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                  color: module.color.withValues(alpha: 0.12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: module.status == 'Active'
                      ? const Color(0xFFDCFCE7)
                      : module.status.startsWith('Active')
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  module.status,
                  style: TextStyle(
                    color: module.status == 'Active'
                        ? const Color(0xFF166534)
                        : const Color(0xFF1D4ED8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            module.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            module.summary,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Priority: ${module.priority}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Next: ${module.nextStep}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          if (module.id == 'V2.7')
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/document-workspace'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Workspace Module'),
              style: TextButton.styleFrom(
                foregroundColor: module.color,
                padding: EdgeInsets.zero,
              ),
            ),
          if (module.id != 'V2.7')
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/v2-endgame'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Endgame Console'),
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

class _GrowthModule {
  final String id;
  final String title;
  final String summary;
  final String status;
  final String priority;
  final Color color;
  final String nextStep;

  const _GrowthModule({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.priority,
    required this.color,
    required this.nextStep,
  });
}
