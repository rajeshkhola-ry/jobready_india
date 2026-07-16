import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/api_config.dart';
import '../Services/document_history_service.dart';
import '../Services/usage_quota_service.dart';

class DownloadResultDialog extends StatelessWidget {
  final String outputFormat;
  final String fileName;
  final Uint8List outputBytes;

  const DownloadResultDialog({
    super.key,
    required this.outputFormat,
    required this.fileName,
    required this.outputBytes,
  });

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
    return 'File ready from JOBREADY.\nFile: $fileName\nDownload: $fileUrl';
  }

  Future<void> _copyShareText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share text copied.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _shareWithSystem(BuildContext context, String fileUrl) async {
    final message = _shareMessage(fileUrl);
    // Universal fallback across browser/runtime variants.
    await _copyShareText(context, message);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share text copied. Paste it in your app.'),
        backgroundColor: Color(0xFF1F4E79),
      ),
    );
  }

  Future<void> _openShareTarget({
    required BuildContext context,
    required String target,
    required String fileUrl,
  }) async {
    final encodedMessage = Uri.encodeComponent(_shareMessage(fileUrl));
    final encodedUrl = Uri.encodeComponent(fileUrl);

    String? shareUrl;
    String? helperMessage;

    switch (target) {
      case 'whatsapp':
        shareUrl = 'https://wa.me/?text=$encodedMessage';
        break;
      case 'facebook':
        shareUrl = 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';
        break;
      case 'linkedin':
        shareUrl = 'https://www.linkedin.com/sharing/share-offsite/?url=$encodedUrl';
        break;
      case 'google_drive':
        shareUrl = 'https://drive.google.com/drive/my-drive';
        helperMessage = 'Google Drive opened. Paste upload/share link there.';
        break;
      case 'onedrive':
        shareUrl = 'https://onedrive.live.com';
        helperMessage = 'OneDrive opened. Paste upload/share link there.';
        break;
      case 'icloud':
        shareUrl = 'https://www.icloud.com/iclouddrive';
        helperMessage = 'iCloud Drive opened. Paste upload/share link there.';
        break;
      default:
        break;
    }

    if (shareUrl == null) {
      return;
    }

    html.window.open(shareUrl, '_blank');

    if (helperMessage != null) {
      await _copyShareText(context, _shareMessage(fileUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(helperMessage),
          backgroundColor: const Color(0xFF1F4E79),
        ),
      );
    }
  }

  Future<void> _showShareOptions(BuildContext context) async {
    final fileUrl = _createTemporaryFileUrl();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'Share File To',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('Choose app or cloud destination'),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This feature is available: Manual Copy-Paste and API integration.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [
                      _ShareOptionTile(
                        icon: Icons.copy_rounded,
                        title: 'Manual Copy-Paste',
                        subtitle: 'Copy file link and paste in any app',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _copyShareText(context, _shareMessage(fileUrl));
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.api_rounded,
                        title: 'API Integration',
                        subtitle: 'Use integration endpoint for automated sharing',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          final apiGuide =
                              'API share endpoint: ${ApiConfig.baseUrl}${ApiConfig.integrationExecuteEndpoint}\nPayload includes app_id, action_id, and file link.';
                          await _copyShareText(context, apiGuide);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('API integration guide copied.'),
                              backgroundColor: Color(0xFF1F4E79),
                            ),
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.share,
                        title: 'System Share',
                        subtitle: 'Use device/browser share sheet',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _shareWithSystem(context, fileUrl);
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.chat,
                        title: 'WhatsApp',
                        subtitle: 'Send file link in chat',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'whatsapp',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.business,
                        title: 'LinkedIn',
                        subtitle: 'Share file link to LinkedIn',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'linkedin',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.thumb_up_alt,
                        title: 'Facebook',
                        subtitle: 'Share file link to Facebook',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'facebook',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.cloud_upload,
                        title: 'Google Drive',
                        subtitle: 'Open Drive and copy share text',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'google_drive',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.cloud_done,
                        title: 'OneDrive',
                        subtitle: 'Open OneDrive and copy share text',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'onedrive',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                      _ShareOptionTile(
                        icon: Icons.cloud_circle,
                        title: 'iCloud Drive',
                        subtitle: 'Open iCloud and copy share text',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openShareTarget(
                            context: context,
                            target: 'icloud',
                            fileUrl: fileUrl,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download started for $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download blocked by browser. Opening file link in new tab.'),
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
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _showShareOptions(context),
                icon: const Icon(Icons.share, size: 17),
                label: const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1F4E79)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
