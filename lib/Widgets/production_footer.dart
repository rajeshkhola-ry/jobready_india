import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';

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
        color: const Color(0xFF0F172A),
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
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF334155)),
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
        const Text(
          'Social: LinkedIn (Coming Soon) • X/Twitter (Coming Soon) • YouTube (Coming Soon)',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FooterMetaBlock extends StatelessWidget {
  const _FooterMetaBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Website: getreadyjob.com',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Copyright 2026 GETREADYJOB. All rights reserved.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
