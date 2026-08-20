import 'package:flutter/material.dart';

import '../Pages/ai_resume_builder_page.dart';
import '../Pages/compression_tool_page.dart';
import '../Pages/convert_tool_page.dart';
import '../Pages/csv_to_excel_page.dart';
import '../Pages/fraud_seal_page.dart';
import '../Pages/govt_verifier_page.dart';
import '../Pages/merge_tool_page.dart';
import '../Pages/pdf_edit_page.dart';
import '../Pages/privacy_masker_page.dart';
import '../Pages/split_tool_page.dart';

/// Single canonical source of truth for the homepage's tool cards - replaces
/// the old `_MostPopularToolsCard`/`_PopularToolRow` and `ToolSelectorV2`
/// widgets, which together showed several of the same tools 2-3 times under
/// slightly different names (e.g. "Edit PDF" appeared 3 times; "AI Resume
/// Builder", "HD Photo Studio", "Micro-Canva", and "Poster Studio" each
/// appeared twice). Every tool below appears exactly once, grouped into the
/// 3 requested category boxes.
class HomepageToolCategories extends StatelessWidget {
  const HomepageToolCategories({super.key});

  static const _pdfAccent = Color(0xFF1F4E79);
  static const _utilityAccent = Color(0xFF0F766E);
  static const _careerAccent = Color(0xFF7C3AED);

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryBox(
          title: 'PDF Power Tools',
          subtitle: 'The most-used PDF workflows, one tap away',
          headerIcon: Icons.picture_as_pdf_rounded,
          accent: _pdfAccent,
          highlight: true,
          tools: [
            _ToolTile(
              icon: Icons.edit_document,
              label: 'Edit PDF',
              description: 'Inline MS Word-style PDF editor',
              accent: _pdfAccent,
              onTap: () => _openPage(context, const PdfEditPage()),
            ),
            _ToolTile(
              icon: Icons.description_outlined,
              label: 'PDF to Word',
              description: 'Side-by-side verification & inline edit',
              accent: _pdfAccent,
              onTap: () => _openPage(
                context,
                const ConvertToolPage(initialInputFormat: 'PDF', initialOutputFormat: 'Word (.docx)'),
              ),
            ),
            _ToolTile(
              icon: Icons.compress_rounded,
              label: 'Compress PDF',
              description: 'Reduce file size, keep quality',
              accent: _pdfAccent,
              onTap: () => _openPage(context, const CompressionToolPage()),
            ),
            _ToolTile(
              icon: Icons.merge_type_rounded,
              label: 'Merge PDF',
              description: 'Combine files into one document',
              accent: _pdfAccent,
              onTap: () => _openPage(context, const MergeToolPage()),
            ),
            _ToolTile(
              icon: Icons.call_split_rounded,
              label: 'Split PDF',
              description: 'Break a PDF into separate pages',
              accent: _pdfAccent,
              onTap: () => _openPage(context, const SplitToolPage()),
            ),
            _ToolTile(
              icon: Icons.lock_outline_rounded,
              label: 'Protect / Unlock PDF',
              description: 'Password-protect or remove access limits',
              accent: _pdfAccent,
              onTap: () => Navigator.of(context).pushNamed('/smart-pdf'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CategoryBox(
          title: 'Conversion & Utility Studio',
          subtitle: 'Everyday converters and document-safety tools',
          headerIcon: Icons.swap_horiz_rounded,
          accent: _utilityAccent,
          tools: [
            _ToolTile(
              icon: Icons.image_outlined,
              label: 'JPG to PDF',
              description: 'Turn images into a clean PDF',
              accent: _utilityAccent,
              onTap: () => _openPage(
                context,
                const ConvertToolPage(initialInputFormat: 'Image', initialOutputFormat: 'PDF (.pdf)'),
              ),
            ),
            _ToolTile(
              icon: Icons.photo_library_outlined,
              label: 'PDF to JPG',
              description: 'Export PDF pages as images',
              accent: _utilityAccent,
              onTap: () => _openPage(
                context,
                const ConvertToolPage(initialInputFormat: 'PDF', initialOutputFormat: 'JPG Images'),
              ),
            ),
            _ToolTile(
              icon: Icons.grid_on_rounded,
              label: 'CSV / Excel Converter',
              description: 'Convert CSV data into Excel (.xlsx)',
              accent: _utilityAccent,
              onTap: () => _openPage(context, const CsvToExcelPage()),
            ),
            _ToolTile(
              icon: Icons.shield_rounded,
              label: 'Privacy Masker',
              description: 'Redact Aadhaar/PAN and sensitive data',
              accent: _utilityAccent,
              onTap: () => _openPage(context, const PrivacyMaskerPage()),
            ),
            _ToolTile(
              icon: Icons.verified_rounded,
              label: 'Fraud Seal',
              description: 'Tamper-proof authenticity watermark',
              accent: _utilityAccent,
              onTap: () => _openPage(context, const FraudSealPage()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CategoryBox(
          title: 'AI Career & Govt Documents',
          subtitle: 'Resume, exam-form, and photo essentials',
          headerIcon: Icons.auto_awesome_rounded,
          accent: _careerAccent,
          tools: [
            _ToolTile(
              icon: Icons.auto_awesome_rounded,
              label: 'AI Resume Builder',
              description: 'ATS-ready resumes, AI-guided',
              accent: _careerAccent,
              onTap: () => _openPage(context, const AiResumeBuilderPage()),
            ),
            _ToolTile(
              icon: Icons.badge_rounded,
              label: 'Govt Form / PCC Resizer',
              description: 'Exact-KB photo & signature resizer',
              accent: _careerAccent,
              onTap: () => _openPage(context, const GovtVerifierPage()),
            ),
            _ToolTile(
              icon: Icons.camera_alt_rounded,
              label: 'HD Photo Studio',
              description: 'Enhance photos, remove backgrounds',
              accent: _careerAccent,
              onTap: () => Navigator.of(context).pushNamed('/photo-hd'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBox extends StatelessWidget {
  const _CategoryBox({
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.accent,
    required this.tools,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Color accent;
  final List<Widget> tools;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlight ? accent.withValues(alpha: 0.45) : const Color(0xFFD8E4F2),
          width: highlight ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: accent.withValues(alpha: 0.14), child: Icon(headerIcon, color: accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        if (highlight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                            child: Text('MOST USED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: accent)),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: tools),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 192,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 16, backgroundColor: accent.withValues(alpha: 0.13), child: Icon(icon, color: accent, size: 16)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 11, color: accent.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.25, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
