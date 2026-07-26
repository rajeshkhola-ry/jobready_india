import 'package:flutter/material.dart';
import 'apple_button.dart';
import '../Services/file_picker_service.dart';
import '../Services/upload_context_service.dart';

class UploadCard extends StatefulWidget {
  final VoidCallback? onChooseFile;

  const UploadCard({super.key, this.onChooseFile});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  List<PickedFileData> _selectedFiles = const [];

  Future<void> _defaultChooseFile(BuildContext context) async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'jpg',
          'jpeg',
          'png',
        ],
      );

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File selection cancelled.')),
        );
        return;
      }

      UploadContextService.setUploadedFiles(files);

      if (!mounted) return;

      setState(() {
        _selectedFiles = files;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${files.length} file(s) uploaded. Open any tool to continue.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to pick file: $e')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_rounded,
            size: 48,
            color: Color(0xFFFFCC00),
          ),
          const SizedBox(height: 8),
          const Text(
            "Drag & Drop your document here",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "PDF • Word • Excel • PowerPoint • Images",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Multiple file upload supported - select one or many files at once.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFE9A6),
            ),
          ),
          const SizedBox(height: 14),
          if (_selectedFiles.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedFiles.length} file(s) uploaded',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFiles = [];
                          });
                          UploadContextService.clearUploadedFiles();
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B6B),
                          side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._selectedFiles.take(4).toList().asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, size: 16, color: Color(0xFFFFCC00)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatBytes(entry.value.size),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFiles.removeAt(entry.key);
                              });
                              if (_selectedFiles.isEmpty) {
                                UploadContextService.clearUploadedFiles();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedFiles.length > 4)
                    Text(
                      '+${_selectedFiles.length - 4} more file(s)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppleButton(
            label: _selectedFiles.isEmpty ? "Choose Files" : "Change Files",
            icon: Icons.upload_file,
            onPressed: widget.onChooseFile ?? () => _defaultChooseFile(context),
            isPrimary: true,
            isFullWidth: true,
            height: 44,
            backgroundColor: const Color(0xFFFFCC00),
            foregroundColor: const Color(0xFF0051BA),
          ),
        ],
      ),
    );
  }
}
