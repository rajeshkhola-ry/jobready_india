import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

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
    final document = html.document;
    const title = 'Career Blog India | Resume Tips, ATS Guides & PDF Tools';
    const description = 'Explore practical blog posts for Indian job seekers covering ATS formatting, resume building, PDF conversion, and interview preparation.';
    const url = 'https://getreadyjob.com/blog';

    document.title = title;
    _upsertMetaTag(name: 'description', content: description);
    _upsertMetaTag(name: 'keywords', content: 'career blog India, ATS resume tips, PDF to Word India, resume builder blog');
    _upsertMetaTag(name: 'geo.region', content: 'IN');
    _upsertMetaTag(property: 'og:title', content: title);
    _upsertMetaTag(property: 'og:description', content: description);
    _upsertMetaTag(property: 'og:url', content: url);
    _upsertMetaTag(name: 'twitter:title', content: title);
    _upsertMetaTag(name: 'twitter:description', content: description);
    _upsertLinkTag(rel: 'canonical', href: url);
    _upsertLinkTag(rel: 'alternate', href: url, hreflang: 'x-default');
    _upsertLinkTag(rel: 'alternate', href: url, hreflang: 'en-in');

    _upsertJsonLdScript(
      json: {
        '@context': 'https://schema.org',
        '@type': 'Blog',
        'name': title,
        'url': url,
        'description': description,
        'inLanguage': 'en-IN',
        'publisher': {
          '@type': 'Organization',
          'name': 'GET READY JOB',
          'url': 'https://getreadyjob.com',
        },
      },
    );
  }

  void _upsertMetaTag({String? name, String? property, required String content}) {
    final selector = name != null
        ? 'meta[name="$name"]'
        : 'meta[property="$property"]';
    final existing = html.document.querySelector(selector);
    if (existing != null) {
      existing.setAttribute('content', content);
      return;
    }

    final meta = html.MetaElement();
    if (name != null) {
      meta.setAttribute('name', name);
    }
    if (property != null) {
      meta.setAttribute('property', property);
    }
    meta.setAttribute('content', content);
    html.document.head!.append(meta);
  }

  void _upsertLinkTag({required String rel, required String href, String? hreflang}) {
    final selector = hreflang != null
        ? 'link[rel="$rel"][hreflang="$hreflang"]'
        : 'link[rel="$rel"]';
    final existing = html.document.querySelector(selector);
    if (existing != null) {
      existing.setAttribute('href', href);
      return;
    }

    final link = html.LinkElement()
      ..setAttribute('rel', rel)
      ..setAttribute('href', href);
    if (hreflang != null) {
      link.setAttribute('hreflang', hreflang);
    }
    html.document.head!.append(link);
  }

  void _upsertJsonLdScript({required Map<String, dynamic> json}) {
    final existing = html.document.querySelector('script[data-seo-blog-listing="true"]');
    existing?.remove();

    final script = html.ScriptElement();
    script.type = 'application/ld+json';
    script.setAttribute('data-seo-blog-listing', 'true');
    script.text = jsonEncode(json);
    html.document.head!.append(script);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
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
