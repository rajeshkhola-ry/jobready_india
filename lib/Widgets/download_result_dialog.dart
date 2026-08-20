import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/device_fingerprint_service.dart';
import '../Services/document_history_service.dart';
import '../Services/usage_quota_service.dart';
import 'universal_share_actions.dart';

class DownloadResultDialog extends StatelessWidget {
  final String outputFormat;
  final String fileName;
  final Uint8List outputBytes;
  final int? originalFileSizeBytes;

  const DownloadResultDialog({
    super.key,
    required this.outputFormat,
    required this.fileName,
    required this.outputBytes,
    this.originalFileSizeBytes,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  String _mimeTypeFromFileName() {
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

    return 'application/octet-stream';
  }

  String _createTemporaryFileUrl() {
    final blob = html.Blob([outputBytes], _mimeTypeFromFileName());
    final url = html.Url.createObjectUrlFromBlob(blob);
    Future<void>.delayed(const Duration(minutes: 10), () {
      html.Url.revokeObjectUrl(url);
    });
    return url;
  }

  String _shareMessage(String fileUrl) {
    return 'File ready from GETREADYJOB.\nFile: $fileName\nDownload: $fileUrl';
  }

  void _downloadFile(BuildContext context) {
    try {
      final blob = html.Blob([outputBytes], _mimeTypeFromFileName());
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      // Delay revoke so browser has time to start the download stream.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        html.Url.revokeObjectUrl(url);
      });

      DocumentHistoryService.addEntry(
        fileName: fileName,
        outputFormat: outputFormat,
        fileSizeBytes: outputBytes.length,
      );
      UsageQuotaService.recordAction(outputFormat);
      DeviceFingerprintService.recordFileConsumed();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download started for $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download was blocked. We opened the file in a new tab. If it still fails, allow pop-ups or use Save Link.'),
          backgroundColor: Colors.orange,
        ),
      );

      final blob = html.Blob([outputBytes], _mimeTypeFromFileName());
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');

      Future<void>.delayed(const Duration(seconds: 15), () {
        html.Url.revokeObjectUrl(url);
      });
    }
  }

  void _showSaveLink(BuildContext context) {
    final blob = html.Blob([outputBytes], _mimeTypeFromFileName());
    final url = html.Url.createObjectUrlFromBlob(blob);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saved Link'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is your generated browser save link:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Save link copied.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () {
              html.window.open(url, '_blank');
            },
            child: const Text('Open Link'),
          ),
          TextButton(
            onPressed: () {
              html.Url.revokeObjectUrl(url);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      html.Url.revokeObjectUrl(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompressionResult = outputFormat.toLowerCase().contains('compress');
    final outputSizeLabel = isCompressionResult ? 'Compressed Size' : 'Output Size';
    final outputSizeText = _formatBytes(outputBytes.length);
    final shareUrl = _createTemporaryFileUrl();

    String? reductionText;
    if (originalFileSizeBytes != null && originalFileSizeBytes! > 0) {
      final reduced = ((originalFileSizeBytes! - outputBytes.length) /
              originalFileSizeBytes! *
              100)
          .clamp(-999.0, 100.0);
      reductionText = '${reduced.toStringAsFixed(1)}%';
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text(
              'Back To Tool',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1F4E79),
              side: const BorderSide(color: Color(0xFF1F4E79)),
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],

      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 350,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Icon(
              Icons.check_circle,
              size: 44,
              color: Colors.green,
            ),
            const SizedBox(height: 6),
            Text(
              isCompressionResult ? 'Compression Complete' : 'Conversion Complete',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(label: 'Output', value: outputFormat),
            const SizedBox(height: 6),
            _InfoRow(label: 'File', value: fileName, maxLines: 2),
            const SizedBox(height: 6),
            _InfoRow(label: outputSizeLabel, value: outputSizeText),
            if (originalFileSizeBytes != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                label: 'Original Size',
                value: _formatBytes(originalFileSizeBytes!),
              ),
            ],
            if (reductionText != null) ...[
              const SizedBox(height: 6),
              _InfoRow(label: 'Reduction', value: reductionText),
            ],
            const SizedBox(height: 6),
            const _InfoRow(label: 'Saved', value: 'Browser Downloads'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _downloadFile(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Download',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () => _showSaveLink(context),
                icon: const Icon(Icons.link, size: 17),
                label: const Text(
                  'Save Link',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F4E79),
                  side: const BorderSide(color: Color(0xFF1F4E79)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            UniversalShareActions(
              fileName: fileName,
              downloadUrl: shareUrl,
              mimeType: _mimeTypeFromFileName(),
              outputBytes: outputBytes,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _InfoRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
