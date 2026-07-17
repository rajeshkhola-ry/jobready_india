import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../Services/compression_benchmark.dart';
import '../Widgets/apple_button.dart';
import 'benchmark_history_page.dart';

/// Compression Benchmark Control Page (Debug/Development)
/// Used for Day 2-3 baseline testing and tuning
class CompressionBenchmarkPage extends StatefulWidget {
  const CompressionBenchmarkPage({super.key});

  @override
  State<CompressionBenchmarkPage> createState() =>
      _CompressionBenchmarkPageState();
}

class _CompressionBenchmarkPageState extends State<CompressionBenchmarkPage> {
  final _benchmark = CompressionBenchmark();
  final _gateConfig = const BenchmarkGateConfig(
    minPassRate: 85.0,
    minAverageQuality: 85.0,
    requireZeroRuntimeBlocked: false,
  );
  bool _isRunning = false;
  String _statusMessage = 'Ready to run benchmark';
  String _gateMessage = 'Gate not evaluated yet';
  BenchmarkGateResult? _lastGateResult;
  BenchmarkGatePolicy _gatePolicy = BenchmarkGatePolicy.portableOnly;
  String _globalGateMessage = 'Global gate not evaluated yet';
  bool? _globalGatePassed;
  List<String> _reportLines = [];
  BenchmarkExecutionMode _mode =
      kIsWeb
          ? BenchmarkExecutionMode.portableFallback
          : BenchmarkExecutionMode.strictPlugin;

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
          'V1-C1 Compression Benchmark',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history, color: Color(0xFFFFC72C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BenchmarkHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kIsWeb) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Text(
                  'Web runtime detected. Compression benchmark may be runtime-blocked by pdf_render plugin on web. Use desktop/mobile runtime for valid quality metrics.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Test Configuration
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Benchmark Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConfigRow(
                    'Small Files',
                    '100KB – 500KB',
                  ),
                  _buildConfigRow(
                    'Medium Files',
                    '5MB – 20MB',
                  ),
                  _buildConfigRow(
                    'Large Files',
                    '50MB – 100MB',
                  ),
                  const SizedBox(height: 8),
                  _buildConfigRow(
                    'Tolerance Threshold',
                    '85% (15% max quality loss)',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Execution Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<BenchmarkExecutionMode>(
                    segments: const [
                      ButtonSegment<BenchmarkExecutionMode>(
                        value: BenchmarkExecutionMode.strictPlugin,
                        label: Text('Strict Plugin'),
                        icon: Icon(Icons.verified),
                      ),
                      ButtonSegment<BenchmarkExecutionMode>(
                        value: BenchmarkExecutionMode.portableFallback,
                        label: Text('Portable Fallback'),
                        icon: Icon(Icons.build_circle_outlined),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged:
                        _isRunning
                            ? null
                            : (selection) {
                              setState(() {
                                _mode = selection.first;
                              });
                            },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode == BenchmarkExecutionMode.strictPlugin
                        ? 'Strict Plugin: uses pdf_render path only; runtime-blocks are reported when unsupported.'
                        : 'Portable Fallback: continues benchmark with cross-runtime fallback when plugin path fails.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Day 7 Regression Gate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rule: pass rate ≥ 85%, average quality ≥ 85 (runtime-blocked rows allowed for strict diagnostics)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _gateMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _lastGateResult == null
                              ? Colors.black87
                              : (_lastGateResult!.passed
                                  ? Colors.green.shade800
                                  : Colors.red.shade800),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Global Policy Lock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<BenchmarkGatePolicy>(
                    segments: const [
                      ButtonSegment<BenchmarkGatePolicy>(
                        value: BenchmarkGatePolicy.portableOnly,
                        label: Text('Portable'),
                      ),
                      ButtonSegment<BenchmarkGatePolicy>(
                        value: BenchmarkGatePolicy.strictOnly,
                        label: Text('Strict'),
                      ),
                      ButtonSegment<BenchmarkGatePolicy>(
                        value: BenchmarkGatePolicy.requireBoth,
                        label: Text('Both'),
                      ),
                    ],
                    selected: {_gatePolicy},
                    onSelectionChanged:
                        _isRunning
                            ? null
                            : (selection) {
                              final selected = selection.first;
                              setState(() {
                                _gatePolicy = selected;
                                if (selected == BenchmarkGatePolicy.portableOnly) {
                                  _mode = BenchmarkExecutionMode.portableFallback;
                                } else if (selected == BenchmarkGatePolicy.strictOnly) {
                                  _mode = BenchmarkExecutionMode.strictPlugin;
                                }
                                _globalGatePassed = null;
                                _globalGateMessage =
                                    'Global gate reset. Run benchmark to evaluate policy.';
                              });
                            },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _globalGateMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _globalGatePassed == null
                              ? Colors.black87
                              : (_globalGatePassed!
                                  ? Colors.green.shade800
                                  : Colors.red.shade800),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: AppleButton(
                    label: _isRunning ? 'Running...' : 'Run Benchmark',
                    icon: Icons.play_arrow,
                    onPressed: _isRunning ? null : _runBenchmark,
                    isPrimary: true,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 12),
                AppleButton(
                  label: 'Clear',
                  icon: Icons.delete_outline,
                  onPressed: _isRunning ? null : _clearResults,
                  isPrimary: false,
                  height: 48,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppleButton(
              label: _isRunning ? 'Running...' : 'Run Strict + Portable Check',
              icon: Icons.compare_arrows,
              onPressed: _isRunning ? null : _runConfidenceComparison,
              isPrimary: false,
              isFullWidth: true,
              height: 48,
            ),
            const SizedBox(height: 20),

            // Results Report
            if (_reportLines.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benchmark Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontFamily: 'Courier',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._reportLines
                        .map(
                          (line) => Text(
                            line,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontFamily: 'Courier',
                            ),
                          ),
                        )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppleButton(
                label: 'Export to CSV',
                icon: Icons.download,
                onPressed: _exportResults,
                isPrimary: true,
                isFullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.red : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runBenchmark() async {
    if (_gatePolicy == BenchmarkGatePolicy.portableOnly) {
      _mode = BenchmarkExecutionMode.portableFallback;
    }
    if (_gatePolicy == BenchmarkGatePolicy.strictOnly) {
      _mode = BenchmarkExecutionMode.strictPlugin;
    }

    setState(() {
      _isRunning = true;
      _statusMessage =
          _mode == BenchmarkExecutionMode.portableFallback
            ? 'Running benchmark in portable fallback mode...'
            : 'Running benchmark in strict plugin mode...';
      _reportLines = [];
    });

    try {
      _benchmark.clearResults();

      // Run benchmark with 2 files per category
      await _benchmark.runFullBenchmark(
        filesPerCategory: 2,
        useSyntheticFallbackOnRuntimeBlock: false,
        mode: _mode,
      );

        final hasProductionResults = _benchmark.productionResults.isNotEmpty;
        final hasDiagnosticRows =
          _benchmark.syntheticFallbackResults.isNotEmpty ||
          _benchmark.runtimeBlockedResults.isNotEmpty;
      final gateResult =
          _benchmark.evaluateGate(mode: _mode, config: _gateConfig);
      final strict =
          _mode == BenchmarkExecutionMode.strictPlugin ? gateResult : null;
      final portable =
          _mode == BenchmarkExecutionMode.portableFallback ? gateResult : null;
      final policyResult = CompressionBenchmark.evaluatePolicy(
        policy: _gatePolicy,
        strict: strict,
        portable: portable,
      );
      final report = _benchmark.generateSummaryReport(
        mode: _mode,
        policy: _gatePolicy,
        policyResult: policyResult,
      );
      final lines = report.split('\n');

      setState(() {
        _reportLines = lines;
        _lastGateResult = gateResult;
        _gateMessage = gateResult.summary;
        _globalGatePassed = policyResult.passed;
        _globalGateMessage = policyResult.summary;
        _statusMessage =
            hasProductionResults
                ? '✓ Benchmark completed with production metrics'
                : (hasDiagnosticRows
                    ? '✓ Diagnostic benchmark completed. Production metrics still need desktop/mobile runtime.'
                    : '✓ Benchmark completed successfully');
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasProductionResults
                ? '✓ Benchmark completed. Production results ready for export.'
                : '✓ Diagnostic benchmark completed. Export available for baseline tracking.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error: $e';
        _reportLines = ['Error running benchmark:', e.toString()];
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Benchmark failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runConfidenceComparison() async {
    setState(() {
      _isRunning = true;
      _statusMessage =
          'Running Day 6 confidence comparison (strict vs portable)...';
      _reportLines = [];
    });

    try {
      _benchmark.clearResults();
      await _benchmark.runFullBenchmark(
        filesPerCategory: 2,
        useSyntheticFallbackOnRuntimeBlock: false,
        mode: BenchmarkExecutionMode.strictPlugin,
      );
      final strictResults = List<BenchmarkResult>.from(_benchmark.results);
      final strictCsv = await _benchmark.exportToCsv(
        mode: BenchmarkExecutionMode.strictPlugin,
        policy: _gatePolicy,
      );

      _benchmark.clearResults();
      await _benchmark.runFullBenchmark(
        filesPerCategory: 2,
        useSyntheticFallbackOnRuntimeBlock: false,
        mode: BenchmarkExecutionMode.portableFallback,
      );
      final portableResults = List<BenchmarkResult>.from(_benchmark.results);
      final portableCsv = await _benchmark.exportToCsv(
        mode: BenchmarkExecutionMode.portableFallback,
        policy: _gatePolicy,
      );

      final strictProduction =
          strictResults.where((result) => result.countsTowardProductionMetrics).toList();
      final portableProduction =
          portableResults.where((result) => result.countsTowardProductionMetrics).toList();

      double passRate(List<BenchmarkResult> rows) {
        if (rows.isEmpty) {
          return 0;
        }

        final passCount =
            rows.where((result) => result.meetsToleranceThreshold).length;
        return (passCount / rows.length) * 100;
      }

      double averageQuality(List<BenchmarkResult> rows) {
        if (rows.isEmpty) {
          return 0;
        }

        final total =
            rows.map((result) => result.qualityScore).reduce((a, b) => a + b);
        return total / rows.length;
      }

      final strictRuntimeBlocked =
          strictResults.where((result) => result.isRuntimeBlocked).length;
      final strictPortableFallback =
          strictResults.where((result) => result.isPortableFallback).length;
      final portableRuntimeBlocked =
          portableResults.where((result) => result.isRuntimeBlocked).length;
      final portableFallbackCount =
          portableResults.where((result) => result.isPortableFallback).length;
      final strictGate = CompressionBenchmark.evaluateResults(
        strictResults,
        mode: BenchmarkExecutionMode.strictPlugin,
        config: _gateConfig,
      );
      final portableGate = CompressionBenchmark.evaluateResults(
        portableResults,
        mode: BenchmarkExecutionMode.portableFallback,
        config: _gateConfig,
      );
      final policyResult = CompressionBenchmark.evaluatePolicy(
        policy: _gatePolicy,
        strict: strictGate,
        portable: portableGate,
      );

      final lines = <String>[
        'DAY 6 CONFIDENCE COMPARISON',
        '====================================',
        'STRICT PLUGIN MODE',
        '  Tests: ${strictResults.length}',
        '  Production tests: ${strictProduction.length}',
        '  Pass rate: ${passRate(strictProduction).toStringAsFixed(1)}%',
        '  Avg quality: ${averageQuality(strictProduction).toStringAsFixed(2)}',
        '  Runtime-blocked: $strictRuntimeBlocked',
        '  Portable-fallback: $strictPortableFallback',
        '  CSV: ${strictCsv.path}',
        '',
        'PORTABLE FALLBACK MODE',
        '  Tests: ${portableResults.length}',
        '  Production tests: ${portableProduction.length}',
        '  Pass rate: ${passRate(portableProduction).toStringAsFixed(1)}%',
        '  Avg quality: ${averageQuality(portableProduction).toStringAsFixed(2)}',
        '  Runtime-blocked: $portableRuntimeBlocked',
        '  Portable-fallback: $portableFallbackCount',
        '  CSV: ${portableCsv.path}',
        '',
        'GATE EVALUATION',
        '  ${strictGate.summary}',
        '  ${portableGate.summary}',
        '  ${policyResult.summary}',
      ];

      setState(() {
        _reportLines = lines;
        _lastGateResult = portableGate;
        _gateMessage =
          'Strict: ${strictGate.passed ? 'PASS' : 'FAIL'} | Portable: ${portableGate.passed ? 'PASS' : 'FAIL'}';
        _globalGatePassed = policyResult.passed;
        _globalGateMessage = policyResult.summary;
        _statusMessage =
            '✓ Day 6 confidence comparison completed (strict + portable).';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Confidence comparison complete. Results ready.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Comparison failed: $e';
        _reportLines = ['Comparison failed:', e.toString()];
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Confidence comparison failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _exportResults() async {
    try {
      final csvFile = await _benchmark.exportToCsv(
        mode: _mode,
        policy: _gatePolicy,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Results exported to: ${csvFile.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _statusMessage = 'Results exported to CSV file';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearResults() {
    setState(() {
      _benchmark.clearResults();
      _reportLines = [];
      _statusMessage = 'Results cleared';
    });
  }

  @override
  void dispose() {
    CompressionBenchmark.cleanupBenchmarkDir();
    super.dispose();
  }
}
