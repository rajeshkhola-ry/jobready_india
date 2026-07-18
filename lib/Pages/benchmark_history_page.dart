import 'dart:io';

import 'package:flutter/material.dart';

class BenchmarkHistoryEntry {
  final File file;
  final int totalRows;
  final int productionRows;
  final int runtimeBlockedRows;
  final int portableFallbackRows;
  final double passRate;
  final double averageQuality;

  const BenchmarkHistoryEntry({
    required this.file,
    required this.totalRows,
    required this.productionRows,
    required this.runtimeBlockedRows,
    required this.portableFallbackRows,
    required this.passRate,
    required this.averageQuality,
  });
}

class BenchmarkHistoryPage extends StatefulWidget {
  const BenchmarkHistoryPage({super.key});

  @override
  State<BenchmarkHistoryPage> createState() => _BenchmarkHistoryPageState();
}

class _BenchmarkHistoryPageState extends State<BenchmarkHistoryPage> {
  static const _benchmarkDir = 'compression_benchmark';

  bool _loading = true;
  String _status = 'Loading benchmark history...';
  List<BenchmarkHistoryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _status = 'Loading benchmark history...';
    });

    try {
      final directory = Directory(_benchmarkDir);
      if (!directory.existsSync()) {
        setState(() {
          _entries = [];
          _loading = false;
          _status = 'No benchmark directory found yet.';
        });
        return;
      }

      final files =
          directory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.csv'))
              .toList()
            ..sort(
              (a, b) =>
                  b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            );

      final parsedEntries = <BenchmarkHistoryEntry>[];
      for (final file in files) {
        final entry = await _parseCsv(file);
        if (entry != null) {
          parsedEntries.add(entry);
        }
      }

      setState(() {
        _entries = parsedEntries;
        _loading = false;
        _status =
            parsedEntries.isEmpty
                ? 'No benchmark CSV files found.'
                : 'Loaded ${parsedEntries.length} benchmark runs.';
      });
    } catch (e) {
      setState(() {
        _entries = [];
        _loading = false;
        _status = 'Failed to load benchmark history: $e';
      });
    }
  }

  Future<BenchmarkHistoryEntry?> _parseCsv(File file) async {
    try {
      final lines = await file.readAsLines();
      if (lines.length <= 1) {
        return null;
      }

      int totalRows = 0;
      int productionRows = 0;
      int runtimeBlockedRows = 0;
      int portableFallbackRows = 0;
      int passedRows = 0;
      double qualitySum = 0;

      for (final rawLine in lines.skip(1)) {
        final line = rawLine.trim();
        if (line.isEmpty) {
          continue;
        }

        final columns = _splitCsvLine(line);
        if (columns.length < 9) {
          continue;
        }

        totalRows += 1;
        final quality = double.tryParse(columns[4]) ?? 0;
        final runNote = columns[8];

        final runtimeBlocked = runNote.startsWith('RUNTIME_BLOCKED:');
        final portableFallback = runNote.startsWith('PORTABLE_FALLBACK:');
        final syntheticFallback = runNote.startsWith('SYNTHETIC_FALLBACK:');

        if (runtimeBlocked) {
          runtimeBlockedRows += 1;
        }
        if (portableFallback) {
          portableFallbackRows += 1;
        }

        final production = !runtimeBlocked && !syntheticFallback;
        if (production) {
          productionRows += 1;
          qualitySum += quality;
          if (quality >= 85.0) {
            passedRows += 1;
          }
        }
      }

      final passRate =
          productionRows == 0 ? 0.0 : (passedRows / productionRows) * 100;
      final averageQuality =
          productionRows == 0 ? 0.0 : qualitySum / productionRows;

      return BenchmarkHistoryEntry(
        file: file,
        totalRows: totalRows,
        productionRows: productionRows,
        runtimeBlockedRows: runtimeBlockedRows,
        portableFallbackRows: portableFallbackRows,
        passRate: passRate,
        averageQuality: averageQuality,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
        if (nextIsQuote) {
          buffer.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }

    values.add(buffer.toString());
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A66),
        elevation: 0,
        title: const Text(
          'Benchmark History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFEAF2FF)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Production header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD8E5F5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.history_rounded,
                                      color: Color(0xFF0E3A66),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Benchmark History',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'View past compression benchmark results',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
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
                        const SizedBox(height: 16),

                        // Status message
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD8E5F5)),
                          ),
                          child: Text(
                            _status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0E3A66),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Entries list
                        _entries.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFD8E5F5)),
                                ),
                                child: Center(
                                  child: Text(
                                    'No benchmark history available',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  ..._entries.asMap().entries.map((e) {
                                    final entry = e.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildEntryCard(context, entry),
                                    );
                                  }),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, BenchmarkHistoryEntry entry) {
    final passColor =
        entry.passRate >= 85 ? const Color(0xFF166534) : const Color(0xFFB45309);
    final qualityColor =
        entry.averageQuality >= 85 ? const Color(0xFF166534) : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.file.uri.pathSegments.last,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: [
                  _statusBadge(
                    '${entry.passRate.toStringAsFixed(1)}% pass',
                    passColor,
                  ),
                  _statusBadge(
                    '${entry.averageQuality.toStringAsFixed(1)} quality',
                    qualityColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricItem('Total', '${entry.totalRows}'),
              const SizedBox(width: 16),
              _metricItem('Production', '${entry.productionRows}'),
              const SizedBox(width: 16),
              _metricItem('Blocked', '${entry.runtimeBlockedRows}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Portable fallback: ${entry.portableFallbackRows}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPathDialog(context, entry.file.path),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('View Path'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0E3A66),
                side: const BorderSide(color: Color(0xFFD8E5F5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E3A66),
          ),
        ),
      ],
    );
  }

  Future<void> _showPathDialog(BuildContext context, String path) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CSV Path'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
