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
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        title: const Text(
          'Benchmark History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh, color: Color(0xFFFFC72C)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(
                            child: Text('No benchmark history available.'),
                          )
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return _buildEntryCard(context, entry);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryCard(BuildContext context, BenchmarkHistoryEntry entry) {
    final passColor = entry.passRate >= 85 ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${entry.passRate.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: passColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Rows: ${entry.totalRows} | Production: ${entry.productionRows}'),
          Text(
            'Runtime-blocked: ${entry.runtimeBlockedRows} | Portable-fallback: ${entry.portableFallbackRows}',
          ),
          Text('Avg quality: ${entry.averageQuality.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showPathDialog(context, entry.file.path),
                icon: const Icon(Icons.folder_open),
                label: const Text('View Path'),
              ),
            ],
          ),
        ],
      ),
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
