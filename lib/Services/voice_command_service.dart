import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'api_config.dart';

/// Result of a single voice-command recording + Gemini classification round trip.
class VoiceCommandResult {
  final bool success;
  final String tool;
  final String action;
  final Map<String, dynamic> parameters;
  final String recognizedText;
  final double confidence;
  final String? error;

  const VoiceCommandResult({
    required this.success,
    this.tool = '',
    this.action = '',
    this.parameters = const {},
    this.recognizedText = '',
    this.confidence = 0,
    this.error,
  });

  factory VoiceCommandResult.failure(String message) =>
      VoiceCommandResult(success: false, error: message);
}

/// Records a short voice command clip from the browser microphone and sends it
/// to the backend (POST /api/voice-command) for Gemini Flash classification.
///
/// Uses `package:web` + `dart:js_interop` (this project's Dart 3.12 SDK no
/// longer resolves `dart:js_util`, and `dart:js`'s `allowInterop` is not
/// defined either, so the modern typed interop package is the only working
/// option for browser MediaRecorder/getUserMedia access here).
class VoiceCommandService {
  VoiceCommandService._();
  static final VoiceCommandService instance = VoiceCommandService._();

  static Map<String, dynamic> _pendingParameters = const {};

  /// Stash parameters extracted from a voice command (e.g. target_size_kb,
  /// preset) so the destination tool page can read + apply them once after
  /// navigation completes.
  static void setPendingParameters(Map<String, dynamic> parameters) {
    _pendingParameters = parameters;
  }

  /// One-shot read: returns and clears any pending voice-command parameters.
  static Map<String, dynamic> consumePendingParameters() {
    final result = _pendingParameters;
    _pendingParameters = const {};
    return result;
  }

  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  final List<web.Blob> _chunks = [];
  String _mimeType = 'audio/webm';

  /// Requests microphone access and starts recording. Returns true if
  /// recording actually started (false if unsupported, denied, or failed).
  Future<bool> startRecording() async {
    try {
      final constraints = web.MediaStreamConstraints(audio: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;

      _mediaStream = stream;
      _mimeType = _pickSupportedMimeType();
      _chunks.clear();

      final options = web.MediaRecorderOptions(mimeType: _mimeType);
      final recorder = web.MediaRecorder(stream, options);
      _mediaRecorder = recorder;

      recorder.ondataavailable = ((web.Event event) {
        final blobEvent = event as web.BlobEvent;
        if (blobEvent.data.size > 0) {
          _chunks.add(blobEvent.data);
        }
      }).toJS;

      recorder.start();
      return true;
    } catch (_) {
      _releaseStream();
      return false;
    }
  }

  String _pickSupportedMimeType() {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
    ];
    for (final candidate in candidates) {
      try {
        if (web.MediaRecorder.isTypeSupported(candidate)) {
          return candidate;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }
    return 'audio/webm';
  }

  /// Stops recording, uploads the captured audio, and returns the
  /// Gemini-classified tool/action/parameters (or a failure result).
  Future<VoiceCommandResult> stopRecordingAndClassify() async {
    final recorder = _mediaRecorder;
    if (recorder == null) {
      return VoiceCommandResult.failure('Recording was not started.');
    }

    try {
      final stopCompleter = Completer<void>();
      recorder.onstop = ((web.Event event) {
        if (!stopCompleter.isCompleted) stopCompleter.complete();
      }).toJS;
      recorder.stop();
      await stopCompleter.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {
      // Proceed with whatever chunks were already captured.
    } finally {
      _releaseStream();
    }

    if (_chunks.isEmpty) {
      return VoiceCommandResult.failure('No audio captured. Please try again.');
    }

    try {
      final parts = <JSAny>[for (final chunk in _chunks) chunk].toJS;
      final blob = web.Blob(parts, web.BlobPropertyBag(type: _mimeType));
      final bytes = await _blobToBytes(blob);
      return _uploadAndClassify(bytes);
    } catch (_) {
      return VoiceCommandResult.failure('Could not process the recording. Please try again.');
    } finally {
      _chunks.clear();
    }
  }

  /// Cancels an in-progress recording without uploading (e.g. user backs out).
  void cancelRecording() {
    try {
      _mediaRecorder?.stop();
    } catch (_) {
      // ignore
    }
    _releaseStream();
    _chunks.clear();
  }

  void _releaseStream() {
    try {
      final tracks = _mediaStream?.getTracks().toDart;
      if (tracks != null) {
        for (final track in tracks) {
          track.stop();
        }
      }
    } catch (_) {
      // ignore
    }
    _mediaStream = null;
    _mediaRecorder = null;
  }

  Future<Uint8List> _blobToBytes(web.Blob blob) async {
    final arrayBuffer = await blob.arrayBuffer().toDart.timeout(const Duration(seconds: 10));
    return arrayBuffer.toDart.asUint8List();
  }

  Future<VoiceCommandResult> _uploadAndClassify(Uint8List bytes) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base/api/voice-command');

      final extension = _mimeType.contains('ogg')
          ? 'ogg'
          : (_mimeType.contains('mp4') ? 'm4a' : 'webm');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('audio', bytes, filename: 'voice_command.$extension'));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return VoiceCommandResult.failure('Voice command service returned an unreadable response.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        return VoiceCommandResult.failure(
          (decoded['error'] as String?) ?? 'Voice command failed. Please try again.',
        );
      }

      final rawParameters = decoded['parameters'];
      return VoiceCommandResult(
        success: true,
        tool: (decoded['tool'] as String?) ?? '',
        action: (decoded['action'] as String?) ?? '',
        parameters: rawParameters is Map ? Map<String, dynamic>.from(rawParameters) : const {},
        recognizedText: (decoded['recognized_text'] as String?) ?? '',
        confidence: (decoded['confidence'] as num?)?.toDouble() ?? 0,
      );
    } on TimeoutException {
      return VoiceCommandResult.failure('Voice command timed out. Please check your connection.');
    } catch (_) {
      return VoiceCommandResult.failure('Could not reach the voice command service.');
    }
  }
}
