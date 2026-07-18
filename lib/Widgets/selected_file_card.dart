import 'dart:typed_data';

import 'package:flutter/material.dart';

// ignore_for_file: use_build_context_synchronously

import '../Services/compression_service.dart';
import '../Services/conversion_service.dart';
import 'choose_output_dialog.dart';
import 'compression_target_dialog.dart';
import 'download_result_dialog.dart';

class SelectedFileCard extends StatefulWidget {
  final String fileName;
  final String fileSize;
  final Uint8List fileBytes;

  const SelectedFileCard({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
  });

  @override
  State<SelectedFileCard> createState() => _SelectedFileCardState();
}

class _SelectedFileCardState extends State<SelectedFileCard> {
  bool get _isPdf => widget.fileName.toLowerCase().endsWith('.pdf');
  bool get _isImage => widget.fileName.toLowerCase().endsWith('.png') ||
      widget.fileName.toLowerCase().endsWith('.jpg') ||
      widget.fileName.toLowerCase().endsWith('.jpeg');

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 34,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Size : ${widget.fileSize}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Selected for Conversion',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (!mounted) return;
                    final initialContext = context;
                    final selectedFormat = await showDialog<String>(
                      context: initialContext,
                      builder: (_) => const ChooseOutputDialog(),
                    );

                    if (!mounted || selectedFormat == null) {
                      return;
                    }

                    if (selectedFormat == 'Compress PDF') {
                      if (!_isPdf) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'PDF compression requires a PDF file.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;
                      final targetContext = context;
                      final targetBytes = await showDialog<int>(
                        context: targetContext,
                        builder: (_) => CompressionTargetDialog(
                          fileName: widget.fileName,
                          fileSizeBytes: widget.fileBytes.length,
                        ),
                      );

                      if (!mounted || targetBytes == null) return;

                      final compressedBytes = await CompressionService()
                          .compressPdf(widget.fileBytes, targetBytes, widget.fileName);

                      if (!mounted) return;
                      final resultContext = context;
                      await showDialog(
                        context: resultContext,
                        builder: (_) => DownloadResultDialog(
                          outputFormat: selectedFormat,
                          fileName: widget.fileName,
                          outputBytes: compressedBytes,
                        ),
                      );
                      return;
                    }

                    if (selectedFormat == 'Compress Images') {
                      if (!_isImage) {
                        if (!mounted) return;
                        final errorContext = context;
                        ScaffoldMessenger.of(errorContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Image compression requires a JPG or PNG image file.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;
                      final targetContext = context;
                      final targetBytes = await showDialog<int>(
                        context: targetContext,
                        builder: (_) => CompressionTargetDialog(
                          fileName: widget.fileName,
                          fileSizeBytes: widget.fileBytes.length,
                        ),
                      );

                      if (!mounted || targetBytes == null) return;

                      final compressedBytes =
                          CompressionService().compressImage(
                        widget.fileBytes,
                        targetBytes,
                        widget.fileName,
                      );

                      if (!mounted) return;
                      final resultContext = context;
                      await showDialog(
                        context: resultContext,
                        builder: (_) => DownloadResultDialog(
                          outputFormat: selectedFormat,
                          fileName: widget.fileName,
                          outputBytes: compressedBytes,
                        ),
                      );
                      return;
                    }

                    final conversionService = ConversionService();
                    final result = await conversionService.convert(
                      inputBytes: widget.fileBytes,
                      inputFileName: widget.fileName,
                      outputFormat: selectedFormat,
                    );

                    if (!mounted) {
                      return;
                    }

                    if (!result.success) {
                      if (!mounted) return;
                      final errorContext = context;
                      ScaffoldMessenger.of(errorContext).showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                        ),
                      );
                      return;
                    }

                    if (!mounted) return;
                    final resultContext = context;
                    await showDialog(
                      context: resultContext,
                      builder: (_) => DownloadResultDialog(
                        outputFormat: selectedFormat,
                        fileName: result.outputFileName ?? widget.fileName,
                        outputBytes: result.outputBytes!,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Choose Output'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
