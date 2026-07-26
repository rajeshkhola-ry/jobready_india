import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../Widgets/upload_card.dart';
import '../Widgets/tool_selector.dart';
import '../Widgets/offer_card.dart';
import '../Widgets/pricing_card.dart';
import '../Widgets/why_choose_card.dart';
import '../Widgets/glowing_logo_badge.dart';
import 'compression_benchmark_page.dart';
import 'launch_readiness_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'pptx', 'csv', 'txt'],
        type: FileType.custom,
      );

      if (result != null && result.files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: ${result.files.first.name}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Launch Readiness',
            icon: const Icon(Icons.rocket_launch_outlined, color: Color(0xFFFFC72C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LaunchReadinessPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Benchmark',
            icon: const Icon(Icons.analytics_outlined, color: Color(0xFFFFC72C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CompressionBenchmarkPage(),
                ),
              );
            },
          ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // G Logo
            const GlowingLogoBadge(size: 36, circular: false),
            const SizedBox(width: 12),
            const Text(
              "GETREADYJOB",
              style: TextStyle(
              color: Color(0xFFFFCC00),
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "🚀 What would you like to do today?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Upload your document once and choose any tool instantly.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF92400E),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Works on major browsers (Chrome, Edge, Firefox, Safari). For best results, use latest Chrome or Edge.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF78350F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            UploadCard(onChooseFile: _selectFile),

            const SizedBox(height: 16),

            const ToolSelector(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
