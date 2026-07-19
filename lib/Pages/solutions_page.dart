import 'package:flutter/material.dart';

import 'site_content_page.dart';

class SolutionsPage extends StatelessWidget {
  const SolutionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'Who GETREADYJOB Is For',
      intro: 'GETREADYJOB is growing beyond individual file utility into a broader productivity platform for education, hiring, and business workflows.',
      highlights: ['Students', 'Teachers', 'HR Teams', 'Small Businesses', 'Recruiters', 'Enterprises'],
      sections: [
        SiteContentSection(
          title: 'Students and Teachers',
          body: 'Document conversion, PDF workflows, academic support, and future guided writing tools can simplify study and teaching tasks.',
        ),
        SiteContentSection(
          title: 'HR Teams and Recruiters',
          body: 'Resume workflows, document handling, and future hiring-focused features can support candidate evaluation and communication.',
        ),
        SiteContentSection(
          title: 'Small Businesses and Enterprises',
          body: 'Professional document operations, future collaboration surfaces, and stronger workflow reliability will support broader business use cases.',
        ),
      ],
    );
  }
}
