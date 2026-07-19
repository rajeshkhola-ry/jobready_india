import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import 'site_content_page.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteContentPage(
      title: 'Support',
      intro: 'Support is available for product questions, workflow issues, and user guidance. This page is the public-facing baseline for the growing GETREADYJOB support experience.',
      highlights: const ['Help', 'Workflow Issues', 'Product Questions', 'Support Email'],
      sections: [
        SiteContentSection(
          title: 'Contact Support',
          body: PublicBrandConfig.supportEmail,
        ),
        const SiteContentSection(
          title: 'What To Include',
          body: 'Share the tool name, source file type, what happened, and what result you expected. This helps reduce turnaround time for support.',
        ),
        const SiteContentSection(
          title: 'Support Scope',
          body: 'Support currently focuses on product use, workflow guidance, and issue reporting. A richer support-center experience is planned in future checkpoints.',
        ),
      ],
    );
  }
}
