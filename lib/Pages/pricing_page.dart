import 'package:flutter/material.dart';

import 'site_content_page.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Pricing',
      intro: 'GETREADYJOB pricing is evolving to support both free access and premium productivity workflows for users and businesses.',
      highlights: ['Free', 'Premium', 'Business', 'Enterprise'],
      sections: [
        SiteContentSection(
          title: 'Free',
          body: 'Core access for users who need practical document tools and basic productivity workflows.',
        ),
        SiteContentSection(
          title: 'Premium',
          body: 'Expanded workflow access, richer conversion and export experiences, and future premium capabilities.',
        ),
        SiteContentSection(
          title: 'Business and Enterprise',
          body: 'Future plans include organization-friendly workflows for teams, HR, education, and business productivity.',
        ),
        SiteContentSection(
          title: 'Upgrade Path',
          body: 'The public upgrade workflow will continue to mature in the next commercial-readiness checkpoints.',
        ),
      ],
    );
  }
}
