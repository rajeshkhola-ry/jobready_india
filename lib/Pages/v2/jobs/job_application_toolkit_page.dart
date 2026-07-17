import 'package:flutter/material.dart';

class JobApplicationToolkitPage extends StatefulWidget {
  const JobApplicationToolkitPage({super.key});

  @override
  State<JobApplicationToolkitPage> createState() => _JobApplicationToolkitPageState();
}

class _JobApplicationToolkitPageState extends State<JobApplicationToolkitPage> {
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobDescriptionController = TextEditingController();
  final TextEditingController _resumeSummaryController = TextEditingController();

  int _matchScore = 0;
  List<String> _strengths = const [];
  List<String> _gaps = const [];
  List<String> _interviewQuestions = const [];

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _jobDescriptionController.dispose();
    _resumeSummaryController.dispose();
    super.dispose();
  }

  void _fillSample() {
    setState(() {
      _jobTitleController.text = 'Operations Specialist';
      _companyController.text = 'Global Cargo Services';
      _jobDescriptionController.text =
          'Looking for someone with document control, reporting, stakeholder communication, and process improvement experience.';
      _resumeSummaryController.text =
          '4+ years handling document workflows, client communication, and process optimization. Strong Excel and reporting background.';
    });
  }

  void _analyzeMatch() {
    final jd = _jobDescriptionController.text.toLowerCase();
    final resume = _resumeSummaryController.text.toLowerCase();

    const keywords = [
      'document',
      'report',
      'communication',
      'process',
      'excel',
      'analysis',
      'team',
      'stakeholder',
    ];

    final matched = keywords.where((k) => jd.contains(k) && resume.contains(k)).toList(growable: false);
    final missing = keywords.where((k) => jd.contains(k) && !resume.contains(k)).toList(growable: false);

    final score = ((matched.length / keywords.length) * 100).round().clamp(20, 98);

    final role = _jobTitleController.text.trim().isEmpty ? 'this role' : _jobTitleController.text.trim();

    setState(() {
      _matchScore = score;
      _strengths = matched.isEmpty
          ? ['Your resume summary is concise and usable as a base draft.']
          : matched.map((m) => 'Strong alignment on $m for $role.').toList(growable: false);
      _gaps = missing.isEmpty
          ? ['No major keyword gaps found from this quick scan.']
          : missing.map((m) => 'Add evidence for $m in your resume or cover letter.').toList(growable: false);
      _interviewQuestions = [
        'How have you handled high-volume document workflows in previous roles?',
        'Describe a process improvement you delivered and its impact.',
        'How do you ensure reporting accuracy under tight timelines?',
        'How would you prioritize competing stakeholder requests?',
      ];
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
    int maxLines = 1,
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

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
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
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Job Application Toolkit'),
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
                        'This toolkit helps you match your resume with a target role, identify gaps, and prepare interview questions before you apply.',
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

                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _field(
                                    label: 'Job title',
                                    controller: _jobTitleController,
                                    hint: 'Example: Operations Specialist',
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    label: 'Company',
                                    controller: _companyController,
                                    hint: 'Example: Global Cargo Services',
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    label: 'Job description highlights',
                                    controller: _jobDescriptionController,
                                    hint: 'Paste key requirements here',
                                    maxLines: 5,
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    label: 'Your resume summary',
                                    controller: _resumeSummaryController,
                                    hint: 'Paste your current resume summary',
                                    maxLines: 5,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _analyzeMatch,
                                        icon: const Icon(Icons.analytics_outlined),
                                        label: const Text('Analyze Match'),
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

                        final right = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Role Match Score',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: _matchScore / 100,
                                    minHeight: 10,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$_matchScore% estimated alignment',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D4ED8),
                                    ),
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
                                    'Strengths',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _bulletList(_strengths.isEmpty ? const ['Run analysis to see strength areas.'] : _strengths),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Gaps To Improve',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _bulletList(_gaps.isEmpty ? const ['Run analysis to identify missing points.'] : _gaps),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Interview Prep Questions',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _bulletList(_interviewQuestions.isEmpty
                                      ? const ['Run analysis to generate targeted interview questions.']
                                      : _interviewQuestions),
                                ],
                              ),
                            ),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: left),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: right),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [left, const SizedBox(height: 16), right],
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
