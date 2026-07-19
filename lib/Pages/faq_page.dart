import 'package:flutter/material.dart';

import 'site_content_page.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'FAQ',
      intro: 'Common questions about files, supported formats, privacy, quality, and future product direction.',
      highlights: ['Files', 'Privacy', 'Formats', 'Pricing'],
      sections: [
        SiteContentSection(
          title: 'What does GETREADYJOB do?',
          body: 'GETREADYJOB provides resume, PDF, conversion, extraction, compression, and document productivity tools in one place.',
        ),
        SiteContentSection(
          title: 'Are my files processed securely?',
          body: 'The product is designed with a privacy-first workflow. Legal and operational policies continue to be expanded as the platform matures.',
        ),
        SiteContentSection(
          title: 'Which tools are available today?',
          body: 'Core live tools include compression, conversion, merge, split, extract, PDF editing flows, resume tools, photo resizing, and history features.',
        ),
        SiteContentSection(
          title: 'Will more features be added?',
          body: 'Yes. The roadmap includes stronger AI assistance, advanced writing tools, business workflows, and expanded document intelligence.',
        ),
      ],
    );
  }
}
