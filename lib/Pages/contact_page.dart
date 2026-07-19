import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import 'site_content_page.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteContentPage(
      title: 'Contact',
      intro: 'For product questions, support requests, partnership inquiries, and legal communication, please use the official business contact below.',
      highlights: const ['Support', 'Business', 'Partnerships', 'Product Feedback'],
      sections: [
        SiteContentSection(
          title: 'Official Business Email',
          body: PublicBrandConfig.supportEmail,
        ),
        const SiteContentSection(
          title: 'Response Scope',
          body: 'Use contact channels for support, business communication, roadmap feedback, and general questions about GETREADYJOB services.',
        ),
        const SiteContentSection(
          title: 'Before You Contact Us',
          body: 'For the fastest help, include the tool name, what you were trying to do, what file type you used, and any error message or unexpected result.',
        ),
      ],
    );
  }
}
