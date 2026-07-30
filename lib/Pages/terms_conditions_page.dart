import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
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
        elevation: 0,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
                        'By accessing and using GETREADYJOB (including Document Utilities, OCR Pipeline, and HD Photo Studio), you agree to these Terms & Conditions and browser cache usage.',
                  ),
                  const _Section(
                    title: '2. Platform Scope & Services',
                    body:
                        'GETREADYJOB provides online document conversion (PDF, Word, Excel, OCR), split/merge utilities, and media enhancement tools such as HD Photo Studio, Background Removal, and Image Upscaling.',
                  ),
                  const _Section(
                    title: '3. Privacy & Zero-Storage Policy',
                    body:
                        'Ephemeral Processing: All uploaded files, images, and processed document outputs are generated dynamically in memory or short-lived temporary streams.\n\nNo Retention: We do not store, archive, sell, or index your uploaded content or edited outputs. Download links serve freshly rendered buffers and bypass stale storage caches.',
                  ),
                  const _Section(
                    title: '4. User Conduct & Acceptable Use',
                    body:
                        'You agree not to use GETREADYJOB to process, create, or distribute unlawful or infringing material.',
                  ),
                  const _Section(
                    title: '5. Intellectual Property Rights',
                    body:
                        'Users retain full ownership over all documents and images uploaded and generated through the platform. GETREADYJOB claims no ownership over user content.',
                  ),
                  const _Section(
                    title: '6. Service Availability & Disclaimers',
                    body:
                        'Services are provided on an “as-is” basis without warranties regarding uninterrupted service or zero file transformation errors.',
                  ),
                  const _Section(
                    title: '7. Limitation of Liability',
                    body:
                        'GETREADYJOB shall not be liable for any indirect or consequential damages resulting from service disruption during file conversion or media editing.',
                  ),
                  const _Section(
                    title: 'Contact',
                    body: 'For legal and support matters, please contact ${PublicBrandConfig.supportEmail}.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Last updated: 2026-07-30',
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
