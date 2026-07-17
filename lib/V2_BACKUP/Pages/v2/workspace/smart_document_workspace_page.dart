import 'package:flutter/material.dart';

import '../../../Services/document_history_service.dart';
import '../../../Services/file_storage_service.dart';

class SmartDocumentWorkspacePage extends StatefulWidget {
  const SmartDocumentWorkspacePage({super.key});

  @override
  State<SmartDocumentWorkspacePage> createState() => _SmartDocumentWorkspacePageState();
}

class _SmartDocumentWorkspacePageState extends State<SmartDocumentWorkspacePage> {
  final TextEditingController _searchController = TextEditingController();

  List<StoredFile> _storedFiles = const [];
  List<DocumentHistoryEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _storedFiles = FileStorageService.getStoredFiles();
      _history = DocumentHistoryService.getEntries().take(8).toList(growable: false);
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  List<StoredFile> _filteredFiles() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _storedFiles;
    }

    return _storedFiles.where((file) {
      return file.name.toLowerCase().contains(query) ||
          file.mimeType.toLowerCase().contains(query);
    }).toList(growable: false);
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

  @override
  Widget build(BuildContext context) {
    final files = _filteredFiles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Smart Document Workspace'),
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
                        'Document Workspace is the V2.7 module for organizing uploaded files, recent processing history, and quick retrieval before running AI or conversion tools.',
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
                            'Search Documents',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search by name or type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;

                        final left = _panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stored Files',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (files.isEmpty)
                                const Text(
                                  'No stored files found. Upload files from tool pages to populate this workspace.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                )
                              else
                                ...files.map(
                                  (file) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FBFF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFD8E5F5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${file.mimeType} • ${_formatSize(file.sizeBytes)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );

                        final right = _panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent Processing History',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_history.isEmpty)
                                const Text(
                                  'No processing history available yet.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                )
                              else
                                ..._history.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FBFF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFD8E5F5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.fileName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${entry.outputFormat} • ${_formatSize(entry.fileSizeBytes)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
