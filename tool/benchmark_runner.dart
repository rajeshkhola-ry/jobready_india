import 'package:flutter/widgets.dart';

import '../lib/Services/compression_benchmark.dart';

class _RunnerSnapshot {
  final String label;
  final int totalTests;
  final int productionTests;
  final int runtimeBlocked;
  final int portableFallback;
  final double passRate;
  final double averageQuality;
  final String csvPath;

  const _RunnerSnapshot({
    required this.label,
    required this.totalTests,
    required this.productionTests,
    required this.runtimeBlocked,
    required this.portableFallback,
    required this.passRate,
    required this.averageQuality,
    required this.csvPath,
  });
}

Future<_RunnerSnapshot> _runSnapshot(
  CompressionBenchmark benchmark,
  String label,
  BenchmarkExecutionMode mode,
) async {
  benchmark.clearResults();

  await benchmark.runFullBenchmark(
    filesPerCategory: 2,
    useSyntheticFallbackOnRuntimeBlock: false,
    mode: mode,
  );

  final csvFile = await benchmark.exportToCsv();
  final report = benchmark.generateSummaryReport();
  final allResults = List<BenchmarkResult>.from(benchmark.results);
  final production =
      allResults.where((result) => result.countsTowardProductionMetrics).toList();

  double passRate(List<BenchmarkResult> rows) {
    if (rows.isEmpty) {
      return 0;
    }

    final passCount = rows.where((result) => result.meetsToleranceThreshold).length;
    return (passCount / rows.length) * 100;
  }

  double averageQuality(List<BenchmarkResult> rows) {
    if (rows.isEmpty) {
      return 0;
    }

    final total = rows.map((result) => result.qualityScore).reduce((a, b) => a + b);
    return total / rows.length;
  }

  final runtimeBlocked = allResults.where((result) => result.isRuntimeBlocked).length;
  final portableFallback = allResults.where((result) => result.isPortableFallback).length;

  print('\n=== $label MODE REPORT ===');
  print(report);
  print('CSV exported to: ${csvFile.path}');

  return _RunnerSnapshot(
    label: label,
    totalTests: allResults.length,
    productionTests: production.length,
    runtimeBlocked: runtimeBlocked,
    portableFallback: portableFallback,
    passRate: passRate(production),
    averageQuality: averageQuality(production),
    csvPath: csvFile.path,
  );
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final benchmark = CompressionBenchmark();
  final modeFromDefine = const String.fromEnvironment('BENCHMARK_MODE');
  final compareMode = args.contains('--mode=compare') || modeFromDefine == 'compare';
    final policyFromDefine = const String.fromEnvironment('BENCHMARK_GATE_POLICY');
    final policy =
      policyFromDefine == 'strict'
        ? BenchmarkGatePolicy.strictOnly
        : (policyFromDefine == 'both'
          ? BenchmarkGatePolicy.requireBoth
          : BenchmarkGatePolicy.portableOnly);
  final usePortableMode =
      args.contains('--mode=portable') || modeFromDefine == 'portable';

  print('JOBREADY benchmark runner starting...');
  if (compareMode) {
    print('Target mode: compare (strict-plugin + portable-fallback)');

    final strict = await _runSnapshot(
      benchmark,
      'STRICT-PLUGIN',
      BenchmarkExecutionMode.strictPlugin,
    );
    final portable = await _runSnapshot(
      benchmark,
      'PORTABLE-FALLBACK',
      BenchmarkExecutionMode.portableFallback,
    );

    print('\n=== DAY 6 CONFIDENCE COMPARISON SUMMARY ===');
    print('STRICT   -> tests: ${strict.totalTests}, production: ${strict.productionTests}, pass: ${strict.passRate.toStringAsFixed(1)}%, quality: ${strict.averageQuality.toStringAsFixed(2)}, runtime-blocked: ${strict.runtimeBlocked}, portable-fallback: ${strict.portableFallback}');
    print('PORTABLE -> tests: ${portable.totalTests}, production: ${portable.productionTests}, pass: ${portable.passRate.toStringAsFixed(1)}%, quality: ${portable.averageQuality.toStringAsFixed(2)}, runtime-blocked: ${portable.runtimeBlocked}, portable-fallback: ${portable.portableFallback}');
    print('STRICT CSV: ${strict.csvPath}');
    print('PORTABLE CSV: ${portable.csvPath}');
    final strictGate = BenchmarkGateResult(
      passed: strict.productionTests > 0 && strict.passRate >= 85.0 && strict.averageQuality >= 85.0,
      totalTests: strict.totalTests,
      productionTests: strict.productionTests,
      runtimeBlocked: strict.runtimeBlocked,
      portableFallback: strict.portableFallback,
      passRate: strict.passRate,
      averageQuality: strict.averageQuality,
      modeLabel: 'Strict',
    );
    final portableGate = BenchmarkGateResult(
      passed: portable.productionTests > 0 && portable.passRate >= 85.0 && portable.averageQuality >= 85.0,
      totalTests: portable.totalTests,
      productionTests: portable.productionTests,
      runtimeBlocked: portable.runtimeBlocked,
      portableFallback: portable.portableFallback,
      passRate: portable.passRate,
      averageQuality: portable.averageQuality,
      modeLabel: 'Portable',
    );
    final policyResult = CompressionBenchmark.evaluatePolicy(
      policy: policy,
      strict: strictGate,
      portable: portableGate,
    );
    print('GLOBAL POLICY: ${CompressionBenchmark.policyLabel(policy)}');
    print('GLOBAL RESULT: ${policyResult.summary}');
  } else {
    final mode =
        usePortableMode
            ? BenchmarkExecutionMode.portableFallback
            : BenchmarkExecutionMode.strictPlugin;
    print('Target mode: ${usePortableMode ? 'portable-fallback' : 'strict-plugin'}');

    await _runSnapshot(
      benchmark,
      usePortableMode ? 'PORTABLE-FALLBACK' : 'STRICT-PLUGIN',
      mode,
    );
  }

  print('JOBREADY benchmark runner completed.');
}
