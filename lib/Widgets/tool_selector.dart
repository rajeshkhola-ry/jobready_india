import 'package:flutter/material.dart';
import 'apple_button.dart';
import '../Pages/compression_tool_page.dart';
import '../Pages/convert_tool_page.dart';
import '../Pages/merge_tool_page.dart';
import '../Pages/split_tool_page.dart';
import '../Pages/extract_tool_page.dart';

class ToolSelector extends StatelessWidget {
  const ToolSelector({super.key});

  void _navigateToTool(BuildContext context, String toolName, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = constraints.maxWidth >= 900 ? 1.15 : 0.95;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose a Tool",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: aspectRatio,
              children: [
                AppleIconButton(
                  icon: Icons.compress,
                  label: "Compress",
                  onPressed: () => _navigateToTool(
                    context,
                    "Compress",
                    const CompressionToolPage(),
                  ),
                  color: Colors.teal,
                ),
                AppleIconButton(
                  icon: Icons.swap_horiz,
                  label: "Convert",
                  onPressed: () => _navigateToTool(
                    context,
                    "Convert",
                    const ConvertToolPage(),
                  ),
                  color: const Color(0xFF0051BA),
                ),
                AppleIconButton(
                  icon: Icons.merge_type,
                  label: "Merge",
                  onPressed: () => _navigateToTool(
                    context,
                    "Merge",
                    const MergeToolPage(),
                  ),
                  color: Colors.green,
                ),
                AppleIconButton(
                  icon: Icons.content_cut,
                  label: "Split",
                  onPressed: () => _navigateToTool(
                    context,
                    "Split",
                    const SplitToolPage(),
                  ),
                  color: Colors.purple,
                ),
                AppleIconButton(
                  icon: Icons.description,
                  label: "Extract",
                  onPressed: () => _navigateToTool(
                    context,
                    "Extract",
                    const ExtractToolPage(),
                  ),
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
