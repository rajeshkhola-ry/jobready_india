import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Widgets/production_footer.dart';

class BlogDetailPage extends StatefulWidget {
  const BlogDetailPage({super.key});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  @override
  void initState() {
    super.initState();
    _applyBlogDetailSeoMetadata();
  }

  void _applyBlogDetailSeoMetadata() {
    final document = html.document;
    const title = 'AI Resume Builder India: Create Job-Ready Profiles Faster';
    const description = 'Learn how Indian professionals can use AI resume builder tools, ATS-friendly formatting, and smart converter workflows to improve interview readiness.';
    const url = 'https://getreadyjob.com/blog/ai-resume-builder-india';

    document.title = title;
    _upsertMetaTag(name: 'description', content: description);
    _upsertMetaTag(name: 'keywords', content: 'AI resume builder India, ATS resume tips, career blog India, PDF to Word India');
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
        '@type': 'BlogPosting',
        'headline': title,
        'description': description,
        'url': url,
        'author': {
          '@type': 'Organization',
          'name': 'GET READY JOB',
        },
        'publisher': {
          '@type': 'Organization',
          'name': 'GET READY JOB',
          'logo': {
            '@type': 'ImageObject',
            'url': 'https://getreadyjob.com/icons/GRJ-512.png',
          },
        },
        'datePublished': '2026-07-31',
        'dateModified': '2026-07-31',
        'articleSection': 'Career Growth',
        'keywords': 'AI resume builder India, ATS resume, PDF to Word India',
      },
    );

    _upsertJsonLdScript(
      json: {
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        'mainEntity': [
          {
            '@type': 'Question',
            'name': 'Can Indian job seekers use AI resume tools for free?',
            'acceptedAnswer': {
              '@type': 'Answer',
              'text': 'Yes. GET READY JOB helps Indian job seekers build ATS-ready resumes, convert PDF resumes to editable Word files, and prepare for interviews without paying for a subscription.',
            },
          },
          {
            '@type': 'Question',
            'name': 'How does ATS formatting help in India?',
            'acceptedAnswer': {
              '@type': 'Answer',
              'text': 'ATS formatting improves keyword alignment and document clarity so resumes are more likely to pass recruiter screening across Indian MNCs and startups.',
            },
          },
        ],
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
    final existing = html.document.querySelector('script[data-seo-blog="true"]');
    existing?.remove();

    final script = html.ScriptElement();
    script.type = 'application/ld+json';
    script.setAttribute('data-seo-blog', 'true');
    script.text = jsonEncode(json);
    html.document.head!.append(script);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        title: const Text('Blog Detail'),
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
                    'AI Resume Builder India: Create Job-Ready Profiles Faster',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Indian job seekers are now competing for roles in startups, MNCs, and hybrid teams. The right resume workflow can make a measurable difference in response rates, interview scheduling, and confidence during job applications.',
                    style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'A strong AI resume builder workflow focuses on three things: a clear summary, ATS-friendly formatting, and resume versions tailored to each role. Pair that with a quick converter workflow for PDF to Word edits, and you can respond to opportunities much faster.',
                    style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF475569)),
                  ),
                ],
              ),
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
                    'Try the free workflow that helps Indian candidates stand out',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC72C), foregroundColor: const Color(0xFF0F172A)),
                        onPressed: () => Navigator.of(context).pushNamed('/resume'),
                        child: const Text('Try AI Resume Builder'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F172A)),
                        onPressed: () => Navigator.of(context).pushNamed('/converter'),
                        child: const Text('Use Resume Converter'),
                      ),
                    ],
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
}
