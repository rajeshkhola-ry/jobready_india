import 'package:flutter/material.dart';

class ResumeWorkspacePage extends StatefulWidget {
  const ResumeWorkspacePage({super.key});

  @override
  State<ResumeWorkspacePage> createState() => _ResumeWorkspacePageState();
}

class _ResumeWorkspacePageState extends State<ResumeWorkspacePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resume draft saved locally in V2 workspace.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Workspace'),
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
                constraints: const BoxConstraints(maxWidth: 900),
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
                        'Build your resume module here for V2 (former V3) without touching V1 launch files.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldCard(
                      label: 'Full Name',
                      controller: _nameController,
                      hint: 'Enter your full name',
                    ),
                    const SizedBox(height: 12),
                    _fieldCard(
                      label: 'Target Job Title',
                      controller: _titleController,
                      hint: 'Example: Cargo Revenue Accounting Specialist',
                    ),
                    const SizedBox(height: 12),
                    _fieldCard(
                      label: 'Professional Summary',
                      controller: _summaryController,
                      hint: 'Write a short profile summary',
                      maxLines: 5,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
}
