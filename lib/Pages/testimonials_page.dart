import 'package:flutter/material.dart';

import 'site_content_page.dart';

class TestimonialsPage extends StatelessWidget {
  const TestimonialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Customer Reviews and Testimonials',
      intro: 'Customer reviews and testimonials are being expanded as part of the production trust layer.',
      highlights: ['Trust Layer', 'User Feedback', 'Coming Soon'],
      sections: [
        SiteContentSection(
          title: 'Status',
          body: 'Public testimonial modules are currently in progress and will be published after content verification and moderation workflows are finalized.',
        ),
        SiteContentSection(
          title: 'What Is Coming',
          body: 'This page will include verified customer stories, workflow outcomes, and product feedback snapshots to improve trust and transparency.',
        ),
        SiteContentSection(
          title: 'Want to Share Feedback?',
          body: 'Please send feedback and product experience notes to hello@getreadyjob.com. Selected reviews may be published with consent.',
        ),
      ],
    );
  }
}
