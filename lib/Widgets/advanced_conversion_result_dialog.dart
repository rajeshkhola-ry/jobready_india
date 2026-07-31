import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

class ConversionArtifact {
  const ConversionArtifact({
    required this.sourceFileName,
    required this.outputFormat,
    required this.fileName,
    required this.outputBytes,
    this.message,
  });

  final String sourceFileName;
  final String outputFormat;
  final String fileName;
  final Uint8List outputBytes;
  final String? message;
}

class AdvancedConversionResultDialog extends StatelessWidget {
  const AdvancedConversionResultDialog({super.key, required this.artifacts});

  final List<ConversionArtifact> artifacts;

  String _mimeTypeFromFileName(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerName.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lowerName.endsWith('.txt')) {
      return 'text/plain';
    }
    if (lowerName.endsWith('.zip')) {
      return 'application/zip';
    }
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lowerName.endsWith('.csv')) {
      return 'text/csv';
    }
    return 'application/octet-stream';
  }

  void _downloadArtifact(BuildContext context, ConversionArtifact artifact) {
    try {
      final blob = html.Blob([artifact.outputBytes], _mimeTypeFromFileName(artifact.fileName));
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', artifact.fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      Future<void>.delayed(const Duration(milliseconds: 800), () {
        html.Url.revokeObjectUrl(url);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading ${artifact.fileName}'), backgroundColor: Colors.green),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download was blocked. Please allow pop-ups and try again.'), backgroundColor: Colors.orange),
      );
    }
  }

  void _shareWhatsApp(BuildContext context, ConversionArtifact artifact) {
    final fallback = 'File ready from GETREADYJOB: ${artifact.fileName}';
    final encoded = Uri.encodeComponent(fallback);
    html.window.open('https://wa.me/?text=$encoded', '_blank');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp share opened'), backgroundColor: Color(0xFF128C7E)),
    );
  }

  void _shareEmail(BuildContext context, ConversionArtifact artifact) {
    final subject = Uri.encodeComponent('GETREADYJOB conversion ready: ${artifact.fileName}');
    final body = Uri.encodeComponent('Your generated file from GETREADYJOB is ready.\nFile: ${artifact.fileName}\nAction: ${artifact.outputFormat}');
    html.window.open('mailto:hello@getreadyjob.com?subject=$subject&body=$body', '_blank');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email composer opened'), backgroundColor: Color(0xFF1F4E79)),
    );
  }

  Future<void> _copyLink(BuildContext context, ConversionArtifact artifact) async {
    final blob = html.Blob([artifact.outputBytes], _mimeTypeFromFileName(artifact.fileName));
    final url = html.Url.createObjectUrlFromBlob(blob);
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download link copied'), backgroundColor: Colors.blue),
    );
    Future<void>.delayed(const Duration(seconds: 12), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conversion Ready'),
          const SizedBox(height: 4),
          Text(
            '${artifacts.length} file${artifacts.length == 1 ? '' : 's'} ready for download',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final artifact in artifacts) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artifact.fileName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${artifact.outputFormat} • ${artifact.sourceFileName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (artifact.message != null && artifact.message!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          artifact.message!,
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _downloadArtifact(context, artifact),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F4E79),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareWhatsApp(context, artifact),
                            icon: const Icon(Icons.chat_rounded, size: 16),
                            label: const Text('WhatsApp'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareEmail(context, artifact),
                            icon: const Icon(Icons.email_rounded, size: 16),
                            label: const Text('Email'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => unawaited(_copyLink(context, artifact)),
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Copy Link'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
