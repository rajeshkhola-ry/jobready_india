import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../Widgets/apple_button.dart';
import '../Widgets/download_result_dialog.dart';
import '../Widgets/quota_gate.dart';
import '../Widgets/site_footer_link.dart';
import '../Services/file_picker_service.dart';
import '../Services/pdf_merge_service.dart';
import '../Services/upload_context_service.dart';

/// Merge Tool Page - Combine multiple PDFs into one
/// User selects multiple files → Sets merge order → Merges
class MergeToolPage extends StatefulWidget {
  const MergeToolPage({super.key});

  @override
  State<MergeToolPage> createState() => _MergeToolPageState();
}

class _MergeToolPageState extends State<MergeToolPage> {
  final PdfMergeService _mergeService = const PdfMergeService();
  List<String> _selectedFiles = [];
  List<Uint8List> _selectedFileBytes = [];
  List<int> _selectedFileSizes = [];
  bool _isMerging = false;
  String _statusMessage = 'Ready to merge';

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _hydrateFromHomeUpload() {
    if (kIsWeb) {
      return;
    }

    final files = UploadContextService.getCompatibleFiles(['pdf']);
    if (files.isEmpty) {
      return;
    }

    _selectedFiles = files.map((f) => f.name).toList();
    _selectedFileBytes = files.map((f) => f.bytes).toList();
    _selectedFileSizes = files.map((f) => f.size).toList();
    _statusMessage = '✓ ${files.length} PDF file(s) loaded from Home upload';
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
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Color(0xFFFFC72C)),
          ),
        ],
        title: const Text(
          'Merge PDFs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safeWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final safeHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Step 1: Select Files
            _buildStepCard(
              step: 1,
              title: 'Choose Files',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppleButton(
                    label: 'Choose Files',
                    icon: Icons.add_circle,
                    onPressed: _selectFiles,
                    isPrimary: _selectedFiles.isEmpty,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedFiles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.description,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No files selected',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildFileList(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: Merge Order
            if (_selectedFiles.isNotEmpty)
              _buildStepCard(
                step: 2,
                title: 'Merge Order',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drag to reorder files (top to bottom)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrderList(),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Step 3: Merge
            if (_selectedFiles.isNotEmpty)
              _buildStepCard(
                step: 3,
                title: 'Merge Files',
                content: AppleButton(
                  label: _isMerging ? 'Merging...' : 'Start Merge',
                  icon: _isMerging ? Icons.hourglass_empty : Icons.merge_type,
                  onPressed: _isMerging ? null : _startMerge,
                  isPrimary: true,
                  isFullWidth: true,
                ),
              ),
            const SizedBox(height: 20),

            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor()),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(),
                ),
              ),
            ),
            if (_isMerging) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.35)),
                ),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Merge is running... please wait.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const SiteFooterLink(),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0051BA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(
              Icons.description,
              color: Colors.grey.shade600,
            ),
            title: Text(
              _selectedFiles[index],
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              _formatBytes(_selectedFileSizes[index]),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFiles.removeAt(index);
                  _selectedFileBytes.removeAt(index);
                  _selectedFileSizes.removeAt(index);
                });
              },
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          return ListTile(
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
            title: Text(
              _selectedFiles[index],
              style: const TextStyle(fontSize: 13),
            ),
            trailing: const Icon(
              Icons.drag_handle,
              color: Colors.grey,
              size: 20,
            ),
          );
        },
      ),
    );
  }

  void _selectFiles() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: ['pdf'],
      );

      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles = files.map((f) => f.name).toList();
          _selectedFileBytes = files.map((f) => f.bytes).toList();
          _selectedFileSizes = files.map((f) => f.size).toList();
          _statusMessage = '✓ ${files.length} files selected';
        });
      } else {
        setState(() {
          _statusMessage = 'File selection cancelled';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startMerge() async {
    if (_selectedFiles.isEmpty) return;

    final allowed = await checkQuotaAndProceed(
      context: context,
      actionBucket: 'merge',
    );
    if (!allowed) return;

    setState(() {
      _isMerging = true;
      _statusMessage = 'Merging ${_selectedFiles.length} files...';
    });

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final pickedFiles = [
        for (var index = 0; index < _selectedFiles.length; index++)
          PickedFileData(
            name: _selectedFiles[index],
            size: _selectedFileSizes[index],
            bytes: _selectedFileBytes[index],
          ),
      ];

      final mergedPdf = await _mergeService.mergePdfs(pickedFiles);

      if (!mounted) return;

      setState(() {
        _isMerging = false;
        _statusMessage = '✓ Merge completed successfully';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merge completed. Download link is ready.'),
          backgroundColor: Colors.green,
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Merged PDF Completed',
          fileName: 'jobready_merged.pdf',
          outputBytes: mergedPdf,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMerging = false;
        _statusMessage = '✗ Merge failed: $e';
      });
    }
  }

  Color _getStatusColor() {
    if (_statusMessage.startsWith('✓')) return Colors.green;
    if (_statusMessage.startsWith('✗')) return Colors.red;
    if (_statusMessage.startsWith('Merging')) return Colors.blue;
    return Colors.grey;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
