import 'package:flutter/material.dart';

import 'site_content_page.dart';

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Disclaimer',
      intro: 'This disclaimer clarifies the current boundaries of GETREADYJOB services, outputs, and support scope.',
      highlights: ['General Use', 'No Legal Advice', 'No Employment Guarantee', 'User Responsibility'],
      sections: [
        SiteContentSection(
          title: 'General Information',
          body: 'GETREADYJOB provides software tools and product guidance for document and productivity workflows. Content and outputs are provided for general informational and practical use.',
        ),
        SiteContentSection(
          title: 'No Professional Advice',
          body: 'GETREADYJOB does not provide legal, financial, employment, immigration, or regulatory advice. Users should consult qualified professionals for expert guidance.',
        ),
        SiteContentSection(
          title: 'No Guarantee of Outcomes',
          body: 'Use of tools does not guarantee hiring, interview success, admissions, business outcomes, or specific document acceptance by third parties.',
        ),
        SiteContentSection(
          title: 'User Responsibility',
          body: 'Users are responsible for verifying final outputs and maintaining copies of important files before sharing or submitting them to external systems.',
        ),
      ],
    );
  }
}
