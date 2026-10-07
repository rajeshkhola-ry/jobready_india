#!/usr/bin/env node
/*
  Per-route pre-render for getreadyjob.com  (7 Oct 2026)

  WHY THIS EXISTS

  Every route on this site used to be served the SAME build/web/index.html.
  Firebase rewrites `**` to /index.html, and the per-route <title>, description
  and visible copy were applied afterwards by JavaScript, from the `routeSeo`
  table in the <head>.

  A browser sees the right page. A crawler, at fetch time, sees 32 byte-identical
  files. Google has to render the Dart app to tell /merge from /compress, and it
  deprioritises that - so Search Console reported "Duplicate, Google chose
  different canonical than user" and the tool pages sat at position 82-91.
  /merge collected 404 impressions and 0 clicks in three months.

  This script runs after `flutter build web` and writes a REAL file per route -
  build/web/<route>/index.html - each with its own title, description, keywords,
  Open Graph and Twitter tags, canonical link and visible content baked into the
  HTML before any JavaScript runs. Firebase Hosting serves a real file ahead of
  the `**` rewrite, so firebase.json needs no change.

  The routes and their metadata are READ FROM index.html itself, not duplicated
  here. There is one source of truth; editing routeSeo is still all it takes.

  Richer per-page copy can be supplied as seo-content/<slug>.html (slug = the
  route with its leading slash dropped and any remaining "/" turned into "-").
  When a file is present its contents become that page's visible block; when it
  is absent the page falls back to the route's title + description, plus its FAQ
  if routeSeo defines one.

  Usage:  node scripts/prerender.js            (from the project root)
          node scripts/prerender.js --dry-run  (report only, write nothing)
*/

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const BUILD_DIR = path.join(ROOT, 'build', 'web');
const INDEX = path.join(BUILD_DIR, 'index.html');
const CONTENT_DIR = path.join(ROOT, 'seo-content');
const ORIGIN = 'https://getreadyjob.com';
const DRY_RUN = process.argv.includes('--dry-run');

function fail(message) {
  console.error('\n  prerender: ' + message + '\n');
  process.exit(1);
}

/* ---------------------------------------------------------------- read ---- */

if (!fs.existsSync(INDEX)) {
  fail('build/web/index.html not found. Run `flutter build web --release` first.');
}

// Read as a string and only ever do string replacement, so whatever line
// endings the file has survive untouched.
const html = fs.readFileSync(INDEX, 'utf8');

/* ------------------------------------------------- extract the SEO table ---- */

function slice(startMarker, endMarker) {
  const start = html.indexOf(startMarker);
  if (start === -1) fail('could not find `' + startMarker + '` in index.html');
  const end = html.indexOf(endMarker, start);
  if (end === -1) fail('could not find the end of `' + startMarker + '` in index.html');
  return html.slice(start, end + endMarker.length);
}

const defaultSeoSrc = slice('var defaultSeo = {', '\n      };');
const routeSeoSrc = slice('var routeSeo = [', '\n      ];');

let defaultSeo, routeSeo;
try {
  // eslint-disable-next-line no-new-func
  const read = new Function(defaultSeoSrc + '\n' + routeSeoSrc + '\nreturn { defaultSeo, routeSeo };');
  const out = read();
  defaultSeo = out.defaultSeo;
  routeSeo = out.routeSeo;
} catch (err) {
  fail('could not evaluate the routeSeo table: ' + err.message);
}

if (!Array.isArray(routeSeo) || !routeSeo.length) fail('routeSeo came back empty.');

/* ------------------------------------------- work out each entry's paths ---- */

// Every test is of the form `route === '/x'` (optionally || route === '/y'),
// so the paths can be read straight out of the function source. If that ever
// stops being true this throws rather than silently skipping a page.
function pathsFor(entry, index) {
  const src = String(entry.test);
  const found = [];
  const re = /route === '([^']+)'/g;
  let m;
  while ((m = re.exec(src)) !== null) found.push(m[1]);
  if (!found.length) {
    fail('routeSeo entry #' + index + ' (' + (entry.url || 'no url') + ') has a test this ' +
         'script cannot read. Expected `route === \'/path\'`. Got: ' + src);
  }
  return found;
}

/* ------------------------------------------------------- build each page ---- */

function escapeHtml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Replace a single tag's attribute value, and say so if the tag is missing
// rather than producing a page that quietly kept the homepage's metadata.
function replaceAttr(source, pattern, replacement, label, route) {
  if (!pattern.test(source)) {
    fail('route ' + route + ': expected to find ' + label + ' in index.html and did not.');
  }
  return source.replace(pattern, replacement);
}

function staticBlockFor(entry, route) {
  const slug = route.replace(/^\//, '').replace(/\//g, '-');
  const file = path.join(CONTENT_DIR, slug + '.html');
  if (fs.existsSync(file)) {
    return { html: fs.readFileSync(file, 'utf8'), source: 'seo-content/' + slug + '.html' };
  }

  // The <title> carries a brand suffix for the search result; an <h1> should
  // not repeat it, so anything after the first "|" is dropped for the heading.
  const heading = String(entry.title).split('|')[0].trim() || entry.title;

  let out = '<header><h1>' + escapeHtml(heading) + '</h1><p>' +
            escapeHtml(entry.description) + '</p></header><main>';
  if (entry.faq && entry.faq.length) {
    out += '<section aria-label="FAQ"><h2>Frequently Asked Questions</h2><dl>';
    entry.faq.forEach(function (item) {
      out += '<dt>' + escapeHtml(item.q) + '</dt><dd>' + escapeHtml(item.a) + '</dd>';
    });
    out += '</dl></section>';
  }
  out += '</main>';
  return { html: out, source: 'routeSeo fallback' };
}

// index.html is a CRLF file. Content pulled in from seo-content/ may well be
// LF, and splicing it in unchanged leaves one file with both. Harmless to a
// browser, but it makes every later diff noisy, so injected text is normalised
// to whatever the host file already uses.
const HOST_EOL = html.indexOf('\r\n') !== -1 ? '\r\n' : '\n';
function toHostEol(text) {
  return String(text).replace(/\r\n/g, '\n').replace(/\n/g, HOST_EOL);
}

const STATIC_BLOCK_RE = /(<div id="grj-seo-static">)([\s\S]*?)(<\/div>)/;
if (!STATIC_BLOCK_RE.test(html)) {
  fail('could not find <div id="grj-seo-static"> in index.html.');
}

function render(entry, route, canonical) {
  const ogTitle = entry.ogTitle || entry.title;
  const ogDescription = entry.ogDescription || entry.description;
  const block = staticBlockFor(entry, route);

  let page = html;
  page = replaceAttr(page, /<title>[\s\S]*?<\/title>/,
    '<title>' + escapeHtml(entry.title) + '</title>', '<title>', route);
  page = replaceAttr(page, /<meta name="description" content="[^"]*">/,
    '<meta name="description" content="' + escapeHtml(entry.description) + '">',
    'the description meta', route);
  page = replaceAttr(page, /<meta name="keywords" content="[^"]*">/,
    '<meta name="keywords" content="' + escapeHtml(entry.keywords || '') + '">',
    'the keywords meta', route);
  page = replaceAttr(page, /<meta property="og:title" content="[^"]*">/,
    '<meta property="og:title" content="' + escapeHtml(ogTitle) + '">', 'og:title', route);
  page = replaceAttr(page, /<meta property="og:description" content="[^"]*">/,
    '<meta property="og:description" content="' + escapeHtml(ogDescription) + '">',
    'og:description', route);
  page = replaceAttr(page, /<meta property="og:url" content="[^"]*">/,
    '<meta property="og:url" content="' + canonical + '">', 'og:url', route);
  page = replaceAttr(page, /<meta name="twitter:title" content="[^"]*">/,
    '<meta name="twitter:title" content="' + escapeHtml(ogTitle) + '">', 'twitter:title', route);
  page = replaceAttr(page, /<meta name="twitter:description" content="[^"]*">/,
    '<meta name="twitter:description" content="' + escapeHtml(ogDescription) + '">',
    'twitter:description', route);
  page = replaceAttr(page, /<link rel="canonical" href="[^"]*">/,
    '<link rel="canonical" href="' + canonical + '">', 'the canonical link', route);

  // data-grj-prerendered tells the in-body fallback script to leave this alone.
  // Without it that script would overwrite the copy below with the one-line
  // title+description version the moment the page loads.
  page = page.replace(STATIC_BLOCK_RE,
    '<div id="grj-seo-static" data-grj-prerendered="1">' + toHostEol(block.html) + '</div>');

  return { page: page, source: block.source };
}

/* ------------------------------------------------------------- write it ---- */

const written = [];
const seen = new Map();

routeSeo.forEach(function (entry, index) {
  const paths = pathsFor(entry, index);
  // One path means this entry IS that page, so the page is its own canonical -
  // which also repairs entries whose url field points at a different route.
  // Several paths are aliases of one page, and entry.url names the real one.
  paths.forEach(function (route) {
    if (route === '/') return;                       // the root file is the homepage
    if (seen.has(route)) {
      fail('route ' + route + ' is claimed by two routeSeo entries (#' +
           seen.get(route) + ' and #' + index + ').');
    }
    seen.set(route, index);

    const canonical = paths.length === 1 ? ORIGIN + route : (entry.url || ORIGIN + route);
    const out = render(entry, route, canonical);
    const dest = path.join(BUILD_DIR, route.replace(/^\//, ''), 'index.html');

    if (!DRY_RUN) {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.writeFileSync(dest, out.page, 'utf8');
    }
    written.push({ route: route, canonical: canonical, title: entry.title, content: out.source });
  });
});

/* -------------------------------------------------------------- report ---- */

console.log('');
console.log('  prerender' + (DRY_RUN ? ' (dry run - nothing written)' : '') + ': ' +
            written.length + ' routes from ' + routeSeo.length + ' routeSeo entries');
console.log('');
written.forEach(function (w) {
  const rich = w.content.indexOf('seo-content/') === 0;
  console.log('    ' + (rich ? '+' : ' ') + ' ' + w.route.padEnd(26) + ' ' + w.content);
});
const rich = written.filter(function (w) { return w.content.indexOf('seo-content/') === 0; }).length;
console.log('');
console.log('    ' + rich + ' with full copy from seo-content/, ' +
            (written.length - rich) + ' on the title+description fallback');
console.log('');
