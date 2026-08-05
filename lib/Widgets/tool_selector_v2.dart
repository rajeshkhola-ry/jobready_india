import 'package:flutter/material.dart';
import '../Pages/compression_tool_page.dart';
import '../Pages/convert_tool_page.dart';
import '../Pages/merge_tool_page.dart';
import '../Pages/split_tool_page.dart';
import '../Pages/extract_tool_page.dart';
import '../Pages/pdf_tools_page.dart';
import '../Pages/pdf_edit_page.dart';
import '../Pages/ai_resume_builder_page.dart';
import '../Pages/micro_canva_utilities_page.dart';
import '../Pages/poster_banner_studio_page.dart';
import '../Pages/resume_document_canvas_templates_page.dart';
import '../Pages/v2/photo/photo_hd_workspace_page.dart';

class ToolSelectorV2 extends StatelessWidget {
  const ToolSelectorV2({super.key});

  void _openTool(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E4F2), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 980
                ? 3
                : width >= 680
                    ? 2
                    : 1;
            final childAspectRatio = width >= 980
              ? 3.2
                : width >= 680
                ? 2.9
                : 2.45;

            final tools = <Widget>[
              _tool(
                context,
                Icons.picture_as_pdf,
                "Compress",
                "Tries to match your target size; some files may stay above target.",
                false,
                () => _openTool(context, const CompressionToolPage()),
              ),
              _tool(
                context,
                Icons.swap_horiz,
                "Convert",
                "Convert PDF, DOCX, images, and office files.",
                false,
                () => _openTool(context, const ConvertToolPage()),
              ),
              _tool(
                context,
                Icons.merge_type,
                "Merge",
                "Combine multiple PDFs into one file.",
                false,
                () => _openTool(context, const MergeToolPage()),
              ),
              _tool(
                context,
                Icons.content_cut,
                "Split",
                "Split one PDF into selected page ranges.",
                false,
                () => _openTool(context, const SplitToolPage()),
              ),
              _tool(
                context,
                Icons.description,
                "Extract",
                "Extract text and content from PDF pages.",
                false,
                () => _openTool(context, const ExtractToolPage()),
              ),
              _tool(
                context,
                Icons.edit_document,
                "Edit PDF",
                "Edit PDF, then save and download.",
                false,
                () => _openTool(context, const PdfEditPage()),
              ),
              _tool(
                context,
                Icons.dashboard_customize_rounded,
                "PDF Tools",
                "Open complete PDF utility workspace.",
                false,
                () => _openTool(context, const PdfToolsPage()),
              ),
              _tool(
                context,
                Icons.smart_toy_rounded,
                "AI Resume Builder",
                "Create and tailor professional resumes directly from the main tools list.",
                true,
                () => _openTool(context, const AiResumeBuilderPage()),
              ),
              _tool(
                context,
                Icons.camera_alt_rounded,
                "HD Photo Studio",
                "Enhance, edit, upscale photos and remove backgrounds in HD.",
                true,
                () => _openTool(context, const PhotoHdWorkspacePage()),
              ),
              _tool(
                context,
                Icons.auto_awesome_motion_rounded,
                "Micro-Canva",
                "Background remover, passport resize, upscale, PNG to SVG.",
                true,
                () => _openTool(context, const MicroCanvaUtilitiesPage()),
              ),
              _tool(
                context,
                Icons.draw_rounded,
                "Resume Canvas",
                "Template canvas for resumes, cover letters, and SOP drafts.",
                true,
                () => _openTool(context, const ResumeDocumentCanvasTemplatesPage()),
              ),
              _tool(
                context,
                Icons.campaign_rounded,
                "Poster Studio",
                "Canvas-based poster, banner, flyer, and local print export workspace.",
                true,
                () => _openTool(context, const PosterBannerStudioPage()),
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "AI Premium Features",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Professional AI-powered workspace for document optimization",
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                  children: tools,
                ),
                const SizedBox(height: 4),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tool(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool isFeatured,
    VoidCallback onTap,
  ) {
    final colorMap = <String, Color>{
      'Compress': const Color(0xFF0E3A66),
      'Convert': const Color(0xFF1F4E79),
      'Merge': const Color(0xFF0F766E),
      'Split': const Color(0xFFB45309),
      'Extract': const Color(0xFFBE123C),
      'Edit PDF': const Color(0xFF0E3A66),
      'PDF Tools': const Color(0xFF1F4E79),
      'HD Photo Studio': const Color(0xFF7C3AED),
      'Micro-Canva': const Color(0xFF0F766E),
      'Resume Canvas': const Color(0xFF0B5C4A),
      'Poster Studio': const Color(0xFF8A1538),
    };

    final accent = colorMap[title] ?? const Color(0xFF1F4E79);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, 0, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FCFF)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isFeatured ? accent.withValues(alpha: 0.55) : const Color(0xFFD9E5F2),
                width: isFeatured ? 1.8 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFeatured ? accent.withValues(alpha: 0.16) : const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: isFeatured ? 18 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: accent.withValues(alpha: 0.13),
                      child: Icon(
                        icon,
                        size: 13,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Featured',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    if (!isFeatured)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: accent.withValues(alpha: 0.85),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.6,
                    height: 1.2,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
