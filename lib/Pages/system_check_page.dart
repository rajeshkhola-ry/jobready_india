import 'package:flutter/material.dart';

import 'compression_tool_page.dart' deferred as compression_page;
import 'convert_tool_page.dart' deferred as convert_page;
import 'extract_tool_page.dart' deferred as extract_page;
import 'merge_tool_page.dart' deferred as merge_page;
import 'pdf_tools_page.dart' deferred as pdf_page;
import 'split_tool_page.dart' deferred as split_page;

class SystemCheckPage extends StatelessWidget {
  const SystemCheckPage({super.key});

  void _openTool(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openCompression(BuildContext context) async {
    await compression_page.loadLibrary();
    _openTool(context, compression_page.CompressionToolPage());
  }

  Future<void> _openConvert(BuildContext context) async {
    await convert_page.loadLibrary();
    _openTool(context, convert_page.ConvertToolPage());
  }

  Future<void> _openMerge(BuildContext context) async {
    await merge_page.loadLibrary();
    _openTool(context, merge_page.MergeToolPage());
  }

  Future<void> _openSplit(BuildContext context) async {
    await split_page.loadLibrary();
    _openTool(context, split_page.SplitToolPage());
  }

  Future<void> _openExtract(BuildContext context) async {
    await extract_page.loadLibrary();
    _openTool(context, extract_page.ExtractToolPage());
  }

  Future<void> _openPdf(BuildContext context) async {
    await pdf_page.loadLibrary();
    _openTool(context, pdf_page.PdfToolsPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        title: const Text(
          'System Check',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Text(
              'Use these checks one by one to validate the active V1 merged build paths.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick V1 Checks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1. Convert: PDF to JPG/PNG exports page-by-page ZIP.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '2. Convert: multiple images to PDF produces one combined PDF.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '3. Convert: Word (.docx) to PDF uses structured page output.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '4. Compress / Merge / Split / Extract: quota gate dialog appears when daily limit is reached.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '5. Extract: Tables / Forms option returns column-separated text output.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '6. PDF Edit: Load Text, Run OCR, and Tables buttons all return text.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '7. Home V1: Daily Usage, Recent Documents, Account/Privacy sections visible.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(height: 4),
                Text(
                  '8. File upload: files above 500 MB are skipped with a clear message.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _toolButton(
            context: context,
            title: '1) Compression Tool',
            subtitle: 'Upload file and run compression flow.',
            icon: Icons.compress,
            color: Colors.teal,
            onTap: () => _openCompression(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '2) Convert Tool',
            subtitle: 'Run format conversion path.',
            icon: Icons.swap_horiz,
            color: const Color(0xFF0051BA),
            onTap: () => _openConvert(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '3) Merge Tool',
            subtitle: 'Add multiple files and merge.',
            icon: Icons.merge_type,
            color: Colors.green,
            onTap: () => _openMerge(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '4) Split Tool',
            subtitle: 'Check page split modes.',
            icon: Icons.content_cut,
            color: Colors.purple,
            onTap: () => _openSplit(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '5) Extract Tool',
            subtitle: 'Check extraction workflow.',
            icon: Icons.description,
            color: Colors.orange,
            onTap: () => _openExtract(context),
          ),
          const SizedBox(height: 10),
          _toolButton(
            context: context,
            title: '6) PDF Toolkit',
            subtitle: 'Validate PDF-specific flows.',
            icon: Icons.picture_as_pdf,
            color: Colors.red,
            onTap: () => _openPdf(context),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return ElevatedButton(
      onPressed: () {
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    );
  }
}
