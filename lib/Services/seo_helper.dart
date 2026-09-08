import 'dart:convert';

import 'package:universal_html/html.dart' as html;

/// Shared helper for setting per-page SEO metadata on web builds: tab title,
/// meta description/keywords, OG/Twitter tags, canonical + hreflang links,
/// and optional JSON-LD structured data.
///
/// Consolidates the pattern that used to be copy-pasted privately inside
/// blog_page.dart, blog_detail_page.dart, and convert_tool_page.dart.
class SeoHelper {
  const SeoHelper._();

  static const String baseUrl = 'https://getreadyjob.com';

  /// Applies title/meta/canonical/OG/Twitter tags for the current page.
  /// [path] is the site-relative route (e.g. '/govt-verifier') used to build
  /// the canonical and hreflang URLs. Pass [jsonLd] to also upsert a
  /// structured-data script tag, keyed by [jsonLdKey] (defaults to [path]).
  static void apply({
    required String title,
    required String description,
    required String path,
    String? keywords,
    Map<String, dynamic>? jsonLd,
    String? jsonLdKey,
  }) {
    final url = path.startsWith('http') ? path : '$baseUrl$path';

    html.document.title = title;
    upsertMetaTag(name: 'description', content: description);
    if (keywords != null) {
      upsertMetaTag(name: 'keywords', content: keywords);
    }
    upsertMetaTag(name: 'geo.region', content: 'IN');
    upsertMetaTag(property: 'og:title', content: title);
    upsertMetaTag(property: 'og:description', content: description);
    upsertMetaTag(property: 'og:url', content: url);
    upsertMetaTag(name: 'twitter:title', content: title);
    upsertMetaTag(name: 'twitter:description', content: description);
    upsertLinkTag(rel: 'canonical', href: url);
    upsertLinkTag(rel: 'alternate', href: url, hreflang: 'x-default');
    upsertLinkTag(rel: 'alternate', href: url, hreflang: 'en-in');

    if (jsonLd != null) {
      upsertJsonLdScript(json: jsonLd, key: jsonLdKey ?? path);
    }
  }

  static void upsertMetaTag({String? name, String? property, required String content}) {
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

  static void upsertLinkTag({required String rel, required String href, String? hreflang}) {
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

  static void upsertJsonLdScript({required Map<String, dynamic> json, required String key}) {
    final existing = html.document.querySelector('script[data-seo-page="$key"]');
    existing?.remove();

    final script = html.ScriptElement();
    script.type = 'application/ld+json';
    script.setAttribute('data-seo-page', key);
    script.text = jsonEncode(json);
    html.document.head!.append(script);
  }
}
