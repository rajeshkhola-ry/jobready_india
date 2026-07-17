import 'package:flutter/material.dart';

class V2EndgameExecutionPage extends StatefulWidget {
  const V2EndgameExecutionPage({super.key});

  @override
  State<V2EndgameExecutionPage> createState() => _V2EndgameExecutionPageState();
}

class _V2EndgameExecutionPageState extends State<V2EndgameExecutionPage> {
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _automationTemplateController =
      TextEditingController();
  final TextEditingController _auditNoteController = TextEditingController();
  final TextEditingController _betaFeedbackController = TextEditingController();

  final List<_TeamMember> _teamMembers = [
    _TeamMember(name: 'Operations Lead', role: 'Admin'),
    _TeamMember(name: 'Content Editor', role: 'Editor'),
  ];

  final List<String> _sharedFolders = ['Policy Docs', 'Client Uploads'];

  final List<String> _languages = ['English', 'Hindi', 'Spanish', 'German'];
  String _sourceLanguage = 'English';
  String _targetLanguage = 'Hindi';
  String _sourceText = 'Hello, your document is ready for review.';

  final List<String> _workflowTemplates = [
    'Compress + Watermark + Export',
    'OCR + Translate + Share',
  ];

  final Map<String, bool> _integrations = {
    'Google Drive': true,
    'OneDrive': false,
    'Slack Notifications': true,
    'Zapier Webhooks': false,
  };

  final Map<String, bool> _securityPolicies = {
    'Require 2FA for Admins': true,
    'Session timeout (30m)': true,
    'IP allowlist mode': false,
    'Daily audit export': true,
  };

  final List<String> _auditNotes = [
    'Role matrix approved by product owner.',
    'Retention policy draft reviewed by legal.',
  ];

  final Map<String, bool> _plans = {
    'Free': true,
    'Pro': true,
    'Team': false,
    'Enterprise': false,
  };

  final List<_QaScenario> _qaScenarios = [
    _QaScenario(name: '100 file batch convert', passed: true),
    _QaScenario(name: 'OCR long PDF stress test', passed: false),
    _QaScenario(name: 'Regional locale rendering', passed: true),
  ];

  final List<_LaunchGate> _launchGates = [
    _LaunchGate(name: 'Security sign-off', done: false),
    _LaunchGate(name: 'Payments dry-run complete', done: false),
    _LaunchGate(name: 'Beta issue burn-down', done: true),
    _LaunchGate(name: 'Launch runbook owner assigned', done: true),
  ];

  final List<String> _betaFeedback = [
    'Need clearer status labels in upload queue.',
  ];

  @override
  void dispose() {
    _memberNameController.dispose();
    _folderNameController.dispose();
    _automationTemplateController.dispose();
    _auditNoteController.dispose();
    _betaFeedbackController.dispose();
    super.dispose();
  }

  int _overallCompletion() {
    final bool teamReady = _teamMembers.length >= 2 && _sharedFolders.isNotEmpty;
    final bool languageReady = _sourceLanguage != _targetLanguage;
    final bool automationReady = _workflowTemplates.isNotEmpty;
    final bool integrationReady = _integrations.values.where((v) => v).length >= 2;
    final bool securityReady = _securityPolicies.values.where((v) => v).length >= 3;
    final bool plansReady = _plans.values.where((v) => v).length >= 3;
    final bool qaReady = _qaScenarios.where((s) => s.passed).length >= 2;
    final bool launchReady = _launchGates.where((g) => g.done).length >= 3;

    final totalReady = [
      teamReady,
      languageReady,
      automationReady,
      integrationReady,
      securityReady,
      plansReady,
      qaReady,
      launchReady,
    ].where((v) => v).length;

    return ((totalReady / 8) * 100).round();
  }

  Widget _panel({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }

  Widget _phaseTitle(String code, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            code,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _v28TeamWorkspace() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.8', 'Team and Business Workspace', const Color(0xFF0F766E)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _memberNameController,
                  decoration: const InputDecoration(
                    labelText: 'Team member name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  final text = _memberNameController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  setState(() {
                    _teamMembers.add(_TeamMember(name: text, role: 'Editor'));
                    _memberNameController.clear();
                  });
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Member'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._teamMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text(member.name),
              trailing: DropdownButton<String>(
                value: member.role,
                items: const ['Admin', 'Editor', 'Viewer']
                    .map((role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(growable: false),
                onChanged: (role) {
                  if (role == null) {
                    return;
                  }
                  setState(() {
                    _teamMembers[index] = _TeamMember(name: member.name, role: role);
                  });
                },
              ),
            );
          }),
          const Divider(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _folderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shared folder',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final text = _folderNameController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  setState(() {
                    _sharedFolders.add(text);
                    _folderNameController.clear();
                  });
                },
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Add Folder'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sharedFolders
                .map((folder) => Chip(
                      label: Text(folder),
                      avatar: const Icon(Icons.folder_open, size: 18),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  String _translatePreview(String input, String target) {
    if (target == 'Hindi') {
      return 'Namaste! Aapka document review ke liye tayyar hai.';
    }
    if (target == 'Spanish') {
      return 'Hola, su documento esta listo para revision.';
    }
    if (target == 'German') {
      return 'Hallo, Ihr Dokument ist zur Prufung bereit.';
    }
    return input;
  }

  Widget _v29LanguageIntelligence() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.9', 'Global Language Intelligence', const Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _sourceLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  items: _languages
                      .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _sourceLanguage = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _targetLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Target',
                    border: OutlineInputBorder(),
                  ),
                  items: _languages
                      .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _targetLanguage = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 2,
            maxLines: 4,
            controller: TextEditingController(text: _sourceText)
              ..selection = TextSelection.collapsed(offset: _sourceText.length),
            onChanged: (value) {
              setState(() {
                _sourceText = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Source text sample',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _translatePreview(_sourceText, _targetLanguage),
              style: const TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v210Automation() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.10', 'Automation and Smart Workflows', const Color(0xFFB45309)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _automationTemplateController,
                  decoration: const InputDecoration(
                    labelText: 'New workflow template',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final text = _automationTemplateController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  setState(() {
                    _workflowTemplates.add(text);
                    _automationTemplateController.clear();
                  });
                },
                child: const Text('Add Template'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._workflowTemplates.map(
            (item) => CheckboxListTile(
              value: true,
              onChanged: (_) {},
              title: Text(item),
              subtitle: const Text('Ready for queue execution'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _v211Integrations() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.11', 'API and Integrations', const Color(0xFF0E7490)),
          const SizedBox(height: 12),
          ..._integrations.entries.map(
            (entry) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: entry.value,
              onChanged: (enabled) {
                setState(() {
                  _integrations[entry.key] = enabled;
                });
              },
              title: Text(entry.key),
              subtitle: Text(enabledLabel(entry.value)),
            ),
          ),
        ],
      ),
    );
  }

  String enabledLabel(bool value) {
    return value ? 'Connected' : 'Not connected';
  }

  Widget _v212SecurityAdmin() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.12', 'Enterprise Security and Admin', const Color(0xFF334155)),
          const SizedBox(height: 12),
          ..._securityPolicies.entries.map(
            (entry) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: entry.value,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _securityPolicies[entry.key] = value;
                });
              },
              title: Text(entry.key),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _auditNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Audit note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  final text = _auditNoteController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  setState(() {
                    _auditNotes.insert(0, text);
                    _auditNoteController.clear();
                  });
                },
                child: const Text('Log Note'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._auditNotes.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(item),
              )),
        ],
      ),
    );
  }

  Widget _v213Monetization() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.13', 'Global Payments and Monetization', const Color(0xFFDC2626)),
          const SizedBox(height: 12),
          ..._plans.entries.map(
            (entry) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: entry.value,
              onChanged: (enabled) {
                setState(() {
                  _plans[entry.key] = enabled;
                });
              },
              title: Text('${entry.key} Plan'),
              subtitle: Text(entry.value
                  ? 'Entitlements enabled for rollout'
                  : 'Pending entitlement mapping'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v214QaBeta() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.14', 'Performance, QA and Beta', const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          ..._qaScenarios.asMap().entries.map((entry) {
            final index = entry.key;
            final scenario = entry.value;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: scenario.passed,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _qaScenarios[index] = _QaScenario(
                    name: scenario.name,
                    passed: value,
                  );
                });
              },
              title: Text(scenario.name),
              subtitle: Text(scenario.passed ? 'Passed' : 'Needs fixes'),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _betaFeedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Beta feedback note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  final text = _betaFeedbackController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  setState(() {
                    _betaFeedback.insert(0, text);
                    _betaFeedbackController.clear();
                  });
                },
                child: const Text('Add Feedback'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._betaFeedback.map(
            (note) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.forum_outlined),
              title: Text(note),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v215LaunchProgram() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _phaseTitle('V2.15', 'Global Launch Program', const Color(0xFF059669)),
          const SizedBox(height: 12),
          ..._launchGates.asMap().entries.map((entry) {
            final index = entry.key;
            final gate = entry.value;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: gate.done,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _launchGates[index] = _LaunchGate(name: gate.name, done: value);
                });
              },
              title: Text(gate.name),
              subtitle: Text(gate.done ? 'Closed' : 'Open'),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completion = _overallCompletion();

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('V2 Endgame Execution (8-15)'),
          backgroundColor: const Color(0xFF0E3A66),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'V2.8'),
              Tab(text: 'V2.9'),
              Tab(text: 'V2.10'),
              Tab(text: 'V2.11'),
              Tab(text: 'V2.12'),
              Tab(text: 'V2.13'),
              Tab(text: 'V2.14'),
              Tab(text: 'V2.15'),
            ],
          ),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Execution Progress',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$completion% of endgame tracks are in executable state.',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: completion / 100,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v28TeamWorkspace()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v29LanguageIntelligence()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v210Automation()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v211Integrations()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v212SecurityAdmin()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v213Monetization()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v214QaBeta()),
                      SingleChildScrollView(padding: const EdgeInsets.all(16), child: _v215LaunchProgram()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMember {
  final String name;
  final String role;

  const _TeamMember({required this.name, required this.role});
}

class _QaScenario {
  final String name;
  final bool passed;

  const _QaScenario({required this.name, required this.passed});
}

class _LaunchGate {
  final String name;
  final bool done;

  const _LaunchGate({required this.name, required this.done});
}
