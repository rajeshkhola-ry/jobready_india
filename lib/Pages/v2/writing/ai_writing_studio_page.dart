import 'package:flutter/material.dart';

import '../../../Services/ai_service.dart';

class AiWritingStudioPage extends StatefulWidget {
  const AiWritingStudioPage({super.key});

  @override
  State<AiWritingStudioPage> createState() => _AiWritingStudioPageState();
}

class _AiWritingStudioPageState extends State<AiWritingStudioPage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  String _selectedMode = 'Cover letter';
  String _selectedTone = 'Professional';
  WritingResponse? _latestResponse;

  static const List<String> _modes = [
    'Cover letter',
    'Email',
    'SOP',
    'Job application',
    'Rewrite',
  ];

  static const List<String> _tones = [
    'Professional',
    'Friendly',
    'Formal',
    'Concise',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  void _generateDraft() {
    final prompt = _inputController.text.trim();
    final context = _contextController.text.trim();

    setState(() {
      _latestResponse = AiService.generateWritingDraft(
        mode: _selectedMode,
        tone: _selectedTone,
        prompt: prompt,
        contextNote: context,
      );
    });
  }

  void _fillSample() {
    setState(() {
      _inputController.text = 'I am applying for an operations role and want a short, convincing cover letter.';
      _contextController.text = 'Highlight attention to detail, document handling, and process improvement.';
      _selectedMode = 'Cover letter';
      _selectedTone = 'Professional';
    });
    _generateDraft();
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }

  Widget _choiceRow({required String label, required List<String> values, required String selectedValue, required ValueChanged<String> onSelected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: value == selectedValue,
                  onSelected: (_) => onSelected(value),
                  selectedColor: const Color(0xFFDBEAFE),
                  labelStyle: TextStyle(
                    color: value == selectedValue ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _draftPreview() {
    final response = _latestResponse;
    if (response == null) {
      return _panel(
        child: const Text(
          'Write a prompt and generate a V2 writing draft to see the preview here.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            response.draft,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          ...response.suggestions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 AI Writing Studio'),
        backgroundColor: const Color(0xFF0E3A66),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panel(
                      child: const Text(
                        'The writing studio is the next V2 module after AI assistant and resume builder. It focuses on practical career writing: email drafts, cover letters, SOPs, and rewrites.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;

                        final editor = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _choiceRow(
                                    label: 'Writing mode',
                                    values: _modes,
                                    selectedValue: _selectedMode,
                                    onSelected: (value) => setState(() => _selectedMode = value),
                                  ),
                                  const SizedBox(height: 14),
                                  _choiceRow(
                                    label: 'Tone',
                                    values: _tones,
                                    selectedValue: _selectedTone,
                                    onSelected: (value) => setState(() => _selectedTone = value),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Draft prompt',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _inputController,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      hintText: 'Tell the studio what to write or rewrite',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Optional context',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _contextController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: 'Add keywords, job title, company style, or constraints',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _generateDraft,
                                        icon: const Icon(Icons.auto_awesome_rounded),
                                        label: const Text('Generate Draft'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _fillSample,
                                        icon: const Icon(Icons.auto_fix_high_rounded),
                                        label: const Text('Fill Sample'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.home_outlined),
                                        label: const Text('Back to V2 Home'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final preview = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: const Text(
                                'Output from this first version is local and structured. Later V2 work can add richer language support and job-description awareness.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _draftPreview(),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: editor),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: preview),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            editor,
                            const SizedBox(height: 16),
                            preview,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
