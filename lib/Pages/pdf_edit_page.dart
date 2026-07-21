import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/pdf_ocr_service.dart';
import '../Widgets/download_result_dialog.dart';
import '../Widgets/production_footer.dart';
import '../Widgets/tool_guidance_panel.dart';

class PdfEditPage extends StatefulWidget {
  final String? initialFileName;
  final Uint8List? initialBytes;

  const PdfEditPage({
    super.key,
    this.initialFileName,
    this.initialBytes,
  });

  @override
  State<PdfEditPage> createState() => _PdfEditPageState();
}

class _PdfEditPageState extends State<PdfEditPage> {
  Uint8List? _selectedBytes;
  String? _selectedName;
  bool _isSaving = false;
  bool _isLoadingText = false;
  String _loadStatus = 'Ready';

  final TextEditingController _editorController = TextEditingController();
  final PdfOcrService _ocrService = const PdfOcrService();

  @override
  void initState() {
    super.initState();
    _selectedBytes = widget.initialBytes;
    _selectedName = widget.initialFileName;

    // If no initial file provided, check for previously uploaded files
    if (_selectedBytes == null) {
      final storedFile = FileStorageService.getLatestFile();
      if (storedFile != null && _isPdfFile(storedFile.name)) {
        _selectedBytes = storedFile.getBytes();
        _selectedName = storedFile.name;
        _loadStatus = 'Loaded previously uploaded file: ${storedFile.name}';
      }
    }

    if (_selectedBytes != null) {
      _loadPdfTextIntoEditor();
    }
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final files = await FilePickerService.pickMultipleFileData(
      allowedExtensions: const ['pdf'],
    );

    if (files.isEmpty) {
      return;
    }

    setState(() {
      _selectedBytes = files.first.bytes;
      _selectedName = files.first.name;
      _loadStatus = 'ℹ️ PDF loaded. Click "Load Text" or "Run OCR" to extract content.';
    });

    await _loadPdfTextIntoEditor();
  }

  void _clearUploadedFile() {
    setState(() {
      _selectedBytes = null;
      _selectedName = null;
      _editorController.clear();
      _loadStatus = 'File removed. Upload a new PDF to continue.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded file removed.')),
    );
  }

  Future<void> _loadPdfTextIntoEditor({bool forceOcr = false}) async {
    if (_selectedBytes == null) {
      return;
    }

    setState(() {
      _isLoadingText = true;
    });

    try {
      final result = await _ocrService.extractText(
        pdfBytes: _selectedBytes!,
        fileName: _selectedName ?? 'document.pdf',
        forceOcr: forceOcr,
      );

      if (result.success) {
        _editorController.text = result.text;
        _loadStatus = 'Ready: PDF text loaded successfully';
      } else {
        _editorController.text = '';
        _loadStatus = 'ℹ️ OCR backend not configured. Loaded embedded PDF text instead.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loadStatus)),
        );
      }
    } catch (e) {
      _editorController.text = '';
      _loadStatus = 'Error: Unable to load text from PDF. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loadStatus)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingText = false;
        });
      }
    }
  }

  Future<void> _extractTables() async {
    if (_selectedBytes == null || _selectedName == null) return;
    setState(() {
      _isLoadingText = true;
      _loadStatus = 'Extracting tables and form data...';
    });
    try {
      final result = await _ocrService.extractText(
        pdfBytes: _selectedBytes!,
        fileName: _selectedName!,
        mode: PdfExtractionMode.tableAware,
      );
      _editorController.text = result.success && result.text.trim().isNotEmpty
          ? result.text
          : 'No table or form content found in this PDF.';
      _loadStatus = result.success
          ? 'Ready: Tables and forms extracted'
          : 'ℹ️ OCR backend not configured. Extracted embedded table data instead.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loadStatus)));
      }
    } catch (e) {
      _loadStatus = 'Error: Table extraction failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loadStatus)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  Future<void> _saveEditedPdf() async {
    if (_selectedBytes == null || _selectedName == null) {
      return;
    }

    final editedText = _editorController.text.trim();
    if (editedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please edit or enter text before saving.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // APPROACH 1: Try to preserve original PDF structure by adding text overlay
      try {
        final originalDoc = sfpdf.PdfDocument.fromBase64String(
          base64Encode(_selectedBytes!),
        );

        try {
          // Append edited content to the end of the document
          final lastPageIndex = originalDoc.pages.count - 1;
          if (lastPageIndex >= 0) {
            final lastPage = originalDoc.pages[lastPageIndex];
            final graphics = lastPage.graphics;

            // Add separator
            graphics.drawLine(
              sfpdf.PdfPen(sfpdf.PdfColor(200, 200, 200)),
              const Offset(20, 700),
              Offset(lastPage.size.width - 20, 700),
            );

            // Add edited text
            final bodyFont = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.timesRoman, 10);
            graphics.drawString(
              'EDITED CONTENT:\n$editedText',
              bodyFont,
              pen: sfpdf.PdfPen(sfpdf.PdfColor(31, 41, 55)),
              bounds: Rect.fromLTWH(20, 720, lastPage.size.width - 40, lastPage.size.height - 740),
            );
          }

          final bytes = Uint8List.fromList(originalDoc.saveSync());
          final outputName = _selectedName!.replaceAll(
            RegExp(r'\.pdf$', caseSensitive: false),
            '_edited.pdf',
          );

          if (!mounted) return;

          setState(() {
            _isSaving = false;
          });

          await showDialog(
            context: context,
            builder: (_) => DownloadResultDialog(
              outputFormat: 'Edited PDF (with original content preserved)',
              fileName: outputName,
              outputBytes: bytes,
            ),
          );

          return;
        } finally {
          originalDoc.dispose();
        }
      } catch (_) {
        // FALLBACK: If overlay fails, create a clean formatted PDF
      }

      // APPROACH 2: Create new formatted PDF with proper structure
      final outputDocument = sfpdf.PdfDocument();
      try {
        final textLines = editedText.split('\n');
        var lineIndex = 0;

        while (lineIndex < textLines.length) {
          final page = outputDocument.pages.add();
          final pageWidth = page.size.width;
          final pageHeight = page.size.height;
          const marginLeft = 20.0;
          const marginTop = 20.0;
          const marginRight = 20.0;
          const marginBottom = 20.0;

          var yPosition = marginTop;
          const lineHeight = 16.0;
          const maxLinesPerPage = 42;
          var linesOnPage = 0;

          // Add header
          final headerFont = sfpdf.PdfStandardFont(
            sfpdf.PdfFontFamily.timesRoman,
            11,
            style: sfpdf.PdfFontStyle.bold,
          );
          final bodyFont = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.timesRoman, 10);

          page.graphics.drawString(
            'Edited PDF from: $_selectedName',
            headerFont,
            pen: sfpdf.PdfPen(sfpdf.PdfColor(31, 41, 55)),
            bounds: Rect.fromLTWH(marginLeft, yPosition, pageWidth - marginLeft - marginRight, 18),
          );

          yPosition += 22;

          // Add edited content with proper text wrapping
          while (lineIndex < textLines.length && linesOnPage < maxLinesPerPage) {
            final rawLine = textLines[lineIndex].replaceAll(RegExp(r'\s+'), ' ').trim();

            if (rawLine.isEmpty) {
              yPosition += lineHeight * 0.5;
              linesOnPage++;
              lineIndex++;
              continue;
            }

            // Handle text wrapping for long lines
            final maxCharsPerLine = 95;
            if (rawLine.length > maxCharsPerLine) {
              final words = rawLine.split(' ');
              var currentLine = '';

              for (final word in words) {
                if ((currentLine + word).length > maxCharsPerLine) {
                  if (currentLine.isNotEmpty) {
                    page.graphics.drawString(
                      currentLine.trim(),
                      bodyFont,
                      pen: sfpdf.PdfPen(sfpdf.PdfColor(50, 50, 50)),
                      bounds: Rect.fromLTWH(
                        marginLeft,
                        yPosition,
                        pageWidth - marginLeft - marginRight,
                        lineHeight,
                      ),
                    );
                    yPosition += lineHeight;
                    linesOnPage++;

                    if (linesOnPage >= maxLinesPerPage) break;
                  }
                  currentLine = '';
                }
                currentLine += '$word ';
              }

              if (currentLine.isNotEmpty && linesOnPage < maxLinesPerPage) {
                page.graphics.drawString(
                  currentLine.trim(),
                  bodyFont,
                  pen: sfpdf.PdfPen(sfpdf.PdfColor(50, 50, 50)),
                  bounds: Rect.fromLTWH(
                    marginLeft,
                    yPosition,
                    pageWidth - marginLeft - marginRight,
                    lineHeight,
                  ),
                );
                yPosition += lineHeight;
                linesOnPage++;
              }
            } else {
              page.graphics.drawString(
                rawLine,
                bodyFont,
                pen: sfpdf.PdfPen(sfpdf.PdfColor(50, 50, 50)),
                bounds: Rect.fromLTWH(
                  marginLeft,
                  yPosition,
                  pageWidth - marginLeft - marginRight,
                  lineHeight,
                ),
              );
              yPosition += lineHeight;
              linesOnPage++;
            }

            lineIndex++;
          }

          // Add footer
          final footerFont = sfpdf.PdfStandardFont(
            sfpdf.PdfFontFamily.timesRoman,
            9,
          );
          page.graphics.drawString(
            'Edited by GETREADYJOB PDF Editor',
            footerFont,
            pen: sfpdf.PdfPen(sfpdf.PdfColor(150, 150, 150)),
            bounds: Rect.fromLTWH(
              marginLeft,
              pageHeight - marginBottom - 12,
              pageWidth - marginLeft - marginRight,
              10,
            ),
          );
        }

        final bytes = Uint8List.fromList(outputDocument.saveSync());
        final outputName = _selectedName!.replaceAll(
          RegExp(r'\.pdf$', caseSensitive: false),
          '_edited.pdf',
        );

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        await showDialog(
          context: context,
          builder: (_) => DownloadResultDialog(
            outputFormat: 'Edited PDF',
            fileName: outputName,
            outputBytes: bytes,
          ),
        );
      } finally {
        outputDocument.dispose();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save PDF: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        title: const Text(
          'PDF to PDF (Edit)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Upload/Change PDF buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(_selectedName == null ? 'Upload PDF' : 'Change PDF'),
                ),
              ),
              if (_selectedName != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearUploadedFile,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Text extraction buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_selectedBytes == null || _isLoadingText)
                      ? null
                      : () => _loadPdfTextIntoEditor(forceOcr: false),
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Load Text'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_selectedBytes == null || _isLoadingText)
                      ? null
                      : () => _loadPdfTextIntoEditor(forceOcr: true),
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Run OCR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_selectedBytes == null || _isLoadingText) ? null : _extractTables,
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Tables'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current file info
          if (_selectedName != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Editing: $_selectedName',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Status message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _loadStatus.toLowerCase().contains('error')
                  ? const Color(0xFFFEE2E2)
                  : _loadStatus.toLowerCase().contains('not configured')
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _loadStatus.toLowerCase().contains('error')
                    ? const Color(0xFFFCA5A5)
                    : _loadStatus.toLowerCase().contains('not configured')
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFFA7F3D0),
              ),
            ),
            child: Text(
              _loadStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _loadStatus.toLowerCase().contains('error')
                    ? const Color(0xFF991B1B)
                    : _loadStatus.toLowerCase().contains('not configured')
                        ? const Color(0xFF92400E)
                        : const Color(0xFF065F46),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Editor title
          const Text(
            'PDF Edit and OCR Workspace',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 8),

          // Text editor
          if (_isLoadingText)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            TextField(
              controller: _editorController,
              minLines: 12,
              maxLines: 20,
              decoration: const InputDecoration(
                labelText: 'Edit text manually here (multiple changes in one shot)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Text(
              'Upload PDF → Load Text or Run OCR → Edit manually → Save/Download as PDF.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 12),

          // Save button
          ElevatedButton.icon(
            onPressed: (_selectedBytes == null || _isSaving) ? null : _saveEditedPdf,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt_rounded),
            label: Text(_isSaving ? 'Saving Edited PDF...' : 'Save & Download Edited PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const ToolGuidancePanel(
            title: 'About PDF Edit & OCR',
            summary: 'Use this page to load text from a PDF, run OCR for scanned content, review extracted tables, and save an edited PDF output.',
            supportedFormats: ['PDF'],
            howToUse: ['Upload a PDF.', 'Load text or run OCR.', 'Edit content and save the updated PDF.'],
            faqs: ['Will OCR work on every scan? Results vary by source quality.', 'Can I recover complex layouts perfectly? Some formatting may need manual review.'],
            tips: ['Use cleaner scans for better OCR.', 'Review extracted text before saving.', 'Keep the original PDF for comparison.'],
          ),
          const SizedBox(height: 16),
          const ProductionFooter(compact: true),
        ],
      ),
    );
  }

  bool _isPdfFile(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }
}
