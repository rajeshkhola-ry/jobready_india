import 'dart:async';

import 'package:flutter/material.dart';

import '../Services/voice_interview_service.dart';
import '../Services/voice_quota_service.dart';
import '../Widgets/global_language_banner.dart';

enum _InterviewStage {
  roleSelection,
  ready,
  recording,
  evaluating,
  feedback,
  quotaBlocked,
  completed,
}

/// Dedicated "AI Voice Mock Interview Practice" tool page: pick a target
/// role/category, then practice a short 3-question voice interview session
/// with browser text-to-speech questions, a 20s voice-recorded answer per
/// question, and Gemini-scored Clarity/Confidence/Content feedback.
class VoiceInterviewPage extends StatefulWidget {
  const VoiceInterviewPage({super.key});

  @override
  State<VoiceInterviewPage> createState() => _VoiceInterviewPageState();
}

class _VoiceInterviewPageState extends State<VoiceInterviewPage> with SingleTickerProviderStateMixin {
  static const List<String> _categories = [
    'SSC / Govt',
    'Banking / Finance',
    'Software Engineer',
    'HR / General',
    'Customer Support',
  ];

  static const Map<String, List<String>> _questionBank = {
    'SSC / Govt': [
      'Why do you want to work in a government or public sector role?',
      'How do you stay updated with current affairs and government schemes?',
      'Describe a time you handled a stressful situation while following strict rules or procedures.',
      'What does public service mean to you?',
      'How would you handle a difficult citizen or applicant at your counter?',
    ],
    'Banking / Finance': [
      'Why do you want to work in the banking or finance sector?',
      'How would you explain a complex financial product to a customer with no finance background?',
      'Tell me about a time you had to handle a customer complaint about money or a transaction.',
      'How do you stay accurate and careful when working with numbers under time pressure?',
      'What do you know about KYC and why is it important for banks?',
    ],
    'Software Engineer': [
      'Walk me through a project you are proud of and the technical challenges you solved.',
      'How do you approach debugging a problem you have never seen before?',
      'Tell me about a time you disagreed with a teammate about a technical decision.',
      'How do you keep your code quality high while working under deadlines?',
      'Describe how you would explain a technical concept to a non-technical stakeholder.',
    ],
    'HR / General': [
      'Tell me about yourself and why you are a good fit for this role.',
      'Describe a challenge you faced at work or college and how you overcame it.',
      'Where do you see yourself in the next five years?',
      'How do you handle feedback or criticism from a manager?',
      'Tell me about a time you worked successfully as part of a team.',
    ],
    'Customer Support': [
      'How would you handle an angry customer who is not satisfied with your answer?',
      'Tell me about a time you turned a negative customer experience into a positive one.',
      'How do you prioritize multiple customer requests at the same time?',
      'What does great customer service mean to you?',
      'Describe a time you had to explain a policy the customer did not want to hear.',
    ],
  };

  final VoiceInterviewService _service = VoiceInterviewService.instance;
  late final AnimationController _pulseController;

  _InterviewStage _stage = _InterviewStage.roleSelection;
  String? _selectedCategory;
  List<String> _sessionQuestions = const [];
  int _currentQuestionIndex = 0;
  int _secondsRemaining = VoiceInterviewService.maxRecordingSeconds;
  Timer? _countdownTimer;
  InterviewEvaluationResult? _currentFeedback;
  final List<InterviewEvaluationResult> _completedResults = [];
  String? _errorMessage;

  bool get _isFirstQuestion => _currentQuestionIndex == 0;

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
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _service.stopSpeaking();
    if (_stage == _InterviewStage.recording) {
      _service.cancelRecording();
    }
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  void _startSession() {
    final category = _selectedCategory;
    if (category == null) return;
    final bank = List<String>.from(_questionBank[category] ?? const <String>[])..shuffle();
    setState(() {
      _sessionQuestions = bank.take(3).toList();
      _currentQuestionIndex = 0;
      _completedResults.clear();
      _currentFeedback = null;
      _errorMessage = null;
      _stage = _InterviewStage.ready;
    });
    _speakCurrentQuestion();
  }

  void _speakCurrentQuestion() {
    if (_currentQuestionIndex < _sessionQuestions.length) {
      _service.speak(_sessionQuestions[_currentQuestionIndex]);
    }
  }

  Future<void> _startRecording() async {
    if (!_isFirstQuestion && !VoiceQuotaService.canUseVoiceCommand()) {
      setState(() => _stage = _InterviewStage.quotaBlocked);
      return;
    }

    _service.stopSpeaking();
    final started = await _service.startRecording();
    if (!mounted) return;

    if (!started) {
      setState(() {
        _errorMessage = 'Microphone access is unavailable. Please allow mic permission and try again.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _stage = _InterviewStage.recording;
      _secondsRemaining = VoiceInterviewService.maxRecordingSeconds;
    });
    _pulseController.repeat(reverse: true);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining -= 1);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _countdownTimer?.cancel();
    _pulseController.stop();
    if (!mounted) return;
    setState(() => _stage = _InterviewStage.evaluating);

    final question = _sessionQuestions[_currentQuestionIndex];
    final result = await _service.stopRecordingAndEvaluate(
      question: question,
      roleCategory: _selectedCategory ?? 'General',
    );
    if (!mounted) return;

    if (result.success) {
      await VoiceQuotaService.recordUsage();
      setState(() {
        _currentFeedback = result;
        _completedResults.add(result);
        _stage = _InterviewStage.feedback;
      });
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Could not evaluate that answer. Please try again.';
        _stage = _InterviewStage.ready;
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex + 1 >= _sessionQuestions.length) {
      setState(() => _stage = _InterviewStage.completed);
      return;
    }
    setState(() {
      _currentQuestionIndex += 1;
      _currentFeedback = null;
      _stage = _InterviewStage.ready;
    });
    _speakCurrentQuestion();
  }

  void _restart() {
    _service.stopSpeaking();
    setState(() {
      _stage = _InterviewStage.roleSelection;
      _selectedCategory = null;
      _sessionQuestions = const [];
      _currentQuestionIndex = 0;
      _completedResults.clear();
      _currentFeedback = null;
      _errorMessage = null;
    });
  }

  double get _averageScore {
    if (_completedResults.isEmpty) return 0;
    final total = _completedResults.fold<double>(0, (sum, r) => sum + r.overallScore);
    return total / _completedResults.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('AI Voice Mock Interview Practice'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(),
                  const SizedBox(height: 20),
                  const GlobalLanguageBanner(),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _buildStageContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D74D8)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Voice Mock Interview Practice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Practice real-time job interview questions with instant voice feedback.',
            style: TextStyle(
              color: Color(0xFFDCE6F5),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (_stage != _InterviewStage.roleSelection) ...[
            const SizedBox(height: 10),
            Text(
              'Voice quota remaining: ${VoiceQuotaService.remainingLabel()}',
              style: const TextStyle(
                color: Color(0xFFDCE6F5),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _InterviewStage.roleSelection:
        return _buildRoleSelection();
      case _InterviewStage.ready:
      case _InterviewStage.recording:
        return _buildQuestionCard();
      case _InterviewStage.evaluating:
        return _buildEvaluating();
      case _InterviewStage.feedback:
        return _buildFeedback();
      case _InterviewStage.quotaBlocked:
        return _buildQuotaBlocked();
      case _InterviewStage.completed:
        return _buildCompleted();
    }
  }

  Widget _buildRoleSelection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your target role/category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _categories)
                ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (_) => _selectCategory(category),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _selectedCategory == category ? Colors.white : const Color(0xFF1F2937),
                  ),
                  selectedColor: const Color(0xFF1D74D8),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide(color: _selectedCategory == category ? const Color(0xFF1D74D8) : const Color(0xFFD1D5DB)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedCategory == null ? null : _startSession,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start 3-Question Practice Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D74D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Free plan: try 1 sample question live. Paid plans: full 3-question session using your voice quota.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final isRecording = _stage == _InterviewStage.recording;
    final question = _currentQuestionIndex < _sessionQuestions.length
        ? _sessionQuestions[_currentQuestionIndex]
        : '';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_sessionQuestions.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D74D8)),
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.35),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _service.speak(question),
            icon: const Icon(Icons.volume_up_rounded, size: 18),
            label: const Text('Repeat Question'),
          ),
          const SizedBox(height: 10),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: isRecording ? _stopRecording : _startRecording,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = isRecording ? 1.0 + (_pulseController.value * 0.18) : 1.0;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: isRecording ? const Color(0xFFDC2626) : const Color(0xFF1D74D8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRecording
                      ? 'Recording... $_secondsRemaining s left (tap to stop)'
                      : 'Tap the mic and speak your answer (max 20s)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluating() {
    return _card(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF1D74D8)),
              SizedBox(height: 14),
              Text(
                'Evaluating your answer...',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final feedback = _currentFeedback;
    if (feedback == null) {
      return const SizedBox.shrink();
    }
    final isLastQuestion = _currentQuestionIndex + 1 >= _sessionQuestions.length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Feedback',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _scorePill('Clarity', feedback.clarity),
              const SizedBox(width: 8),
              _scorePill('Confidence', feedback.confidence),
              const SizedBox(width: 8),
              _scorePill('Content', feedback.content),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              feedback.feedback.isNotEmpty ? feedback.feedback : 'Good attempt - keep practicing for more confident, detailed delivery.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nextQuestion,
              icon: Icon(isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded),
              label: Text(isLastQuestion ? 'Finish Session' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scorePill(String label, int score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          children: [
            Text(
              '$score/10',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1D74D8)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaBlocked() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309), size: 22),
              SizedBox(width: 8),
              Text(
                'Voice Quota Depleted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            VoiceQuotaService.blockedReasonMessage().isNotEmpty
                ? VoiceQuotaService.blockedReasonMessage()
                : 'You have used your available voice commands. Upgrade your plan or purchase a top-up pack to continue this practice session.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/pricing'),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Upgrade Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D74D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_completedResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _stage = _InterviewStage.completed),
                child: const Text('View Score Summary So Far'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleted() {
    final average = _averageScore;
    final summaryLabel = average >= 8
        ? 'Excellent work!'
        : average >= 6
            ? 'Great effort - keep practicing!'
            : average > 0
                ? 'Good start - practice builds confidence!'
                : 'Session ended';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Complete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Text(
            summaryLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  average > 0 ? average.toStringAsFixed(1) : '-',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF1D74D8)),
                ),
                const Text(
                  'Overall Score (out of 10)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_completedResults.length} of ${_sessionQuestions.length} questions answered',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/pdf-tools'),
              icon: const Icon(Icons.build_rounded),
              label: const Text('Try Document Tools'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D74D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/pricing'),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Upgrade Plan'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _restart,
              child: const Text('Practice Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
