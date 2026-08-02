import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Pages/convert_tool_page.dart';
import '../Pages/v2/photo/photo_hd_workspace_page.dart';
import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/upload_context_service.dart';

const int _maxUploadBytes = 500 * 1024 * 1024; // 500 MB

class UploadCardV2 extends StatefulWidget {
  const UploadCardV2({super.key});

  @override
  State<UploadCardV2> createState() => _UploadCardV2State();
}

class _UploadCardV2State extends State<UploadCardV2> {
  List<PickedFileData> _selectedFiles = const [];
  bool _dragging = false;

  StreamSubscription<html.MouseEvent>? _webDragOverSub;
  StreamSubscription<html.MouseEvent>? _webDragLeaveSub;
  StreamSubscription<html.MouseEvent>? _webDropSub;

  static const List<String> _allowedExtensions = [
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
    'webp',
    'bmp',
  ];

  @override
  void initState() {
    super.initState();
    _initWebDropHandlers();
  }

  @override
  void dispose() {
    _webDragOverSub?.cancel();
    _webDragLeaveSub?.cancel();
    _webDropSub?.cancel();
    super.dispose();
  }

  void _initWebDropHandlers() {
    if (!kIsWeb) {
      return;
    }

    _webDragOverSub = html.document.onDragOver.listen((event) {
      event.preventDefault();
      if (!mounted) return;
      if (!_dragging) {
        setState(() {
          _dragging = true;
        });
      }
    });

    _webDragLeaveSub = html.document.onDragLeave.listen((event) {
      event.preventDefault();
      if (!mounted) return;
      if (_dragging) {
        setState(() {
          _dragging = false;
        });
      }
    });

    _webDropSub = html.document.onDrop.listen((event) async {
      event.preventDefault();

      if (!mounted) return;

      setState(() {
        _dragging = false;
      });

      final fileList = event.dataTransfer.files;
      if (fileList == null || fileList.isEmpty) {
        return;
      }

      final accepted = <PickedFileData>[];
      for (final file in fileList) {
        final name = file.name;
        if (!_isAllowedFile(name)) {
          continue;
        }

        final bytes = await _readFileBytes(file);
        if (bytes == null) {
          continue;
        }

        if (bytes.length > _maxUploadBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name exceeds 500 MB limit and was skipped.')),
            );
          }
          continue;
        }

        accepted.add(PickedFileData(name: name, size: bytes.length, bytes: bytes));
      }

      if (accepted.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drop valid files only: PDF, Office docs, or images.'),
          ),
        );
        return;
      }

      _applyUploadedFiles(accepted, append: true);
    });
  }

  Future<Uint8List?> _readFileBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();

    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else if (result is Uint8List) {
        completer.complete(result);
      } else if (result is List<int>) {
        completer.complete(Uint8List.fromList(result));
      } else {
        completer.complete(null);
      }
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  bool _isAllowedFile(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) {
      return false;
    }

    final extension = name.substring(dotIndex + 1).toLowerCase();
    return _allowedExtensions.contains(extension);
  }

  bool _isImageFile(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) {
      return false;
    }

    final extension = name.substring(dotIndex + 1).toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(extension);
  }

  String _getMimeType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lowerName.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lowerName.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lowerName.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) return 'image/jpeg';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.bmp')) return 'image/bmp';
    return 'application/octet-stream';
  }

  void _applyUploadedFiles(List<PickedFileData> files, {bool append = false}) {
    if (files.isEmpty) {
      return;
    }

    final merged = append
        ? <PickedFileData>[..._selectedFiles, ...files]
        : List<PickedFileData>.from(files);

    setState(() {
      _selectedFiles = merged;
    });

    UploadContextService.setUploadedFiles(merged);

    // Store files globally for access across tool pages
    for (final file in files) {
      unawaited(
        FileStorageService.storeFile(
          name: file.name,
          bytes: file.bytes,
          mimeType: _getMimeType(file.name),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${merged.length} file(s) ready. Open any tool to continue.'),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePickerService.pickMultipleFileData(
        allowedExtensions: _allowedExtensions,
      );

      if (!mounted) {
        return;
      }

      final report = FilePickerService.lastSelectionReport;
      if (files.isEmpty) {
        final message = report.cancelled
            ? 'File selection cancelled.'
            : (report.hasFilteredFiles
                ? report.buildSummaryMessage()
                : 'No usable files were selected. Please choose supported files and try again.');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }

      _applyUploadedFiles(files);

      if (report.hasFilteredFiles && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.buildSummaryMessage()),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      final isImageSelection = files.any((file) => _isImageFile(file.name));
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isImageSelection
              ? const PhotoHdWorkspacePage()
              : const ConvertToolPage(),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed to start. Please check browser permissions and try again.'),
          backgroundColor: Colors.red,
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    size: 36,
                    color: Color(0xFF1F4E79),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upload your document',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Drag & Drop your file(s) here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 220,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text(
                      'Browse Files',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (kIsWeb) ...[
                  Container(
                    width: double.infinity,
                    height: 96,
                    decoration: BoxDecoration(
                      color: _dragging ? const Color(0xFFF2F7FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _dragging ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _dragging ? 'Release to upload' : 'Drop files here',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Supported: PDF • DOCX • XLSX • PPT • JPG • PNG • WEBP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Multiple file upload supported',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E3A66),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap the card or use the button above to browse your files instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Maximum file size: 100 MB',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_selectedFiles.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FFF9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB7F1C7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedFiles.length} file(s) selected',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
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
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._selectedFiles.take(4).toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file_rounded,
                                  size: 16,
                                  color: const Color(0xFF059669),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF065F46),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatBytes(file.size),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final newFiles = <PickedFileData>[];
                                      for (int i = 0; i < _selectedFiles.length; i++) {
                                        if (i != index) {
                                          newFiles.add(_selectedFiles[i]);
                                        }
                                      }
                                      _selectedFiles = newFiles;
                                    });
                                    if (_selectedFiles.isEmpty) {
                                      UploadContextService.clearUploadedFiles();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_selectedFiles.length > 4)
                          Text(
                            '+${_selectedFiles.length - 4} more file(s)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
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
