import 'package:flutter/material.dart';

import '../../../Services/document_history_service.dart';
import '../../../Services/usage_quota_service.dart';

class ConverterWorkspacePage extends StatefulWidget {
  const ConverterWorkspacePage({super.key});

  @override
  State<ConverterWorkspacePage> createState() => _ConverterWorkspacePageState();
}

class _ConverterWorkspacePageState extends State<ConverterWorkspacePage> {
  String _inputFormat = 'PDF';
  String _outputFormat = 'DOCX';
  bool _keepLayout = true;
  bool _highQuality = true;
  List<DocumentHistoryEntry> _recentEntries = const <DocumentHistoryEntry>[];
  int _todayConversions = 0;

  static const List<String> _formats = [
    'PDF',
    'DOCX',
    'TXT',
    'JPG',
    'PNG',
  ];

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    final entries = DocumentHistoryService.getEntries()
        .where((entry) => _matchesConversionEntry(entry.outputFormat))
        .take(4)
        .toList(growable: false);
    final summary = UsageQuotaService.getTodaySummary();

    setState(() {
      _recentEntries = entries;
      _todayConversions = summary.conversions;
    });
  }

  bool _matchesConversionEntry(String outputFormat) {
    final normalized = outputFormat.toLowerCase();
    return normalized.contains('convert') ||
        normalized.contains('pdf') ||
        normalized.contains('word') ||
        normalized.contains('image') ||
        normalized.contains('jpg') ||
        normalized.contains('png') ||
        normalized.contains('text');
  }

  void _applyPreset(String input, String output) {
    setState(() {
      _inputFormat = input;
      _outputFormat = output;
    });
  }

  void _startConversionPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Plan created: $_inputFormat to $_outputFormat, '
          'layout ${_keepLayout ? 'kept' : 'flexible'}, '
          'quality ${_highQuality ? 'high' : 'balanced'}. Opening converter tool...',
        ),
      ),
    );

    Navigator.pushNamed(context, '/convert');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Converter Workspace'),
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
                    _panel(
                      child: const Text(
                        'V2 converter module workspace. Configure conversion plans here before execution.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Presets',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Use a preset to prepare the V2 workspace, then continue into the main converter.',
                            style: TextStyle(
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
                              _PresetChip(
                                label: 'PDF to DOCX',
                                onTap: () => _applyPreset('PDF', 'DOCX'),
                              ),
                              _PresetChip(
                                label: 'DOCX to PDF',
                                onTap: () => _applyPreset('DOCX', 'PDF'),
                              ),
                              _PresetChip(
                                label: 'PDF to JPG',
                                onTap: () => _applyPreset('PDF', 'JPG'),
                              ),
                              _PresetChip(
                                label: 'PNG to PDF',
                                onTap: () => _applyPreset('PNG', 'PDF'),
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
                            'Input Format',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _inputFormat,
                            items: _formats
                                .map((format) => DropdownMenuItem<String>(
                                      value: format,
                                      child: Text(format),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _inputFormat = value);
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Output Format',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _outputFormat,
                            items: _formats
                                .map((format) => DropdownMenuItem<String>(
                                      value: format,
                                      child: Text(format),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _outputFormat = value);
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
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
                          SwitchListTile.adaptive(
                            value: _keepLayout,
                            onChanged: (value) => setState(() => _keepLayout = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Preserve document layout'),
                          ),
                          SwitchListTile.adaptive(
                            value: _highQuality,
                            onChanged: (value) => setState(() => _highQuality = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Prefer high quality output'),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _startConversionPlan,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Create Plan & Open Tool'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _refreshHistory,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Refresh History'),
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
                    const SizedBox(height: 14),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Recent Conversion History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Today: $_todayConversions',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0E3A66),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_recentEntries.isEmpty)
                            const Text(
                              'No conversion history yet. Complete one conversion from the main tool and it will appear here.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF64748B),
                              ),
                            )
                          else
                            Column(
                              children: _recentEntries
                                  .map((entry) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _HistoryRow(entry: entry),
                                      ))
                                  .toList(growable: false),
                            ),
                        ],
                      ),
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

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: child,
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      backgroundColor: const Color(0xFFEAF2FF),
      side: const BorderSide(color: Color(0xFFD8E5F5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DocumentHistoryEntry entry;

  const _HistoryRow({required this.entry});

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Color(0xFF0E3A66),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.outputFormat} • ${_formatSize(entry.fileSizeBytes)} • ${_formatTime(entry.recordedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
