import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import '../Utils/web_safe_browser.dart';

class ProductionFooter extends StatelessWidget {
  final bool compact;

  const ProductionFooter({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E233A), Color(0xFF102942)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GETREADYJOB',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Professional tools for resumes, documents, PDF workflows, and productivity tasks.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FooterRouteLink(label: 'About Us', route: '/about'),
              _FooterRouteLink(label: 'Contact', route: '/contact'),
              _FooterRouteLink(label: 'Pricing', route: '/pricing'),
              _FooterRouteLink(label: 'FAQ', route: '/faq'),
              _FooterRouteLink(label: 'Help Center / Support', route: '/support'),
              _FooterRouteLink(label: 'Privacy Policy', route: '/privacy'),
              _FooterRouteLink(label: 'Terms & Conditions', route: '/terms'),
              _FooterRouteLink(label: 'Cookie Policy', route: '/cookie-policy'),
              _FooterRouteLink(label: 'Disclaimer', route: '/disclaimer'),
              _FooterRouteLink(label: 'Customer Reviews / Testimonials', route: '/testimonials'),
            ],
          ),
          const SizedBox(height: 16),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: _BusinessAndSocialBlock()),
                    SizedBox(width: 12),
                    Expanded(child: _FooterMetaBlock()),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BusinessAndSocialBlock(),
                    SizedBox(height: 12),
                    _FooterMetaBlock(),
                  ],
                ),
        ],
      ),
    );
  }
}

class _FooterRouteLink extends StatelessWidget {
  final String label;
  final String route;

  const _FooterRouteLink({
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF36506B)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BusinessAndSocialBlock extends StatelessWidget {
  const _BusinessAndSocialBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business email: ${PublicBrandConfig.supportEmail}',
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _FooterExternalLinkChip(
              label: 'Instagram',
              url: 'https://instagram.com/getreadyjob',
              icon: Icons.camera_alt_rounded,
              iconColor: Color(0xFFE1306C),
            ),
            _FooterExternalLinkChip(
              label: 'Facebook',
              url: 'https://facebook.com/profile.php?id=615933517430528',
              icon: Icons.facebook_rounded,
              iconColor: Color(0xFF1877F2),
            ),
            _FooterExternalLinkChip(
              label: 'LinkedIn',
              url: 'https://linkedin.com/company/getreadyjob',
              icon: Icons.business_center_rounded,
              iconColor: Color(0xFF0A66C2),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterExternalLinkChip extends StatelessWidget {
  final String label;
  final String url;
  final IconData icon;
  final Color iconColor;

  const _FooterExternalLinkChip({
    required this.label,
    required this.url,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => WebSafeBrowser.openWindow(url),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF36506B)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterMetaBlock extends StatelessWidget {
  const _FooterMetaBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Website: getreadyjob.com',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/terms'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Patent Pending (App No. 202611096315)',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF93C5FD),
                  ),
                ),
              ),
            ),
            const Text(
              '|',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              '© 2026 GETREADYJOB. All Rights Reserved.',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'See Terms & Conditions for Legal & Patent Notice.',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
