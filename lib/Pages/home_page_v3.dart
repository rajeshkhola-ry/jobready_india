import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import '../Widgets/production_footer.dart';

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
          'Get Job Ready',
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
                            color: const Color(0xFF1F2937).withValues(alpha: 0.24),
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
                                  backgroundColor: const Color(0xFF1F2937),
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
                                  foregroundColor: const Color(0xFF1F2937),
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
                          _TopNavAction(label: 'HOME', onTap: () => _openRoute(context, '/home')),
                          _TopNavAction(label: 'RESUME', onTap: () => _openRoute(context, '/resume')),
                          _TopNavAction(label: 'CONVERTER', onTap: () => _openRoute(context, '/converter-v2')),
                          _TopNavAction(label: 'PHOTO HD', onTap: () => _openRoute(context, '/photo-hd')),
                          _TopNavAction(label: 'MERGE', onTap: () => _openRoute(context, '/merge')),
                          _TopNavAction(label: 'SPLIT', onTap: () => _openRoute(context, '/split')),
                          _TopNavAction(label: 'PDF TOOLS', onTap: () => _openRoute(context, '/pdf-tools')),
                          _TopNavAction(label: 'HISTORY', onTap: () => _openRoute(context, '/history')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _StatusPill(label: 'Free for 15 days', value: 'All features except AI', color: Color(0xFF0F766E)),
                        _StatusPill(label: 'Resume Builder', value: 'Ready', color: Color(0xFF1F2937)),
                        _StatusPill(label: 'Support', value: PublicBrandConfig.supportEmail, color: Color(0xFF1F2937)),
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
                          color: const Color(0xFF1F2937),
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
                          color: const Color(0xFF1F2937),
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
                    const Text(
                      'Why GETREADYJOB?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: width >= 980 ? 3 : width >= 640 ? 2 : 1,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: width >= 700 ? 2.2 : 2.8,
                      children: const [
                        _InfoCard(icon: Icons.flash_on_rounded, title: 'Fast', description: 'Quick document actions for everyday job, study, and office tasks.'),
                        _InfoCard(icon: Icons.shield_rounded, title: 'Secure', description: 'Built with privacy-first handling and controlled processing flows.'),
                        _InfoCard(icon: Icons.lock_outline_rounded, title: 'Private', description: 'User-focused workflows with clear support and retention direction.'),
                        _InfoCard(icon: Icons.verified_rounded, title: 'No Watermark', description: 'Professional outputs designed to stay clean and ready to use.'),
                        _InfoCard(icon: Icons.phone_android_rounded, title: 'Mobile Friendly', description: 'Responsive layouts that stay usable across desktop, tablet, and mobile.'),
                        _InfoCard(icon: Icons.auto_awesome_rounded, title: 'AI Powered', description: 'AI-assisted workflows are planned to expand in the next roadmap phases.'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Trusted by Growing Users',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: const [
                        _MetricCard(label: 'Documents Converted', value: '25K+'),
                        _MetricCard(label: 'Active Users', value: '3.2K+'),
                        _MetricCard(label: 'Countries Served', value: '40+'),
                        _MetricCard(label: 'Avg Processing Time', value: '< 30 sec'),
                        _MetricCard(label: 'Customer Satisfaction', value: '4.9/5'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Built for Modern Work',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        const _AudiencePill(label: 'Students'),
                        const _AudiencePill(label: 'Teachers'),
                        const _AudiencePill(label: 'HR Teams'),
                        const _AudiencePill(label: 'Small Businesses'),
                        const _AudiencePill(label: 'Recruiters'),
                        const _AudiencePill(label: 'Enterprises'),
                        _AudiencePill(label: 'See Solutions', isPrimary: true, onTap: () => _openRoute(context, '/solutions')),
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
                      ),
                      child: width >= 760
                          ? const Row(
                              children: [
                                Expanded(
                                  child: _IdentityBlock(
                                    title: 'Our Mission',
                                    body: 'Build practical software that helps people work faster with resumes, documents, PDF workflows, and professional productivity tasks.',
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: _IdentityBlock(
                                    title: 'Our Vision',
                                    body: 'Grow GETREADYJOB into a trusted software company for careers, education, documents, and business workflows.',
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              children: [
                                _IdentityBlock(
                                  title: 'Our Mission',
                                  body: 'Build practical software that helps people work faster with resumes, documents, PDF workflows, and professional productivity tasks.',
                                ),
                                SizedBox(height: 14),
                                _IdentityBlock(
                                  title: 'Our Vision',
                                  body: 'Grow GETREADYJOB into a trusted software company for careers, education, documents, and business workflows.',
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F2937).withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: width >= 760
                          ? const Row(
                              children: [
                                Expanded(child: _ReviewBlock()),
                                SizedBox(width: 18),
                                Expanded(child: _SecurityBlock()),
                              ],
                            )
                          : const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ReviewBlock(),
                                SizedBox(height: 18),
                                _SecurityBlock(),
                              ],
                            ),
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
                      child: width >= 760
                          ? Row(
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
                                    color: Color(0xFF1F2937),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: _HelpBlock(supportEmail: PublicBrandConfig.supportEmail)),
                              ],
                            )
                          : Column(
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
                                    color: Color(0xFF1F2937),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _HelpBlock(supportEmail: PublicBrandConfig.supportEmail),
                              ],
                            ),
                    ),
                    const SizedBox(height: 22),
                    const ProductionFooter(),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7F4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1F2937), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudiencePill extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _AudiencePill({
    required this.label,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDDE7F4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : const Color(0xFF1F2937),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  final String title;
  final String body;

  const _IdentityBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HelpBlock extends StatelessWidget {
  final String supportEmail;

  const _HelpBlock({required this.supportEmail});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          'Have a question or need support? Our team is ready to help. Reach us at $supportEmail or visit getreadyjob.com.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'User Reviews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '4.9/5',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '★★★★★ placeholder for future Google reviews and customer testimonials.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SecurityBlock extends StatelessWidget {
  const _SecurityBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Security & Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Files processed securely\nFiles deleted automatically\nSSL encrypted\nPrivacy-first approach',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ],
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
