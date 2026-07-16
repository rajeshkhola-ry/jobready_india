import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import '../lib/Services/compression_benchmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('run full compression benchmark and export csv', () async {
    final benchmark = CompressionBenchmark();

    final results = await benchmark.runFullBenchmark(
      filesPerCategory: 2,
      useSyntheticFallbackOnRuntimeBlock: true,
    );
    final csvFile = await benchmark.exportToCsv();

    // Machine-readable markers for terminal parsing
    // ignore: avoid_print
    print('RESULT_COUNT=${results.length}');
    // ignore: avoid_print
    print('PASS_RATE=${benchmark.passRate.toStringAsFixed(2)}');
    // ignore: avoid_print
    print('AVG_QUALITY=${benchmark.averageQualityScore.toStringAsFixed(2)}');
    // ignore: avoid_print
    print('AVG_RATIO=${benchmark.averageCompressionRatio.toStringAsFixed(4)}');
    // ignore: avoid_print
    print('CSV_PATH=${csvFile.path}');

    expect(results.isNotEmpty, isTrue);
    expect(File(csvFile.path).existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
