import 'package:flutter/material.dart';

import 'site_content_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteContentPage(
      title: 'About GETREADYJOB',
      intro: 'GETREADYJOB is building practical software for resumes, documents, PDF workflows, and professional productivity. The goal is to help users move faster with clean, reliable tools that feel simple to use.',
      highlights: ['Our Mission', 'Our Vision', 'Why GETREADYJOB', 'Our Story'],
      sections: [
        SiteContentSection(
          title: 'Our Mission',
          body: 'Build accessible tools that help people create, convert, improve, and manage professional documents without unnecessary friction.',
        ),
        SiteContentSection(
          title: 'Our Vision',
          body: 'Grow GETREADYJOB into a trusted document and career-productivity software company for users worldwide.',
        ),
        SiteContentSection(
          title: 'Why GETREADYJOB',
          body: 'The platform combines document utility, resume workflows, PDF tools, and future AI assistance into one focused ecosystem.',
        ),
        SiteContentSection(
          title: 'Our Story',
          body: 'GETREADYJOB is evolving from a focused document workflow platform into a broader product designed for job seekers, students, professionals, and teams.',
        ),
      ],
    );
  }
}
