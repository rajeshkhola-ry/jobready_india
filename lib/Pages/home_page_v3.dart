import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';

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
          'JOBREADY',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F8FC), Color(0xFFE6EEF7)],
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFD4F3)),
                      ),
                      child: const Text(
                        'Runtime: V2 | Entry: lib/main_v3.dart',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0E3A66),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B2E52), Color(0xFF1F4E79)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0E3A66).withValues(alpha: 0.24),
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
                                label: 'Resume Builder',
                                icon: Icons.description_outlined,
                              ),
                              _StatusChip(
                                label: 'PDF & Photo Tools',
                                icon: Icons.picture_as_pdf_outlined,
                              ),
                              _StatusChip(
                                label: 'No sign-up needed',
                                icon: Icons.lock_open_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Smart tools for your documents.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create, convert, merge, and export professional documents in seconds. Built for job seekers worldwide.',
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
                              ElevatedButton.icon(
                                onPressed: () => _openRoute(context, '/compress'),
                                icon: const Icon(Icons.compress),
                                label: const Text('Compress PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E3A66),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openRoute(context, '/resume'),
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('Build Resume'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0E3A66),
                                  side: const BorderSide(color: Color(0xFFD8E5F5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
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
                          _TopNavAction(
                            label: 'HISTORY',
                            onTap: () => _openRoute(context, '/history'),
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
                          label: 'Free to use',
                          value: 'Always',
                          color: Color(0xFF0F766E),
                        ),
                        _StatusPill(
                          label: 'Resume Builder',
                          value: 'Ready',
                          color: Color(0xFF0E3A66),
                        ),
                        _StatusPill(
                          label: 'Support',
                          value: PublicBrandConfig.supportEmail,
                          color: Color(0xFF0E3A66),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'All Tools',
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
                          icon: Icons.description_outlined,
                          label: 'Resume Builder',
                          subtitle: 'Create and export professional resumes',
                          color: const Color(0xFF0E3A66),
                          onTap: () => _openRoute(context, '/resume'),
                        ),
                        _QuickActionCard(
                          icon: Icons.transform,
                          label: 'Converter',
                          subtitle: 'PDF and document format conversion',
                          color: const Color(0xFF1F4E79),
                          onTap: () => _openRoute(context, '/converter-v2'),
                        ),
                        _QuickActionCard(
                          icon: Icons.compress,
                          label: 'Compress',
                          subtitle: 'Target size workflow',
                          color: const Color(0xFF0E3A66),
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
                          icon: Icons.photo_size_select_large_rounded,
                          label: 'Photo HD',
                          subtitle: 'Passport photo to larger print sizes',
                          color: const Color(0xFF0E7490),
                          onTap: () => _openRoute(context, '/photo-hd'),
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
                          color: const Color(0xFF1F4E79),
                          onTap: () => _openRoute(context, '/pdf-tools'),
                        ),
                        _QuickActionCard(
                          icon: Icons.history_rounded,
                          label: 'History',
                          subtitle: 'View document activity',
                          color: const Color(0xFF64748B),
                          onTap: () => _openRoute(context, '/history'),
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
                              color: Color(0xFF0E3A66),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Need help?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Have a question or need support? Our team is ready to help. Reach us at ${PublicBrandConfig.supportEmail} or visit getreadyjob.com.',
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
