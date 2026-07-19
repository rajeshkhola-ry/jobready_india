import 'package:flutter/material.dart';

import 'site_content_page.dart';

class RoadmapPage extends StatelessWidget {
  const RoadmapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Roadmap',
      intro: 'GETREADYJOB is actively evolving. The roadmap helps users understand current priorities and future product direction.',
      highlights: ['Current RC', 'Phase 1', 'V2.1', 'Future AI'],
      sections: [
        SiteContentSection(
          title: 'Current Focus',
          body: 'The current focus is product polish, trust, legal readiness, user guidance, and commercial maturity across the public website.',
        ),
        SiteContentSection(
          title: 'Next Steps',
          body: 'Immediate roadmap goals include stronger public trust sections, legal/business pages, better tool guidance, SEO improvements, and support workflows.',
        ),
        SiteContentSection(
          title: 'Future Direction',
          body: 'Future roadmap items include AI-assisted workflows, advanced writing tools, business workspaces, and richer document intelligence.',
        ),
      ],
    );
  }
}
