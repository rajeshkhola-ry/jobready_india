import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/ai_cover_letter_service.dart';
import '../Services/company_insights_service.dart';
import '../Services/file_picker_service.dart';

class AiResumeBuilderPage extends StatefulWidget {
  const AiResumeBuilderPage({super.key});

  @override
  State<AiResumeBuilderPage> createState() => _AiResumeBuilderPageState();
}

class _AiResumeBuilderPageState extends State<AiResumeBuilderPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _projectsController = TextEditingController();
  final TextEditingController _jdController = TextEditingController();
  final TextEditingController _targetRoleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();

  Uint8List? _profilePhotoBytes;
  String? _profilePhotoName;
  bool? _attachPhotoToResume;
  String _summaryGhostHint = 'e.g. Results-driven professional with several years of experience delivering measurable impact through strategic execution, stakeholder collaboration, and continuous improvement.';
  String _selectedTier = '0–5 yrs';
  String _resumeOutput = '';
  String _coverLetterOutput = '';
  String _interviewQuestionsOutput = '';
  String _companyInsightsOutput = '';
  bool _mncStandard = true;
  bool _onePageLayout = false;
  bool _showTailoredPreview = false;
  bool _showCoverLetterPreview = false;
  bool _showInterviewQuestionsPreview = false;
  bool _showCompanyInsightsPreview = false;
  bool _isAssisting = false;
  String? _activeAssistField;
  TextEditingController? _activeAssistController;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _skillsController.dispose();
    _projectsController.dispose();
    _jdController.dispose();
    _targetRoleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // Ghost-text fields (empty fields are skipped entirely, never printed as filler content).
  String _buildResume() {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final summary = _summaryController.text.trim();
    final experience = _experienceController.text.trim();
    final education = _educationController.text.trim();
    final skills = _skillsController.text.trim();
    final projects = _projectsController.text.trim();
    final jd = _jdController.text.trim();
    final role = _targetRoleController.text.trim();

    final buffer = StringBuffer();

    if (name.isNotEmpty) {
      buffer.writeln(name);
    }
    if (email.isNotEmpty) {
      buffer.writeln('Email: $email');
    }
    if (phone.isNotEmpty) {
      buffer.writeln('Phone: $phone');
    }

    if (summary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Profile');
      buffer.writeln(summary);
    }

    buffer.writeln();
    buffer.writeln('Experience Tier: $_selectedTier');
    buffer.writeln(_mncStandard ? 'MNC Standard: 1-page / 2-page auto-format ready' : 'Flexible layout mode');
    buffer.writeln(_onePageLayout ? 'Preferred length: 1 page' : 'Preferred length: 2 pages');

    if (experience.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Experience');
      buffer.writeln(experience);
    }

    if (education.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Education');
      buffer.writeln(education);
    }

    if (skills.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Skills');
      buffer.writeln(skills);
    }

    if (projects.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Projects / Achievements');
      buffer.writeln(projects);
    }

    if (jd.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('JD Matcher');
      buffer.writeln('Tailored for ${role.isEmpty ? 'target role' : role} using JD keywords: ${jd.split(RegExp(r'\s+')).take(10).join(', ')}');
    }

    return buffer.toString().trim();
  }

  String _buildCoverLetter() {
    return AiCoverLetterService.buildCoverLetter(
      fullName: _fullNameController.text.trim().isEmpty ? 'Your Name' : _fullNameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? 'email@example.com' : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? 'Phone' : _phoneController.text.trim(),
      experience: _experienceController.text.trim().isEmpty ? 'Add your experience summary here.' : _experienceController.text.trim(),
      skills: _skillsController.text.trim().isEmpty ? 'Add core skills here.' : _skillsController.text.trim(),
      projects: _projectsController.text.trim().isEmpty ? 'Add key projects and achievements.' : _projectsController.text.trim(),
      targetRole: _targetRoleController.text.trim().isEmpty ? 'Target Role' : _targetRoleController.text.trim(),
      summary: _summaryController.text.trim().isEmpty ? 'Results-driven professional ready to create impact.' : _summaryController.text.trim(),
      jd: _jdController.text.trim(),
      mncStandard: _mncStandard,
      selectedTier: _selectedTier,
    );
  }

  void _generateResume() {
    setState(() {
      _resumeOutput = _buildResume();
      _showTailoredPreview = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your resume is ready! Please scroll down to preview and download.')),
    );
  }

  void _generateCoverLetter() {
    setState(() {
      _coverLetterOutput = _buildCoverLetter();
      _showCoverLetterPreview = true;
      _showTailoredPreview = true;
    });
  }

  void _generateInterviewQuestions() {
    setState(() {
      _interviewQuestionsOutput = AiCoverLetterService.buildInterviewQuestions(
        targetRole: _targetRoleController.text.trim(),
        jd: _jdController.text.trim(),
        experience: _experienceController.text.trim(),
        skills: _skillsController.text.trim(),
        summary: _summaryController.text.trim(),
      );
      _showInterviewQuestionsPreview = true;
      _showTailoredPreview = true;
    });
  }

  void _searchCompanyInsights() {
    final companyName = _companyController.text.trim();
    if (companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a company name to search insights.')));
      return;
    }

    setState(() {
      _companyInsightsOutput = CompanyInsightsService.fetchCompanyInsights(companyName);
      _showCompanyInsightsPreview = true;
    });
  }

  void _refineWithAiAssist() {
    setState(() {
      if (_coverLetterOutput.isEmpty) {
        _coverLetterOutput = _buildCoverLetter();
      } else {
        _coverLetterOutput = 'AI-assisted refinement:\n\n$_coverLetterOutput';
      }
      _showCoverLetterPreview = true;
      _showTailoredPreview = true;
    });
  }

  void _showJdInputDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Upload or paste JD'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paste a job description or upload a text file to match it against your resume.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _jdController,
                  maxLines: 8,
                  decoration: _buildStyledInputDecoration(
                    labelText: 'Job description / JD',
                    hintText: 'Paste JD here…',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final uploadInput = html.FileUploadInputElement();
                    uploadInput.accept = '.txt,.md,.json';
                    uploadInput.click();
                    uploadInput.onChange.listen((_) {
                      final files = uploadInput.files;
                      if (files == null || files.isEmpty) {
                        return;
                      }
                      final file = files.first;
                      final reader = html.FileReader();
                      reader.readAsText(file);
                      reader.onLoadEnd.listen((_) {
                        final text = reader.result?.toString() ?? '';
                        if (text.trim().isNotEmpty) {
                          _jdController.text = text;
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      });
                    });
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload text file'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (_jdController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paste or upload a JD first.')));
                  return;
                }
                Navigator.of(dialogContext).pop();
                setState(() {
                  _showTailoredPreview = true;
                  _resumeOutput = _buildResume();
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JD ready for matching.')));
              },
              child: const Text('Use JD'),
            ),
          ],
        );
      },
    );
  }

  void _downloadResume() {
    final photoBytes = _attachPhotoToResume == true ? _profilePhotoBytes : null;
    AiCoverLetterService.downloadResumeExport(_resumeOutput, 'pdf', photoBytes: photoBytes);
  }

  void _downloadCoverLetter() {
    AiCoverLetterService.downloadTextFile(_coverLetterOutput, 'cover_letter_export.txt');
  }

  Future<void> _handleShareAction(String action) async {
    final resumeText = _resumeOutput.isEmpty ? 'Resume not generated yet.' : _resumeOutput;
    final coverLetterText = _coverLetterOutput.isEmpty ? 'Cover Letter not generated yet.' : _coverLetterOutput;

    if (action == 'drive' || action == 'onedrive') {
      if (action == 'drive') {
        AiCoverLetterService.openGoogleDrive();
      } else {
        AiCoverLetterService.openOneDrive();
      }
      return;
    }

    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select File Format'),
          content: const Text('Choose PDF or DOCX for the exported resume file.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'pdf'), child: const Text('PDF')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'docx'), child: const Text('DOCX')),
          ],
        );
      },
    );

    if (selectedFormat == null) {
      return;
    }

    final shareText = 'Hi! I created a polished resume and cover letter with AI Resume Builder.\n\nResume:\n$resumeText\n\nCover Letter:\n$coverLetterText';
    final photoBytes = _attachPhotoToResume == true ? _profilePhotoBytes : null;

    if (action == 'whatsapp') {
      await AiCoverLetterService.shareResumeExport(
        resumeText,
        selectedFormat,
        subject: 'AI Resume Builder export',
        text: shareText,
        photoBytes: photoBytes,
      );
      AiCoverLetterService.openWhatsApp(shareText);
    } else if (action == 'email') {
      await AiCoverLetterService.shareResumeExport(
        resumeText,
        selectedFormat,
        subject: 'AI Resume Builder export',
        text: shareText,
        photoBytes: photoBytes,
      );
      AiCoverLetterService.openEmail('AI Resume Builder export', shareText);
    }
  }

  String _generateAssistedText(String fieldLabel, String currentValue) {
    final trimmedValue = currentValue.trim();
    final role = _targetRoleController.text.trim().isNotEmpty ? _targetRoleController.text.trim() : 'the target role';
    final yearsMatch = RegExp(r'(\d+)\s*(?:years?|yrs?)').firstMatch(trimmedValue);
    final yearsText = yearsMatch != null ? '${yearsMatch.group(1)}+' : 'several';
    final baseValue = trimmedValue.isEmpty ? 'your background, strengths, and measurable achievements' : trimmedValue;

    switch (fieldLabel.toLowerCase()) {
      case 'career summary':
      case 'professional summary':
      case 'summary':
        return 'Results-driven $role professional with $yearsText years of experience delivering measurable impact through strategic execution, stakeholder collaboration, content quality, and continuous improvement. Known for combining strong ownership with clear communication and a consistent record of high-quality outcomes.';
      case 'experience':
      case 'work experience':
        return '• $baseValue\n• Proven track record of delivering high-impact outcomes in fast-paced, results-oriented environments.\n• Strong ownership, collaboration, and professional growth with a focus on quality and execution.';
      case 'education':
        return '• $baseValue\n• Demonstrated academic discipline, analytical capability, and a strong commitment to continuous learning and professional growth.';
      case 'skills':
        return '• $baseValue\n• Analytical thinking and problem-solving\n• Clear communication and stakeholder collaboration\n• Adaptability, ownership, and continuous learning';
      case 'projects / achievements':
      case 'projects':
      case 'achievements':
        return '• $baseValue\n• Delivered measurable outcomes that improved efficiency, quality, and stakeholder satisfaction.\n• Managed work with a strong focus on execution, reliability, and continuous improvement.';
      case 'target role':
        return 'Targeting $role with a strong focus on measurable impact, execution, and long-term growth.';
      case 'jd matcher':
        return 'Tailored for $role with strong alignment to the job description, emphasizing relevant experience, transferable strengths, and clear professional credibility.';
      default:
        return trimmedValue.isEmpty
            ? 'Polished professional content tailored to the role and ready to use.'
            : '$baseValue\n\nPrepared with a more polished, professional, and resume-ready tone.';
    }
  }

  void _setActiveAssistField(String fieldLabel, TextEditingController controller) {
    setState(() {
      _activeAssistField = fieldLabel;
      _activeAssistController = controller;
    });
  }

  Future<void> _applyAiAssistToField(String fieldLabel, TextEditingController controller) async {
    if (_isAssisting) {
      return;
    }

    setState(() {
      _isAssisting = true;
      _activeAssistField = fieldLabel;
      _activeAssistController = controller;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    final assistedText = _generateAssistedText(fieldLabel, controller.text);
    controller.value = TextEditingValue(
      text: assistedText,
      selection: TextSelection.collapsed(offset: assistedText.length),
    );

    setState(() {
      _isAssisting = false;
      _activeAssistField = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $fieldLabel with polished AI text.')),
      );
    }

    if (_resumeOutput.isNotEmpty) {
      setState(() {
        _resumeOutput = _buildResume();
        _showTailoredPreview = true;
      });
    }
  }

  Widget _buildAssistButton({required String label, required TextEditingController controller, VoidCallback? onTap}) {
    final isLoading = _isAssisting && _activeAssistField == label;

    return TextButton.icon(
      onPressed: isLoading ? null : (onTap ?? () => _applyAiAssistToField(label, controller)),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome, size: 16),
      label: Text(isLoading ? 'Writing…' : '✨ AI Assist'),
    );
  }

  Future<void> _applyAiAssistToFocusedField() async {
    final label = _activeAssistField ?? 'Career Summary';
    final controller = _activeAssistController ?? _summaryController;
    await _applyAiAssistToField(label, controller);
  }

  InputDecoration _buildStyledInputDecoration({required String hintText, String? labelText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
    );
  }

  // Career Summary's AI Assist only ever refreshes a hint (ghost text); it never writes into the controller.
  void _refreshSummaryGhostHint() {
    final generated = _generateAssistedText('career summary', '');
    setState(() {
      _summaryGhostHint = 'e.g. $generated';
    });
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool isMultiline = false,
    bool showAssistButton = true,
    String? hintText,
    VoidCallback? onAssistTap,
  }) {
    final isPhoneField = label.toLowerCase() == 'phone';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (showAssistButton) _buildAssistButton(label: label, controller: controller, onTap: onAssistTap),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isPhoneField ? TextInputType.phone : TextInputType.text,
          maxLines: isMultiline ? 4 : maxLines,
          onTap: () => _setActiveAssistField(label, controller),
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: _buildStyledInputDecoration(
            hintText: hintText ?? (isPhoneField ? 'Type your contact number' : label),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Profile Photo', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_profilePhotoBytes == null)
                const Text('Add a professional photo for your resume.', style: TextStyle(fontSize: 13, color: Color(0xFF475569)))
              else
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFE2E8F0),
                        image: DecorationImage(
                          image: MemoryImage(_profilePhotoBytes!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _profilePhotoName ?? 'Profile photo ready',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await FilePickerService.pickFileData(
                        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                      );
                      if (picked == null || !mounted) {
                        return;
                      }
                      setState(() {
                        _profilePhotoBytes = picked.bytes;
                        _profilePhotoName = picked.name;
                        _attachPhotoToResume = true;
                      });
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Photo'),
                  ),
                  if (_profilePhotoBytes != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _profilePhotoBytes = null;
                          _profilePhotoName = null;
                          _attachPhotoToResume = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                ],
              ),
              if (_profilePhotoBytes != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Add this photo to your downloaded/exported resume?',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Yes, attach photo'),
                      selected: _attachPhotoToResume == true,
                      onSelected: (_) => setState(() => _attachPhotoToResume = true),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _attachPhotoToResume == true ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('No, do not attach'),
                      selected: _attachPhotoToResume == false,
                      onSelected: (_) => setState(() => _attachPhotoToResume = false),
                      selectedColor: const Color(0xFF64748B),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _attachPhotoToResume == false ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _attachPhotoToResume == true
                      ? 'This photo will be included in your downloaded resume.'
                      : 'This photo will NOT be included in your downloaded resume.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (_resumeOutput.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _downloadResume,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download PDF'),
          ),
        if (_coverLetterOutput.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _downloadCoverLetter,
            icon: const Icon(Icons.description_rounded),
            label: const Text('Download Cover Letter'),
          ),
        OutlinedButton.icon(
          onPressed: _generateCoverLetter,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Generate Matching Cover Letter'),
        ),
        OutlinedButton.icon(
          onPressed: _generateInterviewQuestions,
          icon: const Icon(Icons.quiz_rounded),
          label: const Text('Generate Interview Questions'),
        ),
        OutlinedButton.icon(
          onPressed: _refineWithAiAssist,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Refine with Yellow AI Assist'),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleShareAction('whatsapp'),
          icon: const Icon(Icons.chat_rounded),
          label: const Text('Send to WhatsApp'),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleShareAction('email'),
          icon: const Icon(Icons.email_rounded),
          label: const Text('Send via Email'),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleShareAction('drive'),
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Save to Google Drive'),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleShareAction('onedrive'),
          icon: const Icon(Icons.cloud_rounded),
          label: const Text('Save to OneDrive'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Resume Builder'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Experience Tier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['0–5 yrs', '5–15 yrs', '15–30+ yrs'].map<Widget>((tier) {
                final selected = _selectedTier == tier;
                return ChoiceChip(
                  label: Text(tier),
                  selected: selected,
                  onSelected: (value) {
                    if (value) {
                      setState(() {
                        _selectedTier = tier;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildField(label: 'Full Name', controller: _fullNameController, showAssistButton: false),
            const SizedBox(height: 12),
            _buildField(label: 'Email', controller: _emailController, showAssistButton: false),
            const SizedBox(height: 12),
            _buildPhotoUploadSection(),
            const SizedBox(height: 12),
            _buildField(label: 'Phone', controller: _phoneController, showAssistButton: false),
            const SizedBox(height: 12),
            _buildField(
              label: 'Career Summary',
              controller: _summaryController,
              isMultiline: true,
              hintText: _summaryGhostHint,
              onAssistTap: _refreshSummaryGhostHint,
            ),
            const SizedBox(height: 12),
            _buildField(label: 'Experience', controller: _experienceController, isMultiline: true),
            const SizedBox(height: 12),
            _buildField(label: 'Education', controller: _educationController, isMultiline: true),
            const SizedBox(height: 12),
            _buildField(label: 'Skills', controller: _skillsController, isMultiline: true),
            const SizedBox(height: 12),
            _buildField(label: 'Projects / Achievements', controller: _projectsController, isMultiline: true),
            const SizedBox(height: 12),
            _buildField(label: 'Target Role', controller: _targetRoleController),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'If you send the JD or Job Post Name, then we can generate a tailored Resume, Cover Letter, AI Interview Preparation Questions, and Company Insights following your target role!',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            _buildField(label: 'JD Matcher', controller: _jdController, isMultiline: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _companyController,
                    decoration: _buildStyledInputDecoration(
                      labelText: 'Company Name',
                      hintText: 'Search company insights',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _searchCompanyInsights,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('MNC Standard (1-page / 2-page auto-format)'),
              value: _mncStandard,
              onChanged: (value) {
                setState(() {
                  _mncStandard = value;
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zero mandatory fields mode'),
              value: !_onePageLayout,
              onChanged: (value) {
                setState(() {
                  _onePageLayout = !value;
                });
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ActionChipButton(
                    icon: Icons.create_rounded,
                    label: 'Create Resume',
                    onPressed: _generateResume,
                    isPrimary: true,
                  ),
                  _ActionChipButton(
                    icon: Icons.description_outlined,
                    label: 'Generate Matching Cover Letter',
                    onPressed: _generateCoverLetter,
                  ),
                  _ActionChipButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Upload / Match JD',
                    onPressed: _showJdInputDialog,
                  ),
                  _ActionChipButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Yellow AI Assist',
                    onPressed: _applyAiAssistToFocusedField,
                  ),
                  _ActionChipButton(
                    icon: Icons.library_books_rounded,
                    label: 'Select Template (500+)',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template gallery will open here.')));
                    },
                  ),
                  _ActionChipButton(
                    icon: Icons.copy_rounded,
                    label: 'Clone / Duplicate Resume',
                    onPressed: _generateResume,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_showTailoredPreview)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreviewActions(),
                      const SizedBox(height: 14),
                      if (_showTailoredPreview)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(_resumeOutput.isEmpty ? 'Create your resume first to preview it here.' : _resumeOutput),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_showCoverLetterPreview)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF7E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF4D06F)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cover Letter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(_coverLetterOutput.isEmpty ? 'Generate a matching cover letter to preview it here.' : _coverLetterOutput),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_showInterviewQuestionsPreview)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Interview Questions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(_interviewQuestionsOutput.isEmpty ? 'Generate interview questions to preview them here.' : _interviewQuestionsOutput),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_showCompanyInsightsPreview)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC4B5FD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Company Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(_companyInsightsOutput.isEmpty ? 'Search for company insights to preview them here.' : _companyInsightsOutput),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
    final foregroundColor = isPrimary ? const Color(0xFFFFC72C) : const Color(0xFF1F2937);
    final borderColor = isPrimary ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
