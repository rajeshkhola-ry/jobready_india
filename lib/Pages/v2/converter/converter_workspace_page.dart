import 'package:flutter/material.dart';

import '../../../Services/document_history_service.dart';
import '../../../Services/usage_quota_service.dart';

class ConverterWorkspacePage extends StatefulWidget {
  const ConverterWorkspacePage({super.key});

  @override
  State<ConverterWorkspacePage> createState() => _ConverterWorkspacePageState();
}

class _ConverterWorkspacePageState extends State<ConverterWorkspacePage> {
  final TextEditingController _searchController = TextEditingController();
  String _inputFormat = 'PDF';
  String _outputFormat = 'DOCX';
  bool _keepLayout = true;
  bool _highQuality = true;
  String _searchQuery = '';
  String _selectedFormat = 'All';
  int _retentionLimit = DocumentHistoryService.getRetentionLimit();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshHistory() {
    final entries = DocumentHistoryService.getEntries()
        .where((entry) => _matchesConversionEntry(entry.outputFormat))
        .toList(growable: false);
    final summary = UsageQuotaService.getTodaySummary();

    setState(() {
      _recentEntries = entries;
      _todayConversions = summary.conversions;
      final formats = _availableFormats();
      if (!formats.contains(_selectedFormat)) {
        _selectedFormat = 'All';
      }
    });
  }

  List<String> _availableFormats() {
    final formats = _recentEntries
        .map((entry) => entry.outputFormat.trim())
        .where((format) => format.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...formats];
  }

  List<DocumentHistoryEntry> _filteredEntries() {
    final query = _searchQuery.trim().toLowerCase();
    return _recentEntries.where((entry) {
      if (_selectedFormat != 'All' && entry.outputFormat != _selectedFormat) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return entry.fileName.toLowerCase().contains(query) ||
          entry.outputFormat.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _clearHistory() async {
    await DocumentHistoryService.clear();
    if (!mounted) {
      return;
    }
    _refreshHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversion history cleared.')),
    );
  }

  Future<void> _updateRetentionLimit(int limit) async {
    await DocumentHistoryService.setRetentionLimit(limit);
    if (!mounted) {
      return;
    }
    setState(() {
      _retentionLimit = limit;
      _recentEntries = DocumentHistoryService.getEntries()
          .where((entry) => _matchesConversionEntry(entry.outputFormat))
          .toList(growable: false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retention updated to last $limit conversion entries.')),
    );
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
    if (_inputFormat == _outputFormat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Input and output format must be different.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening converter: $_inputFormat → $_outputFormat'
          '${_keepLayout ? ', layout preserved' : ''}'
          '${_highQuality ? ', high quality' : ''}.',
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
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E3A66),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Converter Workspace',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Choose your formats, apply a preset, and convert.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
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
                                isActive: _inputFormat == 'PDF' && _outputFormat == 'DOCX',
                                onTap: () => _applyPreset('PDF', 'DOCX'),
                              ),
                              _PresetChip(
                                label: 'DOCX to PDF',
                                isActive: _inputFormat == 'DOCX' && _outputFormat == 'PDF',
                                onTap: () => _applyPreset('DOCX', 'PDF'),
                              ),
                              _PresetChip(
                                label: 'PDF to JPG',
                                isActive: _inputFormat == 'PDF' && _outputFormat == 'JPG',
                                onTap: () => _applyPreset('PDF', 'JPG'),
                              ),
                              _PresetChip(
                                label: 'PNG to PDF',
                                isActive: _inputFormat == 'PNG' && _outputFormat == 'PDF',
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
                            value: _inputFormat,
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
                            value: _outputFormat,
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
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              value: _keepLayout,
                              onChanged: (value) => setState(() => _keepLayout = value),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Preserve document layout'),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              value: _highQuality,
                              onChanged: (value) => setState(() => _highQuality = value),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Prefer high quality output'),
                            ),
                          ),
                          if (_inputFormat == _outputFormat)
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Input and output format are the same ($_inputFormat). Please select a different output.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _inputFormat == _outputFormat ? null : _startConversionPlan,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E3A66),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: const Text('Convert Now'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _refreshHistory,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Refresh History'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.home_outlined),
                                label: const Text('Back to Home'),
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
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Search conversion history',
                              hintText: 'Search file name or format',
                              prefixIcon: Icon(Icons.search_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedFormat,
                            items: _availableFormats()
                                .map(
                                  (format) => DropdownMenuItem<String>(
                                    value: format,
                                    child: Text(format),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedFormat = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Filter by format',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final limit in const [20, 50, 100, 200])
                                ChoiceChip(
                                  label: Text('Retention: $limit'),
                                  selected: _retentionLimit == limit,
                                  onSelected: (_) => _updateRetentionLimit(limit),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Showing ${_filteredEntries().length} of ${_recentEntries.length} entries',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _recentEntries.isEmpty ? null : _clearHistory,
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: const Text('Clear History'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_recentEntries.isEmpty)
                            const Text(
                              'No conversion history yet. Complete one conversion from the main tool and it will appear here.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF64748B),
                              ),
                            )
                          else if (_filteredEntries().isEmpty)
                            const Text(
                              'No conversion history matches the current search or format filter.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF64748B),
                              ),
                            )
                          else
                            Column(
                              children: _filteredEntries()
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
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF0E3A66),
          ),
        ),
        onPressed: onTap,
        backgroundColor:
            isActive ? const Color(0xFF0E3A66) : const Color(0xFFEAF2FF),
        side: BorderSide(
          color: isActive ? const Color(0xFF0E3A66) : const Color(0xFFD8E5F5),
        ),
        avatar: isActive
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
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
