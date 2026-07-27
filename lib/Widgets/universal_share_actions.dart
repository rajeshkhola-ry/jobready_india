import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

class UniversalShareActions extends StatelessWidget {
  final String fileName;
  final String downloadUrl;
  final String shareText;

  const UniversalShareActions({
    super.key,
    required this.fileName,
    required this.downloadUrl,
    required this.shareText,
  });

  Future<void> _copyShareText(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share text copied.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openWhatsApp() {
    final encoded = Uri.encodeComponent(shareText);
    html.window.open('https://wa.me/?text=$encoded', '_blank');
  }

  void _openEmail() {
    final subject = Uri.encodeComponent('GETREADYJOB file ready: $fileName');
    final body = Uri.encodeComponent(shareText);
    html.window.open('mailto:?subject=$subject&body=$body', '_self');
  }

  String _googleDriveSavePageDataUri() {
    final source = jsonEncode(downloadUrl);
    final file = jsonEncode(fileName);
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
  <g:savetodrive src="'''+downloadUrl+'''" filename="'''+fileName+'''" sitename="GETREADYJOB"></g:savetodrive>
  <p class="hint">If the button does not appear, refresh this tab once and try again.</p>
  <script>
    window.__grjDriveSource = $source;
    window.__grjDriveFile = $file;
  </script>
</body>
</html>''';
    return Uri.dataFromString(
      htmlPage,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  String _oneDriveSavePageDataUri() {
    final source = jsonEncode(downloadUrl);
    final file = jsonEncode(fileName);
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
    const sourceUrl = $source;
    const sourceFile = $file;
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

  void _openGoogleDriveSaver() {
    html.window.open(_googleDriveSavePageDataUri(), '_blank');
  }

  void _openOneDriveSaver() {
    html.window.open(_oneDriveSavePageDataUri(), '_blank');
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
              onPressed: () {
                _openWhatsApp();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF128C7E),
                foregroundColor: Colors.white,
              ),
              child: const Text('WhatsApp'),
            ),
            ElevatedButton(
              onPressed: () {
                _openEmail();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
              ),
              child: const Text('Email'),
            ),
            OutlinedButton(
              onPressed: () async {
                _openGoogleDriveSaver();
                await _copyShareText(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                side: const BorderSide(color: Color(0xFF0F766E)),
              ),
              child: const Text('Google Drive'),
            ),
            OutlinedButton(
              onPressed: () async {
                _openOneDriveSaver();
                await _copyShareText(context);
              },
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
