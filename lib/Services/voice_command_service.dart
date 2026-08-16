import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:universal_html/html.dart' as html;
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

  /// Sentinel key: when present and `true` in the pending-parameters map, the
  /// destination tool page should run its main action end-to-end (auto-run +
  /// auto-download) instead of only pre-filling the UI, provided a file is
  /// already available (via the existing upload-context hydration).
  static const String autoExecuteFlagKey = '_voice_auto_execute';

  /// Sentinel key: the exact Gemini-classified tool string (e.g.
  /// 'pdf_to_word') so a single destination page that covers several
  /// directions (e.g. ConvertToolPage) can tell which one was requested.
  static const String voiceToolKey = '_voice_tool';

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

  // --- Live transcription (Web Speech API), run in parallel with the audio
  // recording above so the UI can show live captions AND the backend can
  // attempt a zero-latency local intent match before ever calling Gemini.
  // No typed dart:js_interop bindings exist for SpeechRecognition (it is
  // non-standard), so this reuses the same proven "JS eval + postMessage
  // bridge" pattern already used elsewhere in this app (Google Sign-In,
  // Razorpay checkout).
  final StreamController<String> _liveTranscriptController = StreamController<String>.broadcast();

  /// Emits the best-effort combined (final + interim) transcript text as the
  /// user speaks. Widgets may subscribe to show live captions; this is best
  /// effort only (empty stream on browsers without SpeechRecognition support).
  Stream<String> get liveTranscriptStream => _liveTranscriptController.stream;

  String _sttToken = '';
  StreamSubscription<html.MessageEvent>? _sttSubscription;
  String _sttFinalTranscript = '';
  String _sttInterimTranscript = '';

  String get _combinedSttTranscript => ('$_sttFinalTranscript $_sttInterimTranscript').trim();

  Map<String, dynamic>? _decodeBridgeMessage(dynamic data) {
    dynamic normalized = data;
    if (normalized is String) {
      final candidate = normalized.trim();
      if (candidate.isEmpty) {
        return null;
      }
      try {
        normalized = jsonDecode(candidate);
      } catch (_) {
        return null;
      }
    }
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    try {
      final dartified = (normalized as JSAny?).dartify();
      if (dartified is Map) {
        return Map<String, dynamic>.from(dartified);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _startLiveTranscription() {
    _sttFinalTranscript = '';
    _sttInterimTranscript = '';
    final token = 'stt_${DateTime.now().microsecondsSinceEpoch}';
    _sttToken = token;

    _sttSubscription?.cancel();
    _sttSubscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) return;
      if (data['source'] != 'jobready_stt' || data['token'] != token) return;

      final type = data['type'] as String?;
      if (type == 'transcript') {
        final finalText = (data['finalText'] as String?) ?? '';
        final interimText = (data['interimText'] as String?) ?? '';
        if (finalText.isNotEmpty) {
          _sttFinalTranscript = ('$_sttFinalTranscript $finalText').trim();
        }
        _sttInterimTranscript = interimText;
        if (!_liveTranscriptController.isClosed) {
          _liveTranscriptController.add(_combinedSttTranscript);
        }
      }
      // 'unavailable' / 'error' / 'end' types are silently ignored here -
      // live captions are a best-effort enhancement, not a hard requirement,
      // and Gemini remains the fallback classifier regardless.
    });

    final script =
        '''
(function() {
  var Ctor = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Ctor) {
    window.postMessage({ source: 'jobready_stt', token: '$token', type: 'unavailable' }, window.location.origin);
    return;
  }
  try {
    var recognition = new Ctor();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = 'en-IN';
    window.__jobreadySttInstances = window.__jobreadySttInstances || {};
    window.__jobreadySttInstances['$token'] = recognition;

    recognition.onresult = function (event) {
      var finalText = '';
      var interimText = '';
      for (var i = event.resultIndex; i < event.results.length; i++) {
        var result = event.results[i];
        if (result.isFinal) {
          finalText += result[0].transcript;
        } else {
          interimText += result[0].transcript;
        }
      }
      window.postMessage({
        source: 'jobready_stt',
        token: '$token',
        type: 'transcript',
        finalText: finalText,
        interimText: interimText
      }, window.location.origin);
    };

    recognition.onerror = function (event) {
      window.postMessage({ source: 'jobready_stt', token: '$token', type: 'error', error: (event && event.error) || 'unknown' }, window.location.origin);
    };

    recognition.onend = function () {
      window.postMessage({ source: 'jobready_stt', token: '$token', type: 'end' }, window.location.origin);
    };

    recognition.start();
  } catch (e) {
    window.postMessage({ source: 'jobready_stt', token: '$token', type: 'error', error: 'start_failed' }, window.location.origin);
  }
})();
''';
    try {
      js.context.callMethod('eval', [script]);
    } catch (_) {
      // Ignore - live captions/local matching are best-effort only.
    }
  }

  void _stopLiveTranscription() {
    if (_sttToken.isEmpty) {
      return;
    }
    final token = _sttToken;
    final script =
        '''
(function() {
  var instances = window.__jobreadySttInstances;
  var recognition = instances && instances['$token'];
  if (recognition) {
    try { recognition.stop(); } catch (e) {}
    delete instances['$token'];
  }
})();
''';
    try {
      js.context.callMethod('eval', [script]);
    } catch (_) {
      // ignore
    }
    _sttSubscription?.cancel();
    _sttSubscription = null;
    _sttToken = '';
  }

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
      _startLiveTranscription();
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

    // Give the speech recognizer a brief moment to flush its final result
    // event (it fires asynchronously, shortly after recognition.stop()).
    final transcriptHint = _combinedSttTranscript;
    _stopLiveTranscription();

    if (_chunks.isEmpty) {
      return VoiceCommandResult.failure('No audio captured. Please try again.');
    }

    try {
      final parts = <JSAny>[for (final chunk in _chunks) chunk].toJS;
      final blob = web.Blob(parts, web.BlobPropertyBag(type: _mimeType));
      final bytes = await _blobToBytes(blob);
      return _uploadAndClassify(bytes, transcriptHint: transcriptHint);
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
    _stopLiveTranscription();
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

  Future<VoiceCommandResult> _uploadAndClassify(Uint8List bytes, {String transcriptHint = ''}) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base/api/voice-command');

      final isOgg = _mimeType.contains('ogg');
      final isMp4 = _mimeType.contains('mp4');
      final extension = isOgg ? 'ogg' : (isMp4 ? 'm4a' : 'webm');
      final audioSubtype = isOgg ? 'ogg' : (isMp4 ? 'mp4' : 'webm');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: 'voice_command.$extension',
          contentType: MediaType('audio', audioSubtype),
        ));
      if (transcriptHint.trim().isNotEmpty) {
        request.fields['transcript_hint'] = transcriptHint.trim();
      }

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
