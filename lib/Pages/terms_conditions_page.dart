import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: const Color(0xFFFFC72C),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LegalTitle(),
          const SizedBox(height: 12),
          const _Section(
            title: '1. Acceptance of Terms',
            body:
                'By using JOBREADY, users agree to these Terms and Conditions. Continued use after updates means acceptance of revised terms.',
          ),
          const _Section(
            title: '2. Service Scope and Availability',
            body:
                'Services are provided on an "as is" and "as available" basis. We may modify, suspend, or discontinue features without prior notice for maintenance, legal, or operational reasons.',
          ),
          const _Section(
            title: '3. User Responsibilities',
            body:
                'Users must provide lawful content, keep account/device access secure, and avoid misuse, reverse engineering, abuse, malware upload, or unlawful sharing.',
          ),
          const _Section(
            title: '4. Security and Cyber Incidents',
            body:
                'We implement reasonable technical and organizational safeguards, but no system is fully immune to cyber attacks, unauthorized access, or zero-day exploits. In case of a suspected breach, we may temporarily restrict service access, reset sessions, rotate credentials, and take emergency steps to protect platform integrity.',
          ),
          const _Section(
            title: '5. Data, Backup, and Recovery',
            body:
                'Users remain responsible for maintaining copies/backups of important files. While we aim to preserve service continuity, we do not guarantee prevention of data loss caused by third-party failures, user actions, malware, browser limitations, or force majeure events.',
          ),
          const _Section(
            title: '6. Payment, Plans, and Promotions',
            body:
                'Paid plans, discounts, and promo offers are governed by plan rules and validity windows. We may reject, deactivate, or revoke promotions in case of abuse, fraud, policy violations, or technical errors.',
          ),
          const _Section(
            title: '7. Third-Party Integrations',
            body:
                'Integrations (payment gateways, cloud providers, social sharing, external APIs) are controlled by third-party terms and uptime. We are not responsible for independent third-party outages, policy changes, account restrictions, or API deprecations.',
          ),
          const _Section(
            title: '8. Limitation of Liability',
            body:
                'To the maximum extent permitted by law, JOBREADY and its operators are not liable for indirect, incidental, special, consequential, or punitive damages, including business loss, loss of profit, or loss of data arising from platform use or inability to use the service.',
          ),
          const _Section(
            title: '9. Indemnification',
            body:
                'Users agree to indemnify and hold harmless JOBREADY from claims, losses, damages, and costs resulting from user content, misuse, policy violations, or unlawful activities.',
          ),
          const _Section(
            title: '10. Suspension and Termination',
            body:
                'We may suspend or terminate access if there is suspected fraud, abuse, security risk, legal non-compliance, or system integrity threat.',
          ),
          const _Section(
            title: '11. Mobile App Installation Permissions and User Consent',
            body:
                'This point applies only to Android mobile and iPhone app installation. Before any app download or installation continues, required permissions must be shown clearly and accepted by the user. If the user selects Cancel or Decline, the download or installation must stop. Typical permissions may include file or media access for document upload and save, notifications for optional updates, network or internet access for core service, and camera or gallery access only when a feature explicitly needs it.',
          ),
          const _Section(
            title: '12. Force Majeure',
            body:
                'We are not liable for delays or failures caused by events beyond reasonable control, including internet outages, cloud failures, natural disasters, government actions, cyber war, or large-scale infrastructure disruptions.',
          ),
          const _Section(
            title: '13. Governing Law and Disputes',
            body:
                'These terms are governed by applicable law in the service jurisdiction. Disputes should first be raised through support for good-faith resolution before formal proceedings.',
          ),
          const _Section(
            title: '14. Updates to Terms',
            body:
                'We may revise these terms periodically for legal, security, or product reasons. Updated terms apply from publication date.',
          ),
          const _Section(
            title: '15. Lifetime Offer Window and Service Closure',
            body:
                'Any "lifetime" offer is valid for up to 10 years from purchase date, subject to service availability. If the site/platform is shut down, permanently discontinued, or legally required to stop operations, the lifetime offer ends at that time. We may still change tools, pricing, features, or service scope without prior notice as stated in these terms.',
          ),
          const _Section(
            title: '16. Contact',
            body: 'For legal and support matters: ${PublicBrandConfig.supportEmail}',
          ),
          const SizedBox(height: 14),
          const Text(
            'Last updated: 2026-07-17',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LegalTitle extends StatelessWidget {
  const _LegalTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        'Important Notice: This document sets core service terms and risk controls. For jurisdiction-specific enforceability, have legal counsel review and approve before production launch.',
        style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF78350F), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.4),
          ),
        ],
      ),
    );
  }
}
