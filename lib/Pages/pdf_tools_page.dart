import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../Widgets/download_result_dialog.dart';
import '../Widgets/pdf_tool_card.dart';
import '../Widgets/site_footer_link.dart';
import '../Services/file_picker_service.dart';
import '../Services/pdf_ocr_service.dart';
import '../Services/public_brand_config.dart';
import '../Services/upload_context_service.dart';
import '../Services/word_generator_service.dart';
import 'pdf_edit_page.dart';

class PdfToolsPage extends StatefulWidget {
  const PdfToolsPage({super.key});

  @override
  State<PdfToolsPage> createState() => _PdfToolsPageState();
}

class _PdfToolsPageState extends State<PdfToolsPage> {
  List<PickedFileData> selectedPdfFiles = [];
  String? selectedPdfName;
  int? selectedPdfSize;

  // Stores the actual uploaded PDF data.
  Uint8List? selectedPdfBytes;

  bool isConverting = false;
  bool conversionCompleted = false;

  double progressValue = 0;

  String conversionStatus = '';
  String generatedFileName = '';
  Uint8List? generatedWordBytes;

  final WordGeneratorService wordService =
      const WordGeneratorService();
  final PdfOcrService _ocrService = const PdfOcrService();

  @override
  void initState() {
    super.initState();
    _hydrateFromHomeUpload();
  }

  void _hydrateFromHomeUpload() {
    final files = UploadContextService.getCompatibleFiles(['pdf']);
    if (files.isEmpty) {
      return;
    }

    final file = files.first;
    selectedPdfFiles = files;
    selectedPdfName = file.name;
    selectedPdfSize = file.size;
    selectedPdfBytes = file.bytes;
    conversionCompleted = false;
    generatedFileName = '';
    generatedWordBytes = null;
    progressValue = 0;
    conversionStatus = '✓ ${file.name} loaded from Home upload';
  }

  Future<void> pickPdf() async {
    final selectedFiles = await FilePickerService.pickMultipleFileData(
      allowedExtensions: const ['pdf'],
    );

    if (selectedFiles.isEmpty) {
      return;
    }

    final selectedFile = selectedFiles.first;

    setState(() {
      selectedPdfFiles = selectedFiles;
      selectedPdfName = selectedFile.name;
      selectedPdfSize = selectedFile.size;
      selectedPdfBytes = selectedFile.bytes;

      conversionCompleted = false;
      generatedFileName = '';
      generatedWordBytes = null;
      progressValue = 0;
      conversionStatus = '';
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            selectedFiles.length == 1
                ? 'Selected: ${selectedFile.name}'
                : '${selectedFiles.length} PDF files selected.',
        ),
      ),
    );
  }

  Future<void> convertPdfToWord() async {
    if (selectedPdfFiles.isEmpty || selectedPdfName == null || selectedPdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a PDF file first.',
          ),
        ),
      );

      return;
    }

    setState(() {
      isConverting = true;
      conversionCompleted = false;
      generatedFileName = '';
      progressValue = 0;
      conversionStatus = '📄 Preparing PDF...';
    });

    try {
      if (selectedPdfFiles.length > 1) {
        setState(() {
          conversionStatus = '📄 Preparing ${selectedPdfFiles.length} PDFs...';
        });

        final archive = Archive();
        for (var index = 0; index < selectedPdfFiles.length; index++) {
          final selectedFile = selectedPdfFiles[index];
          if (!mounted) return;

          setState(() {
            progressValue = (index + 1) / selectedPdfFiles.length;
            conversionStatus = '📄 Converting ${selectedFile.name}...';
          });

          Uint8List outputBytes;
          try {
            outputBytes = await wordService.createWordDocumentFromPdfLayout(
              pdfBytes: selectedFile.bytes,
              pdfFileName: selectedFile.name,
            );
          } catch (_) {
            final String extractedText = await _extractTextWithOcr(
              selectedFile.bytes,
              selectedFile.name,
            );

            outputBytes = await wordService.createWordDocument(
              pdfFileName: selectedFile.name,
              extractedText: extractedText,
            );
          }

          final String outputFileName = selectedFile.name.replaceAll(
            RegExp(r'\.pdf$', caseSensitive: false),
            '.docx',
          );

          archive.addFile(ArchiveFile(outputFileName, outputBytes.length, outputBytes));
        }

        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) {
          throw Exception('Unable to create ZIP output.');
        }

        if (!mounted) return;

        setState(() {
          progressValue = 1.0;
          conversionStatus = '✅ Finalizing batch...';
          conversionCompleted = true;
          generatedFileName = 'jobready_pdf_to_word_batch.zip';
          generatedWordBytes = Uint8List.fromList(zipBytes);
          isConverting = false;
        });

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: 'Word (.docx) Batch',
            fileName: 'jobready_pdf_to_word_batch.zip',
            outputBytes: Uint8List.fromList(zipBytes),
          ),
        );
        return;
      }

      // Progress UI.
      for (int i = 1; i <= 80; i++) {
        await Future.delayed(
          const Duration(milliseconds: 20),
        );

        if (!mounted) return;

        setState(() {
          progressValue = i / 100;

          if (i < 20) {
            conversionStatus =
                '📄 Preparing PDF...';
          } else if (i < 40) {
            conversionStatus =
                '🔍 Reading PDF...';
          } else if (i < 60) {
            conversionStatus =
                '✍️ Preparing Text Extraction...';
          } else {
            conversionStatus =
                '📄 Preparing Word File...';
          }
        });
      }

      Uint8List outputBytes;
      try {
        outputBytes = await wordService.createWordDocumentFromPdfLayout(
          pdfBytes: selectedPdfBytes!,
          pdfFileName: selectedPdfName!,
        );
      } catch (_) {
        final String extractedText = await _extractTextWithOcr(
          selectedPdfBytes!,
          selectedPdfName!,
        );

        outputBytes = await wordService.createWordDocument(
          pdfFileName: selectedPdfName!,
          extractedText: extractedText,
        );
      }

      if (outputBytes.isEmpty) {
        throw Exception(
          'Generated Word document is empty.',
        );
      }

      final String outputFileName =
          selectedPdfName!.replaceAll(
        RegExp(
          r'\.pdf$',
          caseSensitive: false,
        ),
        '.docx',
      );

      if (!mounted) return;

      setState(() {
        progressValue = 1.0;
        conversionStatus = '✅ Finalizing...';

        conversionCompleted = true;
        generatedFileName = outputFileName;
        generatedWordBytes = outputBytes;
        isConverting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$outputFileName created successfully.',
          ),
        ),
      );

      await showDialog(
        context: context,
        builder: (_) => DownloadResultDialog(
          outputFormat: 'Word (.docx)',
          fileName: outputFileName,
          outputBytes: outputBytes,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isConverting = false;
        conversionCompleted = false;
        conversionStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conversion failed: $e',
          ),
        ),
      );
    }
  }

  Future<String> _extractTextFromPdf(
    Uint8List pdfBytes,
    String pdfName,
  ) async {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        final extractedText = sfpdf.PdfTextExtractor(document).extractText();
        final normalizedText = extractedText.trim();
        return normalizedText.isEmpty
            ? 'No readable text was found in the selected PDF file.'
            : normalizedText;
      } finally {
        document.dispose();
      }
    } catch (e) {
      debugPrint('PDF extraction failed: $e');
      return 'Unable to extract text from the selected PDF. The file may contain scanned images or unsupported content.';
    }
  }

  Future<String> _extractTextWithOcr(
    Uint8List pdfBytes,
    String pdfName,
  ) async {
    final result = await _ocrService.extractText(
      pdfBytes: pdfBytes,
      fileName: pdfName,
      forceOcr: true,
    );

    if (result.success && result.text.trim().isNotEmpty) {
      return result.text;
    }

    return _extractTextFromPdf(pdfBytes, pdfName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF1F2937),
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
          'PDF Tools',
          style: TextStyle(
            color: Color(0xFFFFC72C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          const Text(
            'PDF Toolkit',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Convert, Merge, Split, Compress and OCR PDFs',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Support: ${PublicBrandConfig.supportEmail}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F4E79),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          if (selectedPdfName != null)
            Card(
              color: Colors.green.shade50,
              elevation: 2,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected PDF',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      selectedPdfFiles.length > 1
                          ? '${selectedPdfFiles.length} PDF files selected'
                          : selectedPdfName!,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      selectedPdfFiles.length > 1
                          ? 'Total Size : ${_formatBytes(selectedPdfFiles.fold<int>(0, (sum, file) => sum + file.size))}'
                          : 'Size : ${_formatBytes(selectedPdfSize!)}',
                    ),

                    if (selectedPdfFiles.length > 1) ...[
                      const SizedBox(height: 8),
                      ...selectedPdfFiles.take(4).map(
                        (file) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${file.name} • ${_formatBytes(file.size)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ),
                      if (selectedPdfFiles.length > 4)
                        Text(
                          '+${selectedPdfFiles.length - 4} more file(s)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],

                    const SizedBox(height: 6),

                    Text(
                      conversionCompleted
                          ? '✅ Status : Process Completed'
                          : 'Status : Ready to Convert',
                      style: TextStyle(
                        color:
                            conversionCompleted
                                ? Colors.blue
                                : Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    if (conversionCompleted) ...[
                      const SizedBox(height: 12),

                      const Text(
                        'Generated Word File',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        generatedFileName,
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.auto_fix_high,
                        ),
                        label: const Text(
                          'Convert to Word',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        onPressed: isConverting
                            ? null
                            : convertPdfToWord,
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (isConverting) ...[
                      const Text(
                        'Conversion Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 10,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '${(progressValue * 100).toInt()} %',
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        conversionStatus,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (selectedPdfName != null)
            const SizedBox(height: 20),

          PdfToolCard(
            icon: Icons.picture_as_pdf,
            title: 'PDF to Word',
            subtitle:
                'Convert one or many PDFs into editable Word documents',
            onTap: pickPdf,
          ),

          const SizedBox(height: 14),



          PdfToolCard(
            icon: Icons.merge_type,
            title: 'Merge PDF',
            subtitle:
                'Combine multiple PDF files',
            onTap: () {
              Navigator.of(context).pushNamed('/merge');
            },
          ),

          const SizedBox(height: 14),

          PdfToolCard(
            icon: Icons.content_cut,
            title: 'Split PDF',
            subtitle:
                'Extract pages from PDF files',
            onTap: () {
              Navigator.of(context).pushNamed('/split');
            },
          ),

          const SizedBox(height: 14),

          PdfToolCard(
            icon: Icons.compress,
            title: 'Compress PDF',
            subtitle: 'Reduce PDF size',
            onTap: () {
              Navigator.of(context).pushNamed('/compress');
            },
          ),

          const SizedBox(height: 14),

          PdfToolCard(
            icon: Icons.edit_note,
            title: 'PDF Edit + OCR',
            subtitle: 'Load text, run OCR for scanned PDFs, edit and save PDF',
            onTap: () {
              Navigator.of(context).pushNamed('/pdf-edit');
            },
          ),
        ],
      ),
      bottomNavigationBar: const SiteFooterLink(),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
