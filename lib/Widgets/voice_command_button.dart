import 'dart:async';

import 'package:flutter/material.dart';

import '../Services/voice_command_service.dart';
import '../Services/voice_quota_service.dart';

enum _VoiceButtonState { idle, listening, processing }

/// Animated microphone button for the homepage drop-zone.
///
/// Tap to start a short (auto-stops after [maxRecordingSeconds]) voice
/// recording, which is sent to the backend for Gemini Flash classification.
/// The raw [VoiceCommandResult] (success or failure) is always handed back
/// via [onResult] - this widget only owns the recording/animation UI, the
/// caller decides what to do with the result (navigate, show an error, etc).
class VoiceCommandButton extends StatefulWidget {
  const VoiceCommandButton({
    super.key,
    required this.onResult,
    this.onListeningChanged,
    this.onLiveTranscript,
    this.maxRecordingSeconds = 5,
  });

  final ValueChanged<VoiceCommandResult> onResult;

  /// Called with `true` when recording starts and `false` when it stops, so
  /// the caller can drive its own UI (e.g. a hint-text listening animation).
  final ValueChanged<bool>? onListeningChanged;

  /// Called with the live (best-effort) Web Speech API transcript text as
  /// the user speaks, so the caller can show a "did I hear you right" live
  /// caption. May never fire on browsers without SpeechRecognition support.
  final ValueChanged<String>? onLiveTranscript;
  final int maxRecordingSeconds;

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with SingleTickerProviderStateMixin {
  final VoiceCommandService _service = VoiceCommandService.instance;
  late final AnimationController _pulseController;
  _VoiceButtonState _state = _VoiceButtonState.idle;
  Timer? _autoStopTimer;
  StreamSubscription<String>? _liveTranscriptSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _liveTranscriptSubscription?.cancel();
    _pulseController.dispose();
    if (_state == _VoiceButtonState.listening) {
      _service.cancelRecording();
      widget.onListeningChanged?.call(false);
    }
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_state == _VoiceButtonState.processing) return;
    if (_state == _VoiceButtonState.listening) {
      await _stopAndClassify();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!VoiceQuotaService.canUseVoiceCommand()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(VoiceQuotaService.blockedReasonMessage()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final started = await _service.startRecording();
    if (!mounted) return;

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone access is unavailable. Please allow mic permission and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _state = _VoiceButtonState.listening);
    widget.onListeningChanged?.call(true);
    _liveTranscriptSubscription?.cancel();
    if (widget.onLiveTranscript != null) {
      _liveTranscriptSubscription = _service.liveTranscriptStream.listen(widget.onLiveTranscript);
    }
    _pulseController.repeat(reverse: true);
    _autoStopTimer = Timer(Duration(seconds: widget.maxRecordingSeconds), () {
      if (_state == _VoiceButtonState.listening) {
        _stopAndClassify();
      }
    });
  }

  Future<void> _stopAndClassify() async {
    _autoStopTimer?.cancel();
    _liveTranscriptSubscription?.cancel();
    _liveTranscriptSubscription = null;
    _pulseController.stop();
    if (!mounted) return;
    setState(() => _state = _VoiceButtonState.processing);
    widget.onListeningChanged?.call(false);

    final result = await _service.stopRecordingAndClassify();
    if (!mounted) return;

    if (result.success) {
      await VoiceQuotaService.recordUsage();
    }

    setState(() => _state = _VoiceButtonState.idle);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _state == _VoiceButtonState.listening;
    final isProcessing = _state == _VoiceButtonState.processing;

    return Tooltip(
      message: isListening
          ? 'Tap to stop and send voice command'
          : 'Tap and speak a command, e.g. "Compress this to 50 KB"',
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 56,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isListening)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.45);
                    final opacity = 1.0 - _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isListening ? const Color(0xFFDC2626) : const Color(0xFFEAF3FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isListening ? const Color(0xFFDC2626) : const Color(0xFFD5E2F2),
                  ),
                ),
                child: isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF123A63)),
                        ),
                      )
                    : Icon(
                        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 20,
                        color: isListening ? Colors.white : const Color(0xFF1F4E79),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
