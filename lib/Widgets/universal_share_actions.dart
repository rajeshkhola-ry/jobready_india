import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class UniversalShareActions extends StatelessWidget {
  final String fileName;
  final String downloadUrl;
  final String mimeType;
  final List<int> outputBytes;
  final String? publicHttpsUrl;

  const UniversalShareActions({
    super.key,
    required this.fileName,
    required this.downloadUrl,
    required this.mimeType,
    required this.outputBytes,
    this.publicHttpsUrl,
  });

  bool _isValidPublicHttps(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.scheme == 'https';
  }

  bool _canShareFilesOnWeb({
    required html.File file,
  }) {
    try {
      final nav = html.window.navigator;
      if (!js_util.hasProperty(nav, 'canShare')) {
        return false;
      }

      final payload = js_util.jsify({
        'files': [file],
      });

      final result = js_util.callMethod<bool>(nav, 'canShare', [payload]);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void _showUnsupportedShareNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Direct file attachment is supported on mobile devices/native apps. Please download the file or use Email / Cloud Storage.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        final webFile = html.File(
          [outputBytes],
          fileName,
          {
            'type': mimeType,
          },
        );

        if (!_canShareFilesOnWeb(file: webFile)) {
          if (_isValidPublicHttps(publicHttpsUrl)) {
            html.window.open(publicHttpsUrl!, '_blank');
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Browser cannot attach files directly. Opened secure public file link.'),
                backgroundColor: Color(0xFF1F4E79),
              ),
            );
          } else {
            _showUnsupportedShareNotice(context);
          }
          return;
        }
      }

      final xFile = XFile.fromData(
        outputBytes,
        name: fileName,
        mimeType: mimeType,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: 'GETREADYJOB file: $fileName',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      if (_isValidPublicHttps(publicHttpsUrl)) {
        html.window.open(publicHttpsUrl!, '_blank');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Native attachment failed. Opened secure public file link.'),
            backgroundColor: Color(0xFF1F4E79),
          ),
        );
        return;
      }

      _showUnsupportedShareNotice(context);
    }
  }

  String _googleDriveSavePageDataUri() {
    final source = downloadUrl;
    final file = fileName;
    final htmlPage = '''<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Save To Google Drive</title>
  <script src="https://apis.google.com/js/platform.js" async defer></script>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; color: #123; }
    .hint { margin-top: 12px; color: #4a5568; font-size: 13px; }
  </style>
</head>
<body>
  <h3>Save To Google Drive</h3>
  <g:savetodrive src="$source" filename="$file" sitename="GETREADYJOB"></g:savetodrive>
  <p class="hint">If the button does not appear, refresh this tab once and try again.</p>
</body>
</html>''';
    return Uri.dataFromString(
      htmlPage,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  String _oneDriveSavePageDataUri() {
    final source = downloadUrl;
    final file = fileName;
    final htmlPage = '''<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Save To OneDrive</title>
  <script src="https://js.live.net/v7.2/OneDrive.js"></script>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; color: #123; }
    .btn {
      background: #0f62fe;
      color: white;
      border: 0;
      border-radius: 8px;
      padding: 10px 14px;
      font-weight: 700;
      cursor: pointer;
    }
    .hint { margin-top: 12px; color: #4a5568; font-size: 13px; }
  </style>
</head>
<body>
  <h3>Save To OneDrive</h3>
  <button class="btn" onclick="saveNow()">Save File</button>
  <p class="hint">Uses free OneDrive Saver SDK. If popup is blocked, allow popups and try again.</p>
  <script>
    const sourceUrl = "$source";
    const sourceFile = "$file";
    function saveNow() {
      try {
        OneDrive.save({
          sourceUri: sourceUrl,
          fileName: sourceFile,
          openInNewWindow: true,
          success: function() {
            console.log('Saved to OneDrive');
          },
          progress: function() {},
          cancel: function() {},
          error: function(e) {
            console.log('OneDrive save error', e);
          }
        });
      } catch (e) {
        alert('OneDrive SDK could not start.');
      }
    }
  </script>
</body>
</html>''';
    return Uri.dataFromString(
      htmlPage,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  Future<void> _openGoogleDriveSaver(BuildContext context) async {
    html.window.open(_googleDriveSavePageDataUri(), '_blank');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Drive saver opened with current file payload.'),
        backgroundColor: Color(0xFF0F766E),
      ),
    );
  }

  Future<void> _openOneDriveSaver(BuildContext context) async {
    html.window.open(_oneDriveSavePageDataUri(), '_blank');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OneDrive saver opened with current file payload.'),
        backgroundColor: Color(0xFF1D4ED8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share or Save',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => unawaited(_shareFile(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF128C7E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Share File (Email/WhatsApp)'),
            ),
            OutlinedButton(
              onPressed: () => unawaited(_openGoogleDriveSaver(context)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                side: const BorderSide(color: Color(0xFF0F766E)),
              ),
              child: const Text('Google Drive'),
            ),
            OutlinedButton(
              onPressed: () => unawaited(_openOneDriveSaver(context)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1D4ED8),
                side: const BorderSide(color: Color(0xFF1D4ED8)),
              ),
              child: const Text('OneDrive'),
            ),
          ],
        ),
      ],
    );
  }
}
