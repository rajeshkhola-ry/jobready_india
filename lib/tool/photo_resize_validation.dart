import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../Services/photo_resize_service.dart';

void main() {
  final samplePath = 'test_assets/photo_samples/public_portrait_sample.jpg';
  final sampleFile = File(samplePath);

  if (!sampleFile.existsSync()) {
    stderr.writeln('SAMPLE_NOT_FOUND: $samplePath');
    exitCode = 1;
    return;
  }

  final bytes = Uint8List.fromList(sampleFile.readAsBytesSync());
  final service = const PhotoResizeService();

  final outputDir = Directory('test_assets/photo_samples/out');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final checks = <Map<String, Object?>>[];
  for (final preset in PhotoResizeService.presets) {
    for (final hd in [false, true]) {
      final result = service.upscalePhoto(
        bytes: bytes,
        fileName: 'public_portrait_sample.jpg',
        preset: preset,
        enableHdMode: hd,
      );

      final outFile = File('${outputDir.path}/${result.outputFileName}');
      outFile.writeAsBytesSync(result.bytes, flush: true);

      final decoded = img.decodeJpg(result.bytes);
      checks.add({
        'preset': preset.id,
        'hd': hd,
        'expected': '${preset.width}x${preset.height}',
        'actual': decoded == null ? 'decode_failed' : '${decoded.width}x${decoded.height}',
        'bytes': result.bytes.length,
        'file': outFile.path,
      });
    }
  }

  for (final check in checks) {
    stdout.writeln(
      '${check['preset']} | hd=${check['hd']} | expected=${check['expected']} | actual=${check['actual']} | bytes=${check['bytes']} | file=${check['file']}',
    );
  }
}
