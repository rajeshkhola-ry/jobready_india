import 'package:flutter/material.dart';

class ResumeWorkspacePage extends StatefulWidget {
  const ResumeWorkspacePage({super.key});

  @override
  State<ResumeWorkspacePage> createState() => _ResumeWorkspacePageState();
}

class _ResumeWorkspacePageState extends State<ResumeWorkspacePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _achievementController = TextEditingController();

  final List<String> _skills = <String>['Excel', 'Reporting', 'Documentation'];
  final List<String> _achievements = <String>[
    'Reduced manual processing time by 30%',
    'Supported cross-team issue resolution',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    _skillController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('V2 resume draft saved locally.')),
    );
  }

  void _fillSample() {
    setState(() {
      _nameController.text = 'Aarav Mehta';
      _titleController.text = 'Operations and Document Specialist';
      _locationController.text = 'Mumbai, India';
      _summaryController.text =
          'Organized operations professional with experience in document handling, workflow support, and client coordination. Focused on accuracy, speed, and structured delivery.';
      if (!_skills.contains('Workflow Planning')) {
        _skills.add('Workflow Planning');
      }
      if (!_achievements.contains('Improved response time across shared inbox workflows')) {
        _achievements.add('Improved response time across shared inbox workflows');
      }
    });
  }

  void _resetDraft() {
    setState(() {
      _nameController.clear();
      _titleController.clear();
      _locationController.clear();
      _summaryController.clear();
      _skillController.clear();
      _achievementController.clear();
      _skills
        ..clear()
        ..addAll(<String>['Excel', 'Reporting', 'Documentation']);
      _achievements
        ..clear()
        ..addAll(<String>[
          'Reduced manual processing time by 30%',
          'Supported cross-team issue resolution',
        ]);
    });
  }

  void _addSkill() {
    final value = _skillController.text.trim();
    if (value.isEmpty || _skills.contains(value)) {
      return;
    }

    setState(() {
      _skills.add(value);
      _skillController.clear();
    });
  }

  void _addAchievement() {
    final value = _achievementController.text.trim();
    if (value.isEmpty || _achievements.contains(value)) {
      return;
    }

    setState(() {
      _achievements.add(value);
      _achievementController.clear();
    });
  }

  Widget _fieldCard({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF8FBFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD8E5F5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipList(List<String> values, VoidCallback Function(String value) onRemove) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values
          .map(
            (value) => InputChip(
              label: Text(value),
              onDeleted: () => onRemove(value),
              backgroundColor: const Color(0xFFEAF2FF),
              deleteIconColor: const Color(0xFF0F4C81),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _previewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E3A66),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E3A66).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Resume Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _titleController.text.isEmpty ? 'Target Job Title' : _titleController.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _locationController.text.isEmpty ? 'City, Country' : _locationController.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Professional Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _summaryController.text.isEmpty
                      ? 'Write a concise professional summary to show up here.'
                      : _summaryController.text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Skills',
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
                  children: _skills
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: const Color(0xFFEAF2FF),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Key Achievements',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ..._achievements.map(
                  (achievement) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            achievement,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Resume Builder'),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD8E5F5)),
                      ),
                      child: const Text(
                        'This is the first V2 product workspace. It stays separate from the stable launch flow while the resume builder grows into a full AI-assisted career module.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;
                        final form = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldCard(
                              label: 'Full Name',
                              controller: _nameController,
                              hint: 'Enter your full name',
                            ),
                            const SizedBox(height: 12),
                            _fieldCard(
                              label: 'Target Job Title',
                              controller: _titleController,
                              hint: 'Example: Operations Coordinator',
                            ),
                            const SizedBox(height: 12),
                            _fieldCard(
                              label: 'Location',
                              controller: _locationController,
                              hint: 'Example: Mumbai, India',
                            ),
                            const SizedBox(height: 12),
                            _fieldCard(
                              label: 'Professional Summary',
                              controller: _summaryController,
                              hint: 'Write a short career summary',
                              maxLines: 5,
                            ),
                            const SizedBox(height: 12),
                            _fieldCard(
                              label: 'Add Skill',
                              controller: _skillController,
                              hint: 'Example: Excel, Reporting, Communication',
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _addSkill,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add Skill'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _fillSample,
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Fill Sample'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _chipList(
                              _skills,
                              (value) {
                                setState(() {
                                  _skills.remove(value);
                                });
                                return () {};
                              },
                            ),
                            const SizedBox(height: 12),
                            _fieldCard(
                              label: 'Add Achievement',
                              controller: _achievementController,
                              hint: 'Example: Improved response time by 20%',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _addAchievement,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add Achievement'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _resetDraft,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset Draft'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _chipList(
                              _achievements,
                              (value) {
                                setState(() {
                                  _achievements.remove(value);
                                });
                                return () {};
                              },
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _saveDraft,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save Draft'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.home_outlined),
                                  label: const Text('Back to V2 Home'),
                                ),
                              ],
                            ),
                          ],
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: form),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: _previewCard()),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            form,
                            const SizedBox(height: 16),
                            _previewCard(),
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
