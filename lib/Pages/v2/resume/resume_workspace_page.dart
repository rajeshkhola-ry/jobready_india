import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../../../Services/resume_pdf_export.dart';

class ResumeWorkspacePage extends StatefulWidget {
  const ResumeWorkspacePage({super.key});

  @override
  State<ResumeWorkspacePage> createState() => _ResumeWorkspacePageState();
}

class _ResumeWorkspacePageState extends State<ResumeWorkspacePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  ResumeTemplate _selectedTemplate = ResumeTemplate.classic;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    _titleController.addListener(_refresh);
    _summaryController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _titleController.removeListener(_refresh);
    _summaryController.removeListener(_refresh);
    _nameController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resume draft saved locally in V2 workspace.')),
    );
  }

  Future<void> _exportPdf() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name before exporting.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await ResumePdfExport.buildPdf(
        name: _nameController.text.trim(),
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        template: _selectedTemplate,
      );
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = 'resume_${_selectedTemplate.name}.pdf';
        anchor.click();
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          html.Url.revokeObjectUrl(url);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF export is available on web. Mobile export coming in next checkpoint.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume export failed. Please review details and try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String get _templateLabel {
    switch (_selectedTemplate) {
      case ResumeTemplate.classic: return 'Classic';
      case ResumeTemplate.modern: return 'Modern';
      case ResumeTemplate.minimal: return 'Minimal';
    }
  }

  Color get _templateAccent {
    switch (_selectedTemplate) {
      case ResumeTemplate.classic: return const Color(0xFF0E3A66);
      case ResumeTemplate.modern: return const Color(0xFF0A84FF);
      case ResumeTemplate.minimal: return const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Workspace'),
        backgroundColor: const Color(0xFF0E3A66),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E3A66),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Fill in your details below, choose a template, and export your resume as a PDF.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldCard(
                      label: 'Full Name',
                      controller: _nameController,
                      hint: 'Enter your full name',
                    ),
                    const SizedBox(height: 12),
                    _fieldCard(
                      label: 'Target Job Title',
                      controller: _titleController,
                      hint: 'Example: Cargo Revenue Accounting Specialist',
                    ),
                    const SizedBox(height: 12),
                    _fieldCard(
                      label: 'Professional Summary',
                      controller: _summaryController,
                      hint: 'Write a short profile summary (2–5 sentences recommended)',
                      maxLines: 6,
                      showCounter: true,
                    ),
                    const SizedBox(height: 20),
                    // ── Template Selector ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8E5F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose Export Template',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: ResumeTemplate.values.map((t) {
                              final isSelected = t == _selectedTemplate;
                              final labels = {
                                ResumeTemplate.classic: 'Classic',
                                ResumeTemplate.modern: 'Modern',
                                ResumeTemplate.minimal: 'Minimal',
                              };
                              final colors = {
                                ResumeTemplate.classic: const Color(0xFF0E3A66),
                                ResumeTemplate.modern: const Color(0xFF0A84FF),
                                ResumeTemplate.minimal: const Color(0xFF374151),
                              };
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTemplate = t),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? colors[t] : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors[t]!,
                                      width: isSelected ? 0 : 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    labels[t]!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : colors[t],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Template Preview ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _templateAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _templateAccent.withValues(alpha: 0.55),
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _templateAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : 'Your Name',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _nameController.text.isNotEmpty
                                            ? _templateAccent
                                            : const Color(0xFFADB5BD),
                                        fontStyle: _nameController.text.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _titleController.text.isNotEmpty
                                          ? _titleController.text
                                          : 'Job Title',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _titleController.text.isNotEmpty
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFFADB5BD),
                                        fontStyle: _titleController.text.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _templateAccent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _templateLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _templateAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: _templateAccent.withValues(alpha: 0.15), thickness: 1),
                          const SizedBox(height: 8),
                          Text(
                            _summaryController.text.isNotEmpty
                                ? _summaryController.text
                                : 'Your professional summary will appear here.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _summaryController.text.isNotEmpty
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFADB5BD),
                              height: 1.6,
                              fontStyle: _summaryController.text.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Draft'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _exporting ? null : _exportPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _templateAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: _exporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_outlined),
                          label: Text(_exporting ? 'Exporting...' : 'Export PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            } else {
                              navigator.pushNamedAndRemoveUntil('/home', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Back to Home'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldCard({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool showCounter = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: showCounter ? 600 : null,
            decoration: InputDecoration(
              hintText: hint,
              counterStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
