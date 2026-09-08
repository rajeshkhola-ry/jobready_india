import 'package:flutter/material.dart';

import '../Services/seo_helper.dart';
import '../Widgets/brand_logo_button.dart';
import '../Widgets/production_footer.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  @override
  void initState() {
    super.initState();
    _applyBlogSeoMetadata();
  }

  void _applyBlogSeoMetadata() {
    const title = 'Career Blog India | Resume Tips, ATS Guides & PDF Tools';
    const description = 'Explore practical blog posts for Indian job seekers covering ATS formatting, resume building, PDF conversion, and interview preparation.';
    const path = '/blog';

    SeoHelper.apply(
      title: title,
      description: description,
      path: path,
      keywords: 'career blog India, ATS resume tips, PDF to Word India, resume builder blog',
      jsonLdKey: 'blog-listing',
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'Blog',
        'name': title,
        'url': '${SeoHelper.baseUrl}$path',
        'description': description,
        'inLanguage': 'en-IN',
        'publisher': {
          '@type': 'Organization',
          'name': 'GET READY JOB',
          'url': SeoHelper.baseUrl,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoButton(
              size: 30,
              padding: const EdgeInsets.all(2),
              tooltip: 'Go to home',
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Blog',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F8FC), Color(0xFFE6EEF7)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDDE7F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Career Blog for Indian Job Seekers',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Read practical articles about ATS resumes, interview prep, PDF workflows, and faster application strategies for Indian professionals.',
                    style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      Chip(label: Text('Resume Tips')),
                      Chip(label: Text('ATS Guides')),
                      Chip(label: Text('PDF Tools')),
                      Chip(label: Text('Interview Prep')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildPostCard(
              context,
              title: 'AI Resume Builder India: Create Job-Ready Profiles Faster',
              summary: 'Learn how Indian job seekers can prepare ATS-ready resumes and respond to opportunities faster with the right tools.',
              route: '/blog-detail',
            ),
            const SizedBox(height: 12),
            _buildPostCard(
              context,
              title: 'Free Resume Converter for Indian Job Seekers',
              summary: 'Convert PDF resumes into editable Word files and improve your workflow with a simple and secure converter experience.',
              route: '/convert',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try the AI Resume Builder & Converter',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC72C), foregroundColor: const Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(context).pushNamed('/resume'),
                    child: const Text('Start Building'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const ProductionFooter(compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, {required String title, required String summary, required String route}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF475569))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(route),
            child: const Text('Read more'),
          ),
        ],
      ),
    );
  }
}
