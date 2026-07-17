import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import '../Widgets/apple_button.dart';

class HomePageV3 extends StatelessWidget {
  const HomePageV3({super.key});

  void _openRoute(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 3
        : width >= 700
            ? 2
            : 1;
    final childAspectRatio = width >= 700 ? 1.8 : 2.6;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'JOBREADY V2',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Separate build',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0051BA), Color(0xFF0A84FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0051BA).withValues(alpha: 0.24),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _StatusChip(
                                label: 'V2 execution mode',
                                icon: Icons.layers_outlined,
                              ),
                              _StatusChip(
                                label: 'Former V3 lane',
                                icon: Icons.rocket_launch_outlined,
                              ),
                              _StatusChip(
                                label: 'Roadmap modules active',
                                icon: Icons.link,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'JOBREADY V2 (former V3) starts here.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This build stays separate from V1 (merged V1+V2) so we can develop the next roadmap modules without disturbing the stable launch flow.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              AppleButton(
                                label: 'Open Compress',
                                icon: Icons.compress,
                                onPressed: () => _openRoute(context, '/compress'),
                              ),
                              AppleButton(
                                label: 'Open PDF Tools',
                                icon: Icons.picture_as_pdf,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/pdf-tools'),
                              ),
                              AppleButton(
                                label: 'Open AI Assistant',
                                icon: Icons.auto_awesome,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/ai-assistant'),
                              ),
                              AppleButton(
                                label: 'Open AI Writing',
                                icon: Icons.edit_note,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/ai-writing'),
                              ),
                              AppleButton(
                                label: 'Open Job Toolkit',
                                icon: Icons.work_outline,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/job-toolkit'),
                              ),
                              AppleButton(
                                label: 'Open Academic Toolkit',
                                icon: Icons.school_outlined,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/academic-toolkit'),
                              ),
                              AppleButton(
                                label: 'Open OCR+',
                                icon: Icons.text_snippet_outlined,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/document-intelligence'),
                              ),
                              AppleButton(
                                label: 'Open Document Workspace',
                                icon: Icons.folder_open_outlined,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/document-workspace'),
                              ),
                              AppleButton(
                                label: 'Open Growth Hub',
                                icon: Icons.track_changes_outlined,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/v2-growth'),
                              ),
                              AppleButton(
                                label: 'Open Endgame 8-15',
                                icon: Icons.rocket_launch_outlined,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/v2-endgame'),
                              ),
                              AppleButton(
                                label: 'Open V2 Roadmap',
                                icon: Icons.route,
                                isPrimary: false,
                                onPressed: () => _openRoute(context, '/v2-roadmap'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TopNavAction(
                            label: 'HOME',
                            onTap: () => _openRoute(context, '/home'),
                          ),
                          _TopNavAction(
                            label: 'AI',
                            onTap: () => _openRoute(context, '/ai-assistant'),
                          ),
                          _TopNavAction(
                            label: 'WRITING',
                            onTap: () => _openRoute(context, '/ai-writing'),
                          ),
                          _TopNavAction(
                            label: 'JOBS',
                            onTap: () => _openRoute(context, '/job-toolkit'),
                          ),
                          _TopNavAction(
                            label: 'ACADEMIC',
                            onTap: () => _openRoute(context, '/academic-toolkit'),
                          ),
                          _TopNavAction(
                            label: 'OCR+',
                            onTap: () => _openRoute(context, '/document-intelligence'),
                          ),
                          _TopNavAction(
                            label: 'WORKSPACE',
                            onTap: () => _openRoute(context, '/document-workspace'),
                          ),
                          _TopNavAction(
                            label: 'GROWTH',
                            onTap: () => _openRoute(context, '/v2-growth'),
                          ),
                          _TopNavAction(
                            label: 'ENDGAME',
                            onTap: () => _openRoute(context, '/v2-endgame'),
                          ),
                          _TopNavAction(
                            label: 'RESUME',
                            onTap: () => _openRoute(context, '/resume'),
                          ),
                          _TopNavAction(
                            label: 'CONVERTER',
                            onTap: () => _openRoute(context, '/converter-v2'),
                          ),
                          _TopNavAction(
                            label: 'PHOTO HD',
                            onTap: () => _openRoute(context, '/photo-hd'),
                          ),
                          _TopNavAction(
                            label: 'ROADMAP',
                            onTap: () => _openRoute(context, '/v2-roadmap'),
                          ),
                          _TopNavAction(
                            label: 'MERGE',
                            onTap: () => _openRoute(context, '/merge'),
                          ),
                          _TopNavAction(
                            label: 'SPLIT',
                            onTap: () => _openRoute(context, '/split'),
                          ),
                          _TopNavAction(
                            label: 'PDF TOOLS',
                            onTap: () => _openRoute(context, '/pdf-tools'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _StatusPill(
                          label: 'V2 shell ready',
                          value: 'Yes',
                          color: Color(0xFF0F766E),
                        ),
                        _StatusPill(
                          label: 'Roadmap board',
                          value: 'Live',
                          color: Color(0xFFB45309),
                        ),
                        _StatusPill(
                          label: 'Support',
                          value: 'hello@getreadyjob.com',
                          color: Color(0xFF1D4ED8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Launch shortcuts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: childAspectRatio,
                      children: [
                        _QuickActionCard(
                          icon: Icons.compress,
                          label: 'Compress',
                          subtitle: 'Target size workflow',
                          color: const Color(0xFF2563EB),
                          onTap: () => _openRoute(context, '/compress'),
                        ),
                        _QuickActionCard(
                          icon: Icons.swap_horiz,
                          label: 'Convert',
                          subtitle: 'PDF and document flow',
                          color: const Color(0xFF0F766E),
                          onTap: () => _openRoute(context, '/convert'),
                        ),
                        _QuickActionCard(
                          icon: Icons.auto_awesome,
                          label: 'AI Assistant',
                          subtitle: 'Summaries and document questions',
                          color: const Color(0xFF1D4ED8),
                          onTap: () => _openRoute(context, '/ai-assistant'),
                        ),
                        _QuickActionCard(
                          icon: Icons.edit_note,
                          label: 'AI Writing',
                          subtitle: 'Letters, SOPs, and rewrites',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _openRoute(context, '/ai-writing'),
                        ),
                        _QuickActionCard(
                          icon: Icons.work_outline,
                          label: 'Job Toolkit',
                          subtitle: 'Match score and interview prep',
                          color: const Color(0xFFB45309),
                          onTap: () => _openRoute(context, '/job-toolkit'),
                        ),
                        _QuickActionCard(
                          icon: Icons.school_outlined,
                          label: 'Academic Toolkit',
                          subtitle: 'SOP, LOR, and proposal drafts',
                          color: const Color(0xFF0E7490),
                          onTap: () => _openRoute(context, '/academic-toolkit'),
                        ),
                        _QuickActionCard(
                          icon: Icons.text_snippet_outlined,
                          label: 'Document Intelligence',
                          subtitle: 'OCR and structured extraction',
                          color: const Color(0xFFDC2626),
                          onTap: () => _openRoute(context, '/document-intelligence'),
                        ),
                        _QuickActionCard(
                          icon: Icons.folder_open_outlined,
                          label: 'Document Workspace',
                          subtitle: 'Search stored files and history',
                          color: const Color(0xFF1D4ED8),
                          onTap: () => _openRoute(context, '/document-workspace'),
                        ),
                        _QuickActionCard(
                          icon: Icons.track_changes_outlined,
                          label: 'V2 Growth Hub',
                          subtitle: 'Roadmap phases 7 to 15',
                          color: const Color(0xFF059669),
                          onTap: () => _openRoute(context, '/v2-growth'),
                        ),
                        _QuickActionCard(
                          icon: Icons.rocket_launch_outlined,
                          label: 'Endgame 8-15',
                          subtitle: 'Final execution console',
                          color: const Color(0xFF0F766E),
                          onTap: () => _openRoute(context, '/v2-endgame'),
                        ),
                        _QuickActionCard(
                          icon: Icons.badge_outlined,
                          label: 'Resume Builder',
                          subtitle: 'Start the V2 career workspace',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _openRoute(context, '/resume'),
                        ),
                        _QuickActionCard(
                          icon: Icons.photo_size_select_large_rounded,
                          label: 'Photo HD',
                          subtitle: 'Passport photo to larger print sizes',
                          color: const Color(0xFF0E7490),
                          onTap: () => _openRoute(context, '/photo-hd'),
                        ),
                        _QuickActionCard(
                          icon: Icons.route,
                          label: 'V2 Roadmap',
                          subtitle: 'Track active and planned V2 modules',
                          color: const Color(0xFF4F46E5),
                          onTap: () => _openRoute(context, '/v2-roadmap'),
                        ),
                        _QuickActionCard(
                          icon: Icons.call_merge,
                          label: 'Merge',
                          subtitle: 'Combine files safely',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _openRoute(context, '/merge'),
                        ),
                        _QuickActionCard(
                          icon: Icons.call_split,
                          label: 'Split',
                          subtitle: 'Divide large PDFs',
                          color: const Color(0xFFB45309),
                          onTap: () => _openRoute(context, '/split'),
                        ),
                        _QuickActionCard(
                          icon: Icons.search,
                          label: 'Extract',
                          subtitle: 'Pull selected pages',
                          color: const Color(0xFFDC2626),
                          onTap: () => _openRoute(context, '/extract'),
                        ),
                        _QuickActionCard(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF Tools',
                          subtitle: 'Workspace and edits',
                          color: const Color(0xFF1D4ED8),
                          onTap: () => _openRoute(context, '/pdf-tools'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCE7F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.support_agent_outlined,
                              color: Color(0xFF2563EB),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Build notes',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'V2 is kept as a separate workspace. Stable V1 launch files stay untouched while this branch grows. For release coordination, use ${PublicBrandConfig.supportEmail}.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopNavAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F172A),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD8E5F5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDDE7F4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
