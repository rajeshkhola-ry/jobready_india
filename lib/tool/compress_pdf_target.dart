import 'dart:io';
import 'dart:typed_data';

import '../Services/compression_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: flutter pub run tool/compress_pdf_target.dart <input.pdf> <targetKB>');
    exitCode = 2;
    return;
  }

  final inputPath = args[0];
  final targetKb = int.tryParse(args[1]);
  if (targetKb == null || targetKb <= 0) {
    stderr.writeln('Invalid targetKB: ${args[1]}');
    exitCode = 2;
    return;
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exitCode = 1;
    return;
  }

  final targetBytes = targetKb * 1024;
  final sourceBytes = await inputFile.readAsBytes();
  final service = CompressionService();

  Uint8List best = sourceBytes;

  final high = await service.compressPdfSmart(
    sourceBytes,
    targetBytes,
    inputFile.uri.pathSegments.isNotEmpty ? inputFile.uri.pathSegments.last : inputFile.path,
    mode: PdfCompressionMode.targetSize,
    pipelineMode: CompressionPipelineMode.highCompressionImageOnly,
  );
  best = high.bytes;

  if (best.length > targetBytes) {
    final forcedHigh = await service.forceCompressPdfToTarget(
      best,
      targetBytes,
      inputFile.uri.pathSegments.isNotEmpty ? inputFile.uri.pathSegments.last : inputFile.path,
      pipelineMode: CompressionPipelineMode.highCompressionImageOnly,
    );
    if (forcedHigh.length < best.length) {
      best = forcedHigh;
    }
  }

  if (best.length > targetBytes) {
    final std = await service.compressPdfSmart(
      sourceBytes,
      targetBytes,
      inputFile.uri.pathSegments.isNotEmpty ? inputFile.uri.pathSegments.last : inputFile.path,
      mode: PdfCompressionMode.targetSize,
      pipelineMode: CompressionPipelineMode.standard,
    );
    if (std.bytes.length < best.length) {
      best = std.bytes;
    }
  }

  final outPath = inputPath.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '_${targetKb}kb_compressed.pdf');
  final outFile = File(outPath);
  await outFile.writeAsBytes(best, flush: true);

  final sourceMb = sourceBytes.length / (1024 * 1024);
  final outKb = best.length / 1024;
  final reduction = sourceBytes.isEmpty
      ? 0.0
      : (1 - (best.length / sourceBytes.length)) * 100;

  stdout.writeln('INPUT=$inputPath');
  stdout.writeln('OUTPUT=$outPath');
  stdout.writeln('ORIGINAL_MB=${sourceMb.toStringAsFixed(3)}');
  stdout.writeln('COMPRESSED_KB=${outKb.toStringAsFixed(2)}');
  stdout.writeln('TARGET_KB=$targetKb');
  stdout.writeln('REDUCTION_PERCENT=${reduction.toStringAsFixed(2)}');
  stdout.writeln('TARGET_MET=${best.length <= targetBytes}');
}
