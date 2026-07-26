import 'dart:io';

import 'package:flutter/material.dart';

class LaunchReadinessPage extends StatefulWidget {
  const LaunchReadinessPage({super.key});

  @override
  State<LaunchReadinessPage> createState() => _LaunchReadinessPageState();
}

class _LaunchReadinessPageState extends State<LaunchReadinessPage> {
  static const String _benchmarkDir = 'compression_benchmark';

  bool _loading = true;
  String _status = 'Loading launch readiness...';
  File? _latestCsv;
  int _csvCount = 0;
  int _productionRows = 0;
  int _runtimeBlockedRows = 0;
  int _portableFallbackRows = 0;
  double _passRate = 0;
  double _averageQuality = 0;
  int _keepLatest = 10;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _status = 'Loading launch readiness...';
    });

    try {
      final dir = Directory(_benchmarkDir);
      if (!dir.existsSync()) {
        setState(() {
          _loading = false;
          _status = 'No benchmark directory available yet.';
          _latestCsv = null;
          _csvCount = 0;
        });
        return;
      }

      final csvFiles =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.csv'))
              .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      _csvCount = csvFiles.length;
      if (csvFiles.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'No benchmark CSV files found.';
          _latestCsv = null;
        });
        return;
      }

      final latest = csvFiles.first;
      final lines = await latest.readAsLines();
      int production = 0;
      int runtimeBlocked = 0;
      int portableFallback = 0;
      int passCount = 0;
      double qualitySum = 0;

      for (final line in lines.skip(1)) {
        final row = line.trim();
        if (row.isEmpty) {
          continue;
        }

        final cols = _splitCsvLine(row);
        if (cols.length < 9) {
          continue;
        }

        final quality = double.tryParse(cols[4]) ?? 0;
        final runNote = cols[8];
        final isRuntimeBlocked = runNote.startsWith('RUNTIME_BLOCKED:');
        final isPortableFallback = runNote.startsWith('PORTABLE_FALLBACK:');
        final isSyntheticFallback = runNote.startsWith('SYNTHETIC_FALLBACK:');

        if (isRuntimeBlocked) {
          runtimeBlocked += 1;
        }
        if (isPortableFallback) {
          portableFallback += 1;
        }

        final isProduction = !isRuntimeBlocked && !isSyntheticFallback;
        if (isProduction) {
          production += 1;
          qualitySum += quality;
          if (quality >= 85.0) {
            passCount += 1;
          }
        }
      }

      setState(() {
        _latestCsv = latest;
        _productionRows = production;
        _runtimeBlockedRows = runtimeBlocked;
        _portableFallbackRows = portableFallback;
        _passRate = production == 0 ? 0 : (passCount / production) * 100;
        _averageQuality = production == 0 ? 0 : qualitySum / production;
        _loading = false;
        _status = 'Launch readiness snapshot updated.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Failed to load readiness data: $e';
      });
    }
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        final escaped = i + 1 < line.length && line[i + 1] == '"';
        if (escaped) {
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

  Future<void> _cleanupOldCsv() async {
    try {
      final dir = Directory(_benchmarkDir);
      if (!dir.existsSync()) {
        return;
      }

      final csvFiles =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.csv'))
              .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (csvFiles.length <= _keepLatest) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No old CSV files to remove.')),
        );
        return;
      }

      final toDelete = csvFiles.skip(_keepLatest);
      int removed = 0;
      for (final file in toDelete) {
        await file.delete();
        removed += 1;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $removed old CSV files.')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleanup failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gatePass = _productionRows > 0 && _passRate >= 85 && _averageQuality >= 85;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        title: const Text(
          'Launch Readiness',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh, color: Color(0xFFFFC72C)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetricCard(
                    title: 'V1 Merged Feature Completion Status',
                    value: 'Tools: DONE | Quota: DONE | OCR+Tables: DONE | Accounts: LOCAL ONLY | Payments: CONFIG ONLY',
                    subtitle: 'Core tools active. Live backend (auth, payments, cloud) still needs production connection.',
                    pass: true,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'V1 Pre-Launch Checklist',
                    value: 'Compress ✓ | Convert ✓ | Merge ✓ | Split ✓ | Extract ✓ | PDF Edit+OCR ✓ | Quota Gate ✓',
                    subtitle: 'Run owner acceptance test and repeat benchmark before final sign-off.',
                    pass: true,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Benchmark Gate',
                    value: gatePass ? 'PASS' : 'FAIL / PENDING',
                    subtitle:
                        'Pass rate: ${_passRate.toStringAsFixed(1)}% | Avg quality: ${_averageQuality.toStringAsFixed(2)}',
                    pass: gatePass,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Latest Benchmark CSV',
                    value: _latestCsv?.uri.pathSegments.last ?? 'None',
                    subtitle: _latestCsv?.path ?? 'No CSV generated yet.',
                    pass: _latestCsv != null,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Run Composition',
                    value:
                        'Production: $_productionRows | Runtime-blocked: $_runtimeBlockedRows | Portable-fallback: $_portableFallbackRows',
                    subtitle: 'Total CSV files: $_csvCount',
                    pass: true,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Artifact Retention',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          value: _keepLatest,
                          items: const [5, 10, 20, 30]
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('Keep latest $value CSV files'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _keepLatest = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _cleanupOldCsv,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Cleanup Old CSV Artifacts'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required bool pass,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pass ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pass ? Colors.green.shade200 : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: pass ? Colors.green.shade800 : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}
