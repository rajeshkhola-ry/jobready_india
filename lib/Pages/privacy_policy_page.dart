import 'package:flutter/material.dart';

import 'site_content_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Privacy Policy',
      intro: 'This privacy policy explains the current privacy direction of GETREADYJOB and will continue to be refined as the product matures.',
      highlights: ['Privacy First', 'File Handling', 'Support', 'Transparency'],
      sections: [
        SiteContentSection(
          title: 'Privacy Approach',
          body: 'GETREADYJOB is designed to minimize unnecessary friction around document workflows while moving toward stronger published privacy controls and transparency.',
        ),
        SiteContentSection(
          title: 'File Handling',
          body: 'Users should avoid relying on the platform as their only storage location and should keep their own copies of important files.',
        ),
        SiteContentSection(
          title: 'Support and Communication',
          body: 'If privacy-related concerns arise, users can contact the official business email listed across the product.',
        ),
        SiteContentSection(
          title: 'Policy Updates',
          body: 'This policy may be refined as privacy architecture, retention controls, and compliance requirements mature.',
        ),
      ],
    );
  }
}
