import 'package:flutter/material.dart';

class AcademicToolkitPage extends StatefulWidget {
  const AcademicToolkitPage({super.key});

  @override
  State<AcademicToolkitPage> createState() => _AcademicToolkitPageState();
}

class _AcademicToolkitPageState extends State<AcademicToolkitPage> {
  final TextEditingController _profileController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedDoc = 'SOP';
  String _selectedTone = 'Formal';
  String _generatedDraft = '';

  static const List<String> _docTypes = <String>[
    'SOP',
    'LOR',
    'Research Proposal',
    'Scholarship Letter',
  ];

  static const List<String> _tones = <String>[
    'Formal',
    'Professional',
    'Concise',
    'Academic',
  ];

  @override
  void dispose() {
    _profileController.dispose();
    _goalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillSample() {
    setState(() {
      _profileController.text =
          'Final year engineering student with internship experience in document process automation and reporting.';
      _goalController.text =
          'Seeking admission to a masters program in data analytics and operations.';
      _notesController.text =
          'Highlight consistency, project ownership, and measurable outcomes from final-year project.';
    });
  }

  void _generateDraft() {
    final profile = _profileController.text.trim();
    final goal = _goalController.text.trim();
    final notes = _notesController.text.trim();

    String opening;
    String body;
    String closing;

    switch (_selectedDoc) {
      case 'LOR':
        opening = 'To Whom It May Concern,';
        body =
            'I am pleased to recommend the applicant. ${profile.isEmpty ? 'The candidate has demonstrated reliability and strong academic commitment.' : profile} ${goal.isEmpty ? '' : 'The applicant is pursuing: $goal.'}';
        closing =
            '${notes.isEmpty ? 'I strongly support this application based on demonstrated discipline and growth.' : notes}\n\nSincerely,';
        break;
      case 'Research Proposal':
        opening = 'Research Proposal Draft';
        body =
            'Background: ${profile.isEmpty ? 'The topic addresses an important practical and academic challenge.' : profile}\n\nObjective: ${goal.isEmpty ? 'Define a measurable objective and expected research contribution.' : goal}';
        closing =
            'Method and expected outcomes can be expanded in the next iteration. ${notes.isEmpty ? '' : notes}';
        break;
      case 'Scholarship Letter':
        opening = 'Scholarship Application Letter';
        body =
            'I respectfully submit my application for scholarship consideration. ${profile.isEmpty ? '' : profile} ${goal.isEmpty ? '' : 'My academic goal is: $goal.'}';
        closing =
            '${notes.isEmpty ? 'Thank you for reviewing my profile and potential.' : notes}\n\nRegards,';
        break;
      case 'SOP':
      default:
        opening = 'Statement of Purpose';
        body =
            '${profile.isEmpty ? 'I am applying with a strong motivation to grow through structured academic learning and practical work.' : profile}\n\n${goal.isEmpty ? 'My objective is to build domain expertise and contribute through high-quality outcomes.' : goal}';
        closing =
            '${notes.isEmpty ? 'I am committed to consistent progress, research curiosity, and meaningful contribution.' : notes}';
        break;
    }

    setState(() {
      _generatedDraft =
          '$opening\n\nTone: $_selectedTone\n\n$body\n\n$closing';
    });
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 3,
  }) {
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
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: const Color(0xFFF8FBFF),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Academic Toolkit'),
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
                        'Academic Toolkit helps prepare SOP, LOR, research proposal, and scholarship drafts with a structured workflow.',
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
                                  const Text(
                                    'Document Type',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _docTypes
                                        .map(
                                          (type) => ChoiceChip(
                                            label: Text(type),
                                            selected: _selectedDoc == type,
                                            onSelected: (_) => setState(() => _selectedDoc = type),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tone',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _tones
                                        .map(
                                          (tone) => ChoiceChip(
                                            label: Text(tone),
                                            selected: _selectedTone == tone,
                                            onSelected: (_) => setState(() => _selectedTone = tone),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _field(
                                    label: 'Academic profile',
                                    controller: _profileController,
                                    hint: 'Add your background, achievements, and relevant experience',
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    label: 'Goal statement',
                                    controller: _goalController,
                                    hint: 'Add your target program, specialization, or objective',
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    label: 'Additional notes',
                                    controller: _notesController,
                                    hint: 'Mention constraints, highlights, or tone expectations',
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

                        final preview = _panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Generated Draft',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _generatedDraft.isEmpty
                                    ? 'Generate a draft to preview the output here.'
                                    : _generatedDraft,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
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
