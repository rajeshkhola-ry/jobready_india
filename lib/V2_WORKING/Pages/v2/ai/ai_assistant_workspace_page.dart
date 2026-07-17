import 'package:flutter/material.dart';

import '../../../Services/ai_service.dart';
import '../../../Services/file_picker_service.dart';
import '../../../Services/upload_context_service.dart';

class AiAssistantWorkspacePage extends StatefulWidget {
  const AiAssistantWorkspacePage({super.key});

  @override
  State<AiAssistantWorkspacePage> createState() => _AiAssistantWorkspacePageState();
}

class _AiAssistantWorkspacePageState extends State<AiAssistantWorkspacePage> {
  final TextEditingController _promptController = TextEditingController();
  PickedFileData? _selectedFile;
  String _selectedQuestion = 'Summarize document';
  AiResponse? _latestResponse;

  static const List<String> _questionTypes = [
    'Summarize document',
    'Explain simply',
    'Find dates',
    'Compare documents',
    'Create email',
  ];

  @override
  void initState() {
    super.initState();
    _hydrateFile();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _hydrateFile() {
    final file = UploadContextService.getFirstCompatibleFile(
      ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
    );

    if (file == null) {
      return;
    }

    _selectedFile = file;
    _latestResponse = AiService.generateResponse(
      questionType: _selectedQuestion,
      fileName: file.name,
      prompt: _promptController.text,
    );
  }

  Future<void> _pickFile() async {
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: const ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
    );

    if (picked == null) {
      return;
    }

    UploadContextService.setLastPickedFile(picked);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFile = picked;
      _latestResponse = AiService.generateResponse(
        questionType: _selectedQuestion,
        fileName: picked.name,
        prompt: _promptController.text,
      );
    });
  }

  void _generateResponse() {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a document first.')),
      );
      return;
    }

    setState(() {
      _latestResponse = AiService.generateResponse(
        questionType: _selectedQuestion,
        fileName: selectedFile.name,
        prompt: _promptController.text,
      );
    });
  }

  void _applyFollowUp(String value) {
    setState(() {
      _selectedQuestion = value;
      _latestResponse = _selectedFile == null
          ? null
          : AiService.generateResponse(
              questionType: value,
              fileName: _selectedFile!.name,
              prompt: _promptController.text,
            );
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

  Widget _questionChip(String label) {
    final isSelected = label == _selectedQuestion;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyFollowUp(label),
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _responseCard() {
    final response = _latestResponse;
    if (response == null) {
      return _panel(
        child: const Text(
          'Upload a document and choose a question type to generate an assistant response.',
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
            response.answer,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Suggested follow-ups',
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
            children: response.followUps.map(_questionChip).toList(growable: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 AI Assistant'),
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
                        'This is the first V2 AI workspace. It uses local assistant logic now, so the module exists and can be expanded later into document-aware AI without changing the V1 launch lane.',
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

                        final leftColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Upload Document',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedFile == null
                                        ? 'No document loaded yet. PDF, Word, text, and image files are supported.'
                                        : 'Loaded: ${_selectedFile!.name} (${_selectedFile!.size} bytes)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.upload_file_rounded),
                                        label: const Text('Upload File'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedFile = null;
                                            _latestResponse = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear_rounded),
                                        label: const Text('Clear'),
                                      ),
                                    ],
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
                                    'Question Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _questionTypes.map(_questionChip).toList(growable: false),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Optional prompt note',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _promptController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: 'Example: keep the answer short and professional',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _generateResponse,
                                        icon: const Icon(Icons.auto_awesome_rounded),
                                        label: const Text('Generate Answer'),
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

                        final rightColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _panel(
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assistant Scope',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Summaries, simple explanations, key dates, comparison prompts, and email drafts are the first supported patterns.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _responseCard(),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: leftColumn),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: rightColumn),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leftColumn,
                            const SizedBox(height: 16),
                            rightColumn,
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
