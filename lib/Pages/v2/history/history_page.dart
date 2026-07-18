import 'package:flutter/material.dart';

import '../../../Services/document_history_service.dart';
import '../../../Services/user_account_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late TextEditingController _searchController;
  String _selectedFormat = 'All formats';
  int _retentionLimit = 100;
  List<DocumentHistoryEntry> _filteredEntries = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _retentionLimit = DocumentHistoryService.getRetentionLimit();
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final allEntries = DocumentHistoryService.getEntries();
    final query = _searchController.text.toLowerCase();

    _filteredEntries = allEntries.where((entry) {
      final matchesSearch =
          query.isEmpty || entry.fileName.toLowerCase().contains(query);
      final matchesFormat =
          _selectedFormat == 'All formats' ||
          entry.outputFormat.toLowerCase().contains(_selectedFormat.toLowerCase());
      return matchesSearch && matchesFormat;
    }).toList();

    setState(() {});
  }

  Future<void> _deleteEntry(String id) async {
    final allEntries = DocumentHistoryService.getEntries();
    final updated = allEntries.where((e) => e.id != id).toList();
    await DocumentHistoryService.clear();
    for (final entry in updated) {
      await DocumentHistoryService.addEntry(
        fileName: entry.fileName,
        outputFormat: entry.outputFormat,
        fileSizeBytes: entry.fileSizeBytes,
      );
    }
    _applyFilters();
  }

  Future<void> _clearAll() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This action cannot be undone. All document conversion history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DocumentHistoryService.clear();
              Navigator.pop(context);
              _applyFilters();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _setRetentionLimit(int limit) async {
    await DocumentHistoryService.setRetentionLimit(limit);
    setState(() {
      _retentionLimit = limit;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDay = DateTime(dt.year, dt.month, dt.day);

    if (entryDay == today) {
      return 'Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (entryDay == yesterday) {
      return 'Yesterday at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserAccountService.getProfile();
    final historyDisabled = !profile.historyEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document History'),
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
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panel(
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
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Document History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'View and manage your recent document conversions and downloads.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (historyDisabled)
                      _panel(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFD8D8)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Color(0xFF9F1239),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'History tracking is disabled in your account settings.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9F1239),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (historyDisabled) const SizedBox(height: 14),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search & Filter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => _applyFilters(),
                            decoration: InputDecoration(
                              hintText: 'Search by file name...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedFormat,
                                  items: [
                                    'All formats',
                                    'PDF',
                                    'DOCX',
                                    'JPG',
                                    'PNG',
                                  ]
                                      .map((format) =>
                                          DropdownMenuItem<String>(
                                            value: format,
                                            child: Text(format),
                                          ))
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedFormat = value;
                                      });
                                      _applyFilters();
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Format',
                                    border: OutlineInputBorder(),
                                  ),
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
                            'Retention Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Keep up to:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [20, 50, 100, 200].map((limit) {
                              final isActive = _retentionLimit == limit;
                              return ChoiceChip(
                                label: Text('$limit entries'),
                                selected: isActive,
                                onSelected: (_) => _setRetentionLimit(limit),
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFF0E3A66),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_filteredEntries.isEmpty)
                      _panel(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 32, horizontal: 16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 40,
                                color: const Color(0xFFB8D0ED),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No documents yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchController.text.isEmpty &&
                                        _selectedFormat == 'All formats'
                                    ? 'Your document history will appear here.'
                                    : 'No results match your search or filter.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent (${_filteredEntries.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _clearAll,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Clear all'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final entry = _filteredEntries[index];
                              return _HistoryEntryTile(
                                entry: entry,
                                onDelete: () => _deleteEntry(entry.id),
                                formatBytes: _formatBytes,
                                formatTime: _formatTime,
                              );
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
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

class _HistoryEntryTile extends StatelessWidget {
  final DocumentHistoryEntry entry;
  final VoidCallback onDelete;
  final String Function(int) formatBytes;
  final String Function(DateTime) formatTime;

  const _HistoryEntryTile({
    required this.entry,
    required this.onDelete,
    required this.formatBytes,
    required this.formatTime,
  });

  IconData _getFormatIcon(String format) {
    final lower = format.toLowerCase();
    if (lower.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.contains('jpg') || lower.contains('jpeg') || lower.contains('png'))
      return Icons.image_rounded;
    if (lower.contains('doc') || lower.contains('word'))
      return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFormatColor(String format) {
    final lower = format.toLowerCase();
    if (lower.contains('pdf')) return const Color(0xFFDC2626);
    if (lower.contains('jpg') || lower.contains('jpeg'))
      return const Color(0xFF0E7490);
    if (lower.contains('png')) return const Color(0xFF0F766E);
    if (lower.contains('doc')) return const Color(0xFF2563EB);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getFormatColor(entry.outputFormat).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getFormatIcon(entry.outputFormat),
              color: _getFormatColor(entry.outputFormat),
              size: 20,
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
                Row(
                  children: [
                    Text(
                      entry.outputFormat,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatBytes(entry.fileSizeBytes),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatTime(entry.recordedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
            iconSize: 18,
            color: const Color(0xFF94A3B8),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete entry',
          ),
        ],
      ),
    );
  }
}
