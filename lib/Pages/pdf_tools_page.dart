import 'package:flutter/material.dart';

import 'extract_tool_page.dart';
import 'compression_tool_page.dart';
import 'convert_tool_page.dart';
import 'merge_tool_page.dart';
import 'pdf_edit_page.dart';
import 'split_tool_page.dart';
import '../Widgets/pdf_tool_card.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/tool_guidance_panel.dart';
import '../Services/public_brand_config.dart';
import '../Services/upload_context_service.dart';

/// PDF Tools Page - Central navigation hub for all PDF-related tools
/// Displays all available PDF tools organized into logical groups
class PdfToolsPage extends StatefulWidget {
  const PdfToolsPage({super.key});

  @override
  State<PdfToolsPage> createState() => _PdfToolsPageState();
}

class _PdfToolsPageState extends State<PdfToolsPage> {
  bool _hasPdfLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkUploadedFiles();
  }

  void _checkUploadedFiles() {
    final files = UploadContextService.getCompatibleFiles(['pdf']);
    setState(() {
      _hasPdfLoaded = files.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'PDF Tools',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Production header
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFF1F2937),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PDF Tools',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Convert, merge, split, compress, and extract',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Support: ${PublicBrandConfig.supportEmail}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // File status indicator
                  if (_hasPdfLoaded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF166534)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF166534),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PDF file ready to process',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_hasPdfLoaded) const SizedBox(height: 24),

                  // Basic Operations section
                  Text(
                    'Basic Operations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  PdfToolCard(
                    icon: Icons.merge_type_rounded,
                    title: 'Merge PDF',
                    subtitle: 'Combine multiple PDFs into one',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MergeToolPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  PdfToolCard(
                    icon: Icons.content_cut_rounded,
                    title: 'Split PDF',
                    subtitle: 'Extract pages from a PDF',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SplitToolPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  PdfToolCard(
                    icon: Icons.file_download_rounded,
                    title: 'Extract from PDF',
                    subtitle: 'Extract text, images, or pages',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ExtractToolPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Conversion & Optimization section
                  Text(
                    'Conversion & Optimization',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  PdfToolCard(
                    icon: Icons.compress_rounded,
                    title: 'Compress PDF',
                    subtitle: 'Reduce file size while maintaining quality',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CompressionToolPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  PdfToolCard(
                    icon: Icons.article_rounded,
                    title: 'PDF to Word',
                    subtitle: 'Convert PDFs to editable Word documents',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConvertToolPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Advanced Tools section
                  Text(
                    'Advanced Tools',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  PdfToolCard(
                    icon: Icons.edit_note_rounded,
                    title: 'PDF Edit & OCR',
                    subtitle: 'Edit PDFs and extract text from scans',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PdfEditPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Footer info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD8E5F5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF1F2937),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All tools process files securely. No data is retained after processing.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const ToolGuidancePanel(
                    title: 'About PDF Tools',
                    summary: 'This hub groups the main PDF workflows available in GETREADYJOB so users can choose the right operation quickly.',
                    supportedFormats: ['PDF for merge, split, compress, extract, and edit workflows'],
                    howToUse: ['Choose the task you want to perform.', 'Open the matching tool page.', 'Upload your file and complete the guided steps.'],
                    faqs: ['Where should I start? Choose the task that matches your goal.', 'Can one page do everything? No, each workflow has its own dedicated page.'],
                    tips: ['Use merge for combining files.', 'Use split for page range extraction.', 'Use edit and OCR for text-focused workflows.'],
                  ),
                  const SizedBox(height: 16),
                  const ProductionFooter(compact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
