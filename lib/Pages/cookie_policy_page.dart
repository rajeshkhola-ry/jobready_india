import 'package:flutter/material.dart';

import 'site_content_page.dart';

class CookiePolicyPage extends StatelessWidget {
  const CookiePolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Cookie Policy',
      intro: 'This page outlines the current cookie and analytics direction for GETREADYJOB web experiences.',
      highlights: ['Cookies', 'Analytics', 'Browser Controls'],
      sections: [
        SiteContentSection(
          title: 'Cookies and Local Storage',
          body: 'GETREADYJOB may use browser-based storage and analytics-related mechanisms to support user experience, product measurement, and workflow continuity.',
        ),
        SiteContentSection(
          title: 'Analytics Use',
          body: 'Analytics is used to understand page usage and feature interaction so the product can be improved responsibly over time.',
        ),
        SiteContentSection(
          title: 'Your Browser Controls',
          body: 'Users can manage cookies and local storage behavior through browser settings, though some site behavior may be affected.',
        ),
      ],
    );
  }
}
