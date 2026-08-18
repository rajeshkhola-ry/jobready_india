import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:web/web.dart' as web;

import 'api_config.dart';

/// Result of a single recorded interview answer + Gemini evaluation round trip.
class InterviewEvaluationResult {
  final bool success;
  final String transcript;
  final int clarity;
  final int confidence;
  final int content;
  final double overallScore;
  final String feedback;
  final String? error;

  const InterviewEvaluationResult({
    required this.success,
    this.transcript = '',
    this.clarity = 0,
    this.confidence = 0,
    this.content = 0,
    this.overallScore = 0,
    this.feedback = '',
    this.error,
  });

  factory InterviewEvaluationResult.failure(String message) =>
      InterviewEvaluationResult(success: false, error: message);
}

/// Speaks interview questions aloud (Web Speech Synthesis API), records a
/// short spoken answer from the browser microphone, and sends it to the
/// backend (POST /api/voice-interview-evaluate) for Gemini-based
/// Clarity/Confidence/Content scoring.
///
/// Mirrors [VoiceCommandService]'s proven `package:web` + `dart:js_interop`
/// MediaRecorder pattern (this project's SDK has no working `dart:js_util`/
/// `allowInterop`), but is kept as its own dedicated service since interview
/// scoring is unrelated to voice-command tool classification.
class VoiceInterviewService {
  VoiceInterviewService._();
  static final VoiceInterviewService instance = VoiceInterviewService._();

  static const int maxRecordingSeconds = 20;

  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  final List<web.Blob> _chunks = [];
  String _mimeType = 'audio/webm';

  /// Speaks [text] aloud via the browser's Web Speech Synthesis API. No
  /// typed `dart:js_interop` bindings are relied on here (same reasoning as
  /// the SpeechRecognition bridge in `voice_command_service.dart`) - silently
  /// does nothing on unsupported browsers, never throws.
  void speak(String text) {
    final safeText = text.replaceAll('\\', r'\\').replaceAll("'", r"\'").replaceAll('\n', ' ');
    final script = '''
(function() {
  try {
    if (!window.speechSynthesis) { return; }
    window.speechSynthesis.cancel();
    var utterance = new SpeechSynthesisUtterance('$safeText');
    utterance.rate = 0.98;
    utterance.pitch = 1.0;
    window.speechSynthesis.speak(utterance);
  } catch (e) {}
})();
''';
    try {
      js.context.callMethod('eval', [script]);
    } catch (_) {
      // TTS is a nice-to-have - never block the practice flow.
    }
  }

  /// Stops any in-progress speech immediately (e.g. user taps the mic while
  /// the question is still being read aloud).
  void stopSpeaking() {
    const script = '''
(function() {
  try { if (window.speechSynthesis) { window.speechSynthesis.cancel(); } } catch (e) {}
})();
''';
    try {
      js.context.callMethod('eval', [script]);
    } catch (_) {
      // ignore
    }
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

  /// Stops recording, uploads the captured audio for the given [question]/
  /// [roleCategory] context, and returns the Gemini-scored evaluation (or a
  /// failure result).
  Future<InterviewEvaluationResult> stopRecordingAndEvaluate({
    required String question,
    required String roleCategory,
  }) async {
    final recorder = _mediaRecorder;
    if (recorder == null) {
      return InterviewEvaluationResult.failure('Recording was not started.');
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
      return InterviewEvaluationResult.failure('No audio captured. Please try again.');
    }

    try {
      final parts = <JSAny>[for (final chunk in _chunks) chunk].toJS;
      final blob = web.Blob(parts, web.BlobPropertyBag(type: _mimeType));
      final bytes = await _blobToBytes(blob);
      return await _uploadAndEvaluate(bytes, question: question, roleCategory: roleCategory);
    } catch (_) {
      return InterviewEvaluationResult.failure('Could not process the recording. Please try again.');
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

  Future<InterviewEvaluationResult> _uploadAndEvaluate(
    Uint8List bytes, {
    required String question,
    required String roleCategory,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base/api/voice-interview-evaluate');

      final isOgg = _mimeType.contains('ogg');
      final isMp4 = _mimeType.contains('mp4');
      final extension = isOgg ? 'ogg' : (isMp4 ? 'm4a' : 'webm');
      final audioSubtype = isOgg ? 'ogg' : (isMp4 ? 'mp4' : 'webm');
      final request = http.MultipartRequest('POST', uri)
        ..fields['question'] = question
        ..fields['roleCategory'] = roleCategory
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: 'interview_answer.$extension',
          contentType: MediaType('audio', audioSubtype),
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return InterviewEvaluationResult.failure('Evaluation service returned an unreadable response.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        return InterviewEvaluationResult.failure(
          (decoded['error'] as String?) ?? 'Could not evaluate that answer. Please try again.',
        );
      }

      return InterviewEvaluationResult(
        success: true,
        transcript: (decoded['transcript'] as String?) ?? '',
        clarity: (decoded['clarity'] as num?)?.toInt() ?? 0,
        confidence: (decoded['confidence'] as num?)?.toInt() ?? 0,
        content: (decoded['content'] as num?)?.toInt() ?? 0,
        overallScore: (decoded['overallScore'] as num?)?.toDouble() ?? 0,
        feedback: (decoded['feedback'] as String?) ?? '',
      );
    } on TimeoutException {
      return InterviewEvaluationResult.failure('Evaluation timed out. Please check your connection.');
    } catch (_) {
      return InterviewEvaluationResult.failure('Could not reach the evaluation service.');
    }
  }
}
