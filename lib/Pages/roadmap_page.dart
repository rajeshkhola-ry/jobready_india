import 'package:flutter/material.dart';

import 'site_content_page.dart';

class RoadmapPage extends StatelessWidget {
  const RoadmapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Roadmap',
      intro: 'GET READY JOB is moving through a structured V2 technical roadmap focused on stronger compression, bilingual OCR, and next-generation photo workflows.',
      highlights: ['V1.1 SEO', 'V2 Compression', 'Bilingual OCR', 'HD Photo Studio'],
      sections: [
        SiteContentSection(
          title: 'V1.1 SEO System Status',
          body: 'Baseline SEO setup has been applied for web deployment: meta coverage, structured data schema, robots.txt, and sitemap. Ongoing work is periodic validation in live search tools.',
        ),
        SiteContentSection(
          title: 'V2 Compression Upgrade',
          body: 'Compression roadmap focuses on quality and efficiency upgrades using Ghostscript-assisted PDF compression and modern WebP pipelines for image-heavy workflows.',
        ),
        SiteContentSection(
          title: 'OCR Roadmap (Hindi + English)',
          body: 'OCR roadmap is centered on reliable bilingual extraction for Hindi and English documents, including better handling of mixed-language scans and low-quality source files.',
        ),
        SiteContentSection(
          title: 'HD Photo Studio Roadmap',
          body: 'Photo roadmap includes restore, upscale, face enhancement, and colorization capabilities with a controlled rollout after stability and performance validation.',
        ),
      ],
    );
  }
}
