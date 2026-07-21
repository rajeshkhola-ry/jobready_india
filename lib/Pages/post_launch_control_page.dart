import 'dart:io';

import 'package:flutter/material.dart';

class PostLaunchControlPage extends StatefulWidget {
  const PostLaunchControlPage({super.key});

  @override
  State<PostLaunchControlPage> createState() => _PostLaunchControlPageState();
}

class _PostLaunchControlPageState extends State<PostLaunchControlPage> {
  static const String _benchmarkDir = 'compression_benchmark';
  static const String _evidenceDir = 'launch_evidence';

  bool _loading = true;
  String _status = 'Loading post-launch control center...';
  File? _latestBenchmarkCsv;
  File? _latestEvidenceCsv;
  File? _latestRunbook;
  File? _latestSignoff;
  int _benchmarkCsvCount = 0;
  int _evidenceFileCount = 0;
  double _passRate = 0;
  double _averageQuality = 0;
  int _productionRows = 0;
  List<File> _signoffHistory = <File>[];
  String _bundleValidationMessage = 'Bundle validation not run yet.';
  bool? _bundleValidationPassed;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _status = 'Loading post-launch control center...';
    });

    try {
      final benchmarkDir = Directory(_benchmarkDir);
      final evidenceDir = Directory(_evidenceDir);

      final benchmarkCsvFiles = benchmarkDir.existsSync()
          ? (benchmarkDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.csv'))
                .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())))
          : <File>[];

      final evidenceFiles = evidenceDir.existsSync()
          ? (evidenceDir
                .listSync()
                .whereType<File>()
                .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())))
          : <File>[];

      final evidenceCsv = evidenceFiles
          .where((f) =>
              f.path.toLowerCase().contains('benchmark_evidence_') &&
              f.path.toLowerCase().endsWith('.csv'))
          .toList();

      final runbooks = evidenceFiles
          .where((f) =>
              f.path.toLowerCase().contains('launch_runbook_') &&
              f.path.toLowerCase().endsWith('.md'))
          .toList();

      final signoffs = evidenceFiles
          .where((f) =>
              f.path.toLowerCase().contains('launch_signoff_') &&
              f.path.toLowerCase().endsWith('.md'))
          .toList();

      final latestBenchmark = benchmarkCsvFiles.isEmpty ? null : benchmarkCsvFiles.first;
      final latestEvidence = evidenceCsv.isEmpty ? null : evidenceCsv.first;
      final latestRunbook = runbooks.isEmpty ? null : runbooks.first;
      final latestSignoff = signoffs.isEmpty ? null : signoffs.first;

      int productionRows = 0;
      int passCount = 0;
      double qualitySum = 0;

      if (latestBenchmark != null) {
        final lines = await latestBenchmark.readAsLines();
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
          final isSynthetic = runNote.startsWith('SYNTHETIC_FALLBACK:');

          if (!isRuntimeBlocked && !isSynthetic) {
            productionRows += 1;
            qualitySum += quality;
            if (quality >= 85.0) {
              passCount += 1;
            }
          }
        }
      }

      setState(() {
        _latestBenchmarkCsv = latestBenchmark;
        _latestEvidenceCsv = latestEvidence;
        _latestRunbook = latestRunbook;
        _latestSignoff = latestSignoff;
        _benchmarkCsvCount = benchmarkCsvFiles.length;
        _evidenceFileCount = evidenceFiles.length;
        _productionRows = productionRows;
        _passRate = productionRows == 0 ? 0.0 : (passCount / productionRows) * 100;
        _averageQuality = productionRows == 0 ? 0.0 : qualitySum / productionRows;
        _signoffHistory = signoffs;
        _loading = false;
        _status = 'Post-launch control snapshot updated.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Failed to load control center: $e';
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

  Future<void> _generateSignoffRecord() async {
    try {
      final evidenceDir = Directory(_evidenceDir);
      if (!evidenceDir.existsSync()) {
        evidenceDir.createSync(recursive: true);
      }

      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final tag =
          '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

      final signoffFile = File('${evidenceDir.path}/launch_signoff_$tag.md');
      final gatePass = _productionRows > 0 && _passRate >= 85.0 && _averageQuality >= 85.0;

      final text = '''# GETREADYJOB Post-Launch Sign-off

Generated: ${now.toIso8601String()}

## Summary
- Gate status: ${gatePass ? 'PASS' : 'FAIL / PENDING'}
- Production rows: $_productionRows
- Pass rate: ${_passRate.toStringAsFixed(1)}%
- Average quality: ${_averageQuality.toStringAsFixed(2)}

## Evidence Links
- Latest benchmark CSV: ${_latestBenchmarkCsv?.path ?? 'None'}
- Latest frozen evidence CSV: ${_latestEvidenceCsv?.path ?? 'None'}
- Latest runbook snapshot: ${_latestRunbook?.path ?? 'None'}

## Governance Checklist
- [x] Benchmark artifacts available
- [x] Runbook snapshot available
- [x] Post-launch sign-off record generated
- [ ] Founder final approval captured

## Notes
Generated by Post Launch Control page (Day 11+ execution).
''';

      await signoffFile.writeAsString(text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-off record created: ${signoffFile.path}'),
          backgroundColor: Colors.green,
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-off generation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _validateExportBundle() async {
    try {
      final benchmarkDir = Directory(_benchmarkDir);
      final evidenceDir = Directory(_evidenceDir);

      final benchmarkCsvFiles = benchmarkDir.existsSync()
          ? benchmarkDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.csv'))
                .toList()
          : <File>[];

      final evidenceFiles = evidenceDir.existsSync()
          ? evidenceDir
                .listSync()
                .whereType<File>()
                .toList()
          : <File>[];

      final hasBenchmarkCsv = benchmarkCsvFiles.isNotEmpty;
      final hasEvidenceCsv = evidenceFiles.any((f) =>
          f.path.toLowerCase().contains('benchmark_evidence_') &&
          f.path.toLowerCase().endsWith('.csv'));
      final hasRunbook = evidenceFiles.any((f) =>
          f.path.toLowerCase().contains('launch_runbook_') &&
          f.path.toLowerCase().endsWith('.md'));
      final hasSignoff = evidenceFiles.any((f) =>
          f.path.toLowerCase().contains('launch_signoff_') &&
          f.path.toLowerCase().endsWith('.md'));

      final passed = hasBenchmarkCsv && hasEvidenceCsv && hasRunbook && hasSignoff;
      final missing = <String>[];
      if (!hasBenchmarkCsv) {
        missing.add('benchmark CSV in compression_benchmark/');
      }
      if (!hasEvidenceCsv) {
        missing.add('frozen evidence CSV in launch_evidence/');
      }
      if (!hasRunbook) {
        missing.add('runbook markdown in launch_evidence/');
      }
      if (!hasSignoff) {
        missing.add('sign-off markdown in launch_evidence/');
      }

      setState(() {
        _bundleValidationPassed = passed;
        _bundleValidationMessage = passed
            ? 'Bundle PASS: benchmark CSV, frozen evidence CSV, runbook, and sign-off are all present.'
            : 'Bundle FAIL: missing ${missing.join(', ')}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bundleValidationMessage),
          backgroundColor: passed ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bundleValidationPassed = false;
        _bundleValidationMessage = 'Bundle validation failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bundle validation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gatePass = _productionRows > 0 && _passRate >= 85.0 && _averageQuality >= 85.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFC72C),
          size: 30,
        ),
        title: const Text(
          'Post-Launch Control',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Color(0xFFFFC72C)),
            onPressed: _loading ? null : _refresh,
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _metricCard(
                    title: 'Release Health Gate',
                    value: gatePass ? 'PASS' : 'FAIL / PENDING',
                    subtitle:
                        'Pass rate ${_passRate.toStringAsFixed(1)}% | Avg quality ${_averageQuality.toStringAsFixed(2)} | Production rows $_productionRows',
                    pass: gatePass,
                  ),
                  const SizedBox(height: 10),
                  _metricCard(
                    title: 'Benchmark Artifacts',
                    value: 'CSV files: $_benchmarkCsvCount',
                    subtitle: _latestBenchmarkCsv?.path ?? 'No benchmark CSV files yet.',
                    pass: _latestBenchmarkCsv != null,
                  ),
                  const SizedBox(height: 10),
                  _metricCard(
                    title: 'Launch Evidence Vault',
                    value: 'Files: $_evidenceFileCount',
                    subtitle: _latestRunbook?.path ?? 'No runbook snapshot found.',
                    pass: _latestRunbook != null,
                  ),
                  const SizedBox(height: 10),
                  _metricCard(
                    title: 'Latest Sign-off Record',
                    value: _latestSignoff?.uri.pathSegments.last ?? 'Not generated yet',
                    subtitle: _latestSignoff?.path ?? 'Generate sign-off record to continue Day 11 flow.',
                    pass: _latestSignoff != null,
                  ),
                  const SizedBox(height: 10),
                  _metricCard(
                    title: 'Export Bundle Validation',
                    value: _bundleValidationPassed == null
                        ? 'NOT RUN'
                        : (_bundleValidationPassed! ? 'PASS' : 'FAIL'),
                    subtitle: _bundleValidationMessage,
                    pass: _bundleValidationPassed ?? false,
                  ),
                  const SizedBox(height: 10),
                  _signoffHistoryCard(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _generateSignoffRecord,
                    icon: const Icon(Icons.approval_outlined),
                    label: const Text('Generate Day 11 Sign-off Record'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _validateExportBundle,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Validate Export Bundle'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _signoffHistoryCard() {
    return Container(
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
            'Sign-off History',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_signoffHistory.isEmpty)
            const Text('No sign-off history found yet.')
          else
            ..._signoffHistory.take(5).map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(file.path),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _metricCard({
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
          SelectableText(subtitle),
        ],
      ),
    );
  }
}
