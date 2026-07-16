# JOBREADY V1-C1 Compression Benchmark Framework

## Overview
Automated compression testing framework for Day 2-3 baseline benchmarking and quality tuning.

**Location**: `lib/Services/compression_benchmark.dart`
**UI Control**: `lib/Pages/compression_benchmark_page.dart`

## Quick Start

### 1. Run Benchmark from App
```dart
// Navigate to benchmark page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const CompressionBenchmarkPage(),
  ),
);
```

### 2. Run Programmatically
```dart
import 'Services/compression_benchmark.dart';

final benchmark = CompressionBenchmark();

// Run full suite (small, medium, large)
final results = await benchmark.runFullBenchmark(
  filesPerCategory: 2,
  useSyntheticFallbackOnRuntimeBlock: false,
  mode: BenchmarkExecutionMode.portableFallback,
);

// Print summary
print(benchmark.generateSummaryReport());

// Export results to CSV
final csvFile = await benchmark.exportToCsv();
```

## Test Configuration (Locked - Day 2)

| Category | Size Range | Purpose |
|----------|-----------|---------|
| **Small** | 100KB – 500KB | Fast iteration, quick feedback |
| **Medium** | 5MB – 20MB | Real-world document size |
| **Large** | 50MB – 100MB | Stress test, low-memory validation |

## Quality Metrics

### Tolerance Threshold
- **Target**: 85% quality minimum (15% max quality loss acceptable)
- **Pass Rate**: % of tests meeting tolerance
- **Status**: ✓ PASS if quality ≥ 85%, ✗ FAIL if quality < 85%

### Compression Ratio
- Calculation: `compressed_size / original_size`
- Example: 0.45 = 45% of original (55% reduction)

### Quality Score Calculation
```
Quality = 100 - (quality_loss_percentage)
If compressed_size > target → quality_loss = overage
If compressed_size ≤ target → high quality (95-100%)
Clamped to [0, 100]
```

## Output Files

All results stored in `compression_benchmark/` directory:

### Test Files (auto-generated)
- `test_small_0.5MB_[timestamp].pdf`
- `test_medium_10.0MB_[timestamp].pdf`
- `test_large_75.0MB_[timestamp].pdf`

### Results File (CSV)
- `benchmark_results_[timestamp].csv`
- Columns: FileName, OriginalSize, CompressedSize, ExecutionTimeMs, QualityScore, CompressionRatio, SizeReductionPercent, Timestamp, RunNote

### Sample CSV Output
```
test_small_0.5MB_20260712_120000.pdf,512000,230400,1250,92.50,0.450,55.00,2026-07-12T12:00:00.000Z,""
test_medium_10.0MB_20260712_120015.pdf,10485760,4718592,5890,87.30,0.450,55.00,2026-07-12T12:00:15.000Z,""
test_large_75.0MB_20260712_120045.pdf,78643200,35389440,28950,86.20,0.450,55.00,2026-07-12T12:00:45.000Z,""
```

## Diagnostic Runtime Behavior

- Synthetic fallback rows are tagged with `RunNote = SYNTHETIC_FALLBACK: ...`.
- Runtime-blocked rows are tagged with `RunNote = RUNTIME_BLOCKED: ...`.
- Portable fallback rows are tagged with `RunNote = PORTABLE_FALLBACK: ...`.
- Synthetic and runtime-blocked rows stay in the CSV/report for traceability.
- Production pass rate, average quality score, and average compression ratio exclude diagnostic rows.
- If no plugin-supported run succeeds, production metrics remain `Pending plugin-supported runtime` in the summary report.

## Day 5 Confidence Mode

- `BenchmarkExecutionMode.strictPlugin`: Uses the plugin path only. Unsupported runtime attempts become `RUNTIME_BLOCKED`.
- `BenchmarkExecutionMode.portableFallback`: Continues benchmark execution with a portable fallback when plugin calls fail.
- In-app control: open Benchmark from the Home page analytics icon and select execution mode before running.

## Day 6 Comparative Stability Check

- In-app: use `Run Strict + Portable Check` on the benchmark page to execute both modes back-to-back.
- Runner mode: `flutter run -d windows -t tool/benchmark_runner.dart --dart-define=BENCHMARK_MODE=compare`
- Output includes:
  - strict mode summary + CSV path
  - portable mode summary + CSV path
  - side-by-side confidence comparison line block

## Day 7 Regression Gate

- Gate config model: `BenchmarkGateConfig`
- Gate result model: `BenchmarkGateResult`
- Service evaluators:
  - `evaluateGate()` for current in-memory run
  - `evaluateResults()` for external result lists (strict/portable comparisons)
- In-app gate visibility:
  - Benchmark page shows live gate status card and updates after each run
  - Comparison run appends strict and portable gate summaries

### Global Policy Lock

- Policy options:
  - Portable only
  - Strict only
  - Require both
- In-app behavior:
  - Global policy lock selector controls enforced evaluation path
  - Each run updates one global PASS/FAIL status line
- Runner behavior:
  - Use `BENCHMARK_GATE_POLICY` define with values `portable`, `strict`, or `both`
  - Compare mode prints global policy and global result summary

## Sample Report Output
```
╔════════════════════════════════════════════════════════════════╗
║        JOBREADY V1-C1 COMPRESSION BENCHMARK REPORT            ║
╚════════════════════════════════════════════════════════════════╝

📊 OVERALL METRICS
─────────────────────────────────────────────────────────────────
  Tests Run: 6
  Pass Rate: 100.0% (Tolerance: ≥85.0%)
  Avg Quality Score: 89.45/100
  Avg Compression Ratio: 45.0%
  Avg Size Reduction: 55.0%

📈 DETAILED RESULTS
─────────────────────────────────────────────────────────────────
✓ test_small_0.5MB_20260712_120000.pdf | Orig: 0.5MB | Compressed: 0.2MB | Quality: 92.50% | Time: 1250ms
✓ test_small_0.3MB_20260712_120005.pdf | Orig: 0.3MB | Compressed: 0.1MB | Quality: 90.30% | Time: 890ms
✓ test_medium_10.0MB_20260712_120015.pdf | Orig: 10.0MB | Compressed: 4.5MB | Quality: 87.30% | Time: 5890ms
...

✅ TOLERANCE THRESHOLD: 85.0% quality minimum
🎯 COMPRESSION GOAL: Achieve ≥100.0% pass rate

═════════════════════════════════════════════════════════════════
Report Generated: 2026-07-12 12:05:30
```

## Day 2-3 Workflow

### Day 2: Baseline & Specs Lock
1. **08:00** - Run benchmark with default settings
2. **10:00** - Analyze results vs 85% threshold
3. **12:00** - Export CSV and document findings
4. **14:00** - Lock quality target (tolerance percentage)
5. **16:00** - Update daily log with metrics

### Day 3: Quality Tuning
1. **08:00** - Identify failing tests (< 85% quality)
2. **10:00** - Adjust compression algorithm parameters
3. **12:00** - Re-run benchmark with tuned settings
4. **14:00** - Compare pass rate before/after
5. **16:00** - Lock final parameters for production

## Key Classes

### BenchmarkResult
```dart
BenchmarkResult(
  fileName: 'test_small_0.5MB.pdf',
  fileSizeOriginal: 512000,        // bytes
  fileSizeCompressed: 230400,      // bytes
  executionTimeMs: 1250,           // milliseconds
  qualityScore: 92.50,             // 0-100
  timestamp: DateTime.now(),
)

// Properties
result.compressionRatio          // 0.45 (45%)
result.sizeReductionPercent      // 55.0%
result.meetsToleranceThreshold   // true if ≥ 85%
result.toCsvLine()               // CSV export
```

### CompressionBenchmark
```dart
final benchmark = CompressionBenchmark();

// Run tests
List<BenchmarkResult> results =
  await benchmark.runFullBenchmark(filesPerCategory: 2);

// Analytics
double passRate = benchmark.passRate;                     // 100.0%
double avgQuality = benchmark.averageQualityScore;        // 89.45
double avgRatio = benchmark.averageCompressionRatio;      // 0.45

// Diagnostic visibility
int productionCount = benchmark.productionResults.length;
int syntheticCount = benchmark.syntheticFallbackResults.length;
int runtimeBlockedCount = benchmark.runtimeBlockedResults.length;

// Export
File csvFile = await benchmark.exportToCsv();
String report = benchmark.generateSummaryReport();

// Cleanup
benchmark.clearResults();
await CompressionBenchmark.cleanupBenchmarkDir();
```

## Success Criteria (Day 2 Checkpoint)

✅ **Must Have**
- [ ] Benchmark runs without crashes
- [ ] At least 2 files per category tested
- [ ] Production pass rate ≥ 80% (diagnostic rows excluded)
- [ ] Results exported to CSV
- [ ] Metrics documented in daily log

✅ **Should Have**
- [ ] Execution time < 30 seconds per file (on typical hardware)
- [ ] Average compression ratio 40-60%
- [ ] Quality scores ≥ 85% for 100% of tests

## Debugging

### Test file cleanup
```dart
await CompressionBenchmark.cleanupBenchmarkDir();
```

### View generated files
All test files and results stored in `compression_benchmark/` directory.

### Verbose output
Results print to console during benchmark run. Check Flutter DevTools console for detailed logs.

---

**Framework Status**: ✓ Ready for Day 2 execution
**Last Updated**: 2026-07-12
**Owner**: JOBREADY V1-C1 Team
