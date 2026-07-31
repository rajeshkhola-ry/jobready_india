import 'package:flutter/material.dart';
import '../Pages/compression_tool_page.dart';
import '../Pages/convert_tool_page.dart';
import '../Pages/merge_tool_page.dart';
import '../Pages/split_tool_page.dart';
import '../Pages/extract_tool_page.dart';
import '../Pages/pdf_tools_page.dart';
import '../Pages/pdf_edit_page.dart';
import '../Pages/ai_resume_builder_page.dart';
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
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183A5B).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                ? 1.8
                : width >= 680
                    ? 1.9
                    : 2.1;

            final tools = <Widget>[
              _tool(
                context,
                Icons.picture_as_pdf,
                "Compress",
                "Tries to match your target size; some files may stay above target.",
                () => _openTool(context, const CompressionToolPage()),
              ),
              _tool(
                context,
                Icons.swap_horiz,
                "Convert",
                "Convert PDF, DOCX, images, and office files.",
                () => _openTool(context, const ConvertToolPage()),
              ),
              _tool(
                context,
                Icons.merge_type,
                "Merge",
                "Combine multiple PDFs into one file.",
                () => _openTool(context, const MergeToolPage()),
              ),
              _tool(
                context,
                Icons.content_cut,
                "Split",
                "Split one PDF into selected page ranges.",
                () => _openTool(context, const SplitToolPage()),
              ),
              _tool(
                context,
                Icons.description,
                "Extract",
                "Extract text and content from PDF pages.",
                () => _openTool(context, const ExtractToolPage()),
              ),
              _tool(
                context,
                Icons.edit_document,
                "Edit PDF",
                "Edit PDF, then save and download.",
                () => _openTool(context, const PdfEditPage()),
              ),
              _tool(
                context,
                Icons.dashboard_customize_rounded,
                "PDF Tools",
                "Open complete PDF utility workspace.",
                () => _openTool(context, const PdfToolsPage()),
              ),
              _tool(
                context,
                Icons.smart_toy_rounded,
                "AI Resume Builder",
                "Create and tailor professional resumes directly from the main tools list.",
                () => _openTool(context, const AiResumeBuilderPage()),
              ),
              _tool(
                context,
                Icons.camera_alt_rounded,
                "HD Photo Studio",
                "Enhance, edit, upscale photos and remove backgrounds in HD.",
                () => _openTool(context, const PhotoHdWorkspacePage()),
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "✨ AI Premium Features",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Professional AI-powered tools for document optimization",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
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
    };

    final accent = colorMap[title] ?? const Color(0xFF1F4E79);

    return InkWell(
      borderRadius: BorderRadius.circular(16),

      onTap: onTap,

      child: Container(
        height: 92,

        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF183A5B).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),

        child: Row(
          children: [

            CircleAvatar(
              radius: 14,

              backgroundColor:
                  accent.withValues(alpha: 0.13),

              child: Icon(
                icon,
                size: 15,
                color: accent,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: accent.withValues(alpha: 0.85),
            ),

          ],
        ),
      ),
    );
  }
}
