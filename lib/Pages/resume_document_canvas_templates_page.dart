import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/resume_document_canvas_service.dart';

class ResumeDocumentCanvasTemplatesPage extends StatefulWidget {
  const ResumeDocumentCanvasTemplatesPage({super.key});

  @override
  State<ResumeDocumentCanvasTemplatesPage> createState() => _ResumeDocumentCanvasTemplatesPageState();
}

class _ResumeDocumentCanvasTemplatesPageState extends State<ResumeDocumentCanvasTemplatesPage> {
  bool _busy = false;
  CanvasTemplate? _selected;

  void _downloadBytes(String fileName, Uint8List bytes, {String mime = 'application/octet-stream'}) {
    final blob = html.Blob(<dynamic>[bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  void _downloadText(String fileName, String content, {String mime = 'text/plain;charset=utf-8'}) {
    _downloadBytes(fileName, Uint8List.fromList(utf8.encode(content)), mime: mime);
  }

  Future<void> _exportPdf(CanvasTemplate template) async {
    setState(() => _busy = true);
    try {
      final bytes = await ResumeDocumentCanvasService.buildTemplatePreviewPdf(template);
      _downloadBytes('${template.id}_preview.pdf', bytes, mime: 'application/pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${template.title} PDF preview.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _exportJson(CanvasTemplate template) {
    final jsonText = ResumeDocumentCanvasService.buildTemplateJson(template);
    _downloadText('${template.id}.json', jsonText, mime: 'application/json;charset=utf-8');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded ${template.title} JSON template.')),
    );
  }

  void _exportMarkdown(CanvasTemplate template) {
    final md = ResumeDocumentCanvasService.buildTemplateMarkdown(template);
    _downloadText('${template.id}.md', md, mime: 'text/markdown;charset=utf-8');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded ${template.title} markdown template.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ResumeDocumentCanvasService.templates;
    final selected = _selected ?? templates.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume & Document Canvas Templates'),
        backgroundColor: const Color(0xFF0D3B66),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFF3F7FC), Color(0xFFEAF2FB), Color(0xFFF8FBFF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      children: <Widget>[
                        Expanded(flex: 6, child: _buildTemplateGrid(templates)),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: _buildPreviewPanel(selected)),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        Expanded(flex: 6, child: _buildTemplateGrid(templates)),
                        const SizedBox(height: 12),
                        Expanded(flex: 5, child: _buildPreviewPanel(selected)),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTemplateGrid(List<CanvasTemplate> templates) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Template Catalog',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0A2F54)),
            ),
            const SizedBox(height: 6),
            const Text('Local-first editable templates for resumes and supporting documents.'),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: templates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  final active = _selected?.id == t.id || (_selected == null && index == 0);

                  return InkWell(
                    onTap: () => setState(() => _selected = t),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: active ? const Color(0xFF0D3B66) : const Color(0xFFD6E2F0), width: active ? 2 : 1),
                        color: active ? const Color(0xFFEAF2FF) : Colors.white,
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: const Color(0xFF0D3B66).withOpacity(0.08), blurRadius: 9, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0A2F54)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D3B66).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(t.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              t.description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(CanvasTemplate selected) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              selected.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0A2F54)),
            ),
            const SizedBox(height: 8),
            Text(selected.description, style: const TextStyle(fontSize: 13.5, height: 1.35)),
            const SizedBox(height: 14),
            const Text('Sections', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected.sections
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      backgroundColor: const Color(0xFFE9F1FB),
                      side: const BorderSide(color: Color(0xFFBDD3EA)),
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _exportPdf(selected),
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _exportJson(selected),
                    icon: const Icon(Icons.data_object),
                    label: const Text('Export JSON'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _exportMarkdown(selected),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Export Markdown'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
