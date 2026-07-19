import 'package:flutter/material.dart';

import 'site_content_page.dart';

class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Knowledge Center',
      intro: 'The GETREADYJOB knowledge center will grow into a practical content hub for resumes, PDF workflows, interviews, career guidance, and productivity help.',
      highlights: ['Resume Tips', 'Interview Tips', 'PDF Guides', 'Career Advice', 'Productivity Tips'],
      sections: [
        SiteContentSection(
          title: 'Resume Tips',
          body: 'Planned articles will help users improve structure, relevance, formatting, and ATS readiness across resume workflows.',
        ),
        SiteContentSection(
          title: 'Interview Tips',
          body: 'Future content will support preparation, confidence, and practical interview readiness for different roles and industries.',
        ),
        SiteContentSection(
          title: 'PDF Guides',
          body: 'The blog will expand with focused how-to guides for conversion, compression, editing, extraction, and document workflow tasks.',
        ),
        SiteContentSection(
          title: 'Career and Productivity Advice',
          body: 'GETREADYJOB will continue to broaden into a practical software platform for career progress and professional productivity.',
        ),
      ],
    );
  }
}
