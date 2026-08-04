import 'package:flutter/material.dart';

import '../Widgets/brand_logo_button.dart';
import '../Widgets/production_footer.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: const Color(0xFFFFC72C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        titleSpacing: 12,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushNamedAndRemoveUntil('/home', (route) => false);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoButton(
              size: 28,
              padding: const EdgeInsets.all(2),
              tooltip: 'Go to home',
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Terms & Conditions',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'These terms govern your use of GETREADYJOB and its document, OCR, and photo enhancement services. By continuing to use the platform, you accept these terms and any future updates published on the site.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Section(
                    title: '1. Acceptance of Terms',
                    body:
                        'By accessing and using GETREADYJOB (including Document Utilities, OCR Pipeline, HD Photo Studio, and AI Tools), you agree to these Terms & Conditions, Privacy Policy, and browser cache usage.',
                  ),
                  const _Section(
                    title: '2. Platform Scope & Services',
                    body:
                        'GETREADYJOB provides online document conversion (PDF, Word, Excel, OCR), split/merge utilities, and media enhancement tools such as HD Photo Studio, Background Removal, and Image Upscaling.',
                  ),
                  const _Section(
                    title: '3. Subscription Plans & Service Modification/Termination Rights',
                    body:
                        '- Subscription Types: GETREADYJOB offers various access options, including Weekly, Monthly, Yearly, and Lifetime plans.\n\n- Definition of "Lifetime Plan": The term "Lifetime" in any plan, promotional offer, or pricing model refers strictly to a maximum product lifecycle of up to 10 (ten) calendar years from the date of purchase, or for as long as GETREADYJOB continues to operate and maintain the specific tool/service, whichever is shorter.\n\n- Absolute Authority to Terminate or Modify Services: GETREADYJOB reserves full, unconditional, and sole authority to modify, suspend, restrict, degrade, or completely terminate any subscription plan (Weekly, Monthly, Yearly, or Lifetime) or any individual tool/service at any time, for any reason, with or without prior notice to users.\n\n- Waiver of Claims: Users explicitly agree and acknowledge that they cannot raise any legal claims, disputes, demands, or questions against GETREADYJOB, its founders, or its parent company regarding service modification, plan termination, or tool deprecation.',
                  ),
                  const _Section(
                    title: '4. Refund & Cancellation Policy',
                    body:
                        '- All subscription payments, tier upgrades, and Lifetime purchases are final and non-refundable.\n\n- In the event of tool deprecation or plan termination, no partial or pro-rated refunds will be issued unless explicitly agreed to in writing by GETREADYJOB.',
                  ),
                  const _Section(
                    title: '5. Privacy & Zero-Storage Policy',
                    body:
                        '- Ephemeral Processing: All uploaded files, images, and processed document outputs are generated dynamically in memory or short-lived temporary streams.\n\n- No Retention: We do not store, archive, sell, or index your uploaded content or edited outputs. Download links serve freshly rendered buffers and bypass stale storage caches.',
                  ),
                  const _Section(
                    title: '6. User Conduct & Acceptable Use',
                    body:
                        '- You agree not to use GETREADYJOB to process, create, or distribute unlawful, harmful, or infringing material.\n\n- Fair Usage Policy (FUP): Automated bot activities, scraping, server overloading, or abusing unlimited processing capabilities are strictly prohibited. We reserve the right to ban or terminate any user account violating FUP without notice.',
                  ),
                  const _Section(
                    title: '7. Intellectual Property Rights',
                    body:
                        'Users retain full ownership over all documents and images uploaded and generated through the platform. GETREADYJOB claims no ownership over user content.',
                  ),
                  const _Section(
                    title: '8. Service Availability & Disclaimers',
                    body:
                        'Services are provided on an "as-is" and "as-available" basis without warranties of any kind regarding uninterrupted service, uptime guarantees, or zero file transformation errors.',
                  ),
                  const _Section(
                    title: '9. Limitation of Liability',
                    body:
                        'GETREADYJOB shall not be liable for any direct, indirect, incidental, or consequential damages resulting from service disruption, data loss, or tool termination during file conversion or media editing.',
                  ),
                  const _Section(
                    title: '10. Contact Information',
                    body: 'For legal and support matters, please contact: hello@getreadyjob.com',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Last updated: 2026-08-04',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const ProductionFooter(compact: true),
                ],
              ),
            ),
          ),
        ),
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
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4B5563),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
