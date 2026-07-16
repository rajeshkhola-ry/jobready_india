import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PhotoSizePreset {
  final String id;
  final String label;
  final int width;
  final int height;

  const PhotoSizePreset({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
  });
}

class PhotoResizeResult {
  final Uint8List bytes;
  final String outputFileName;
  final int width;
  final int height;

  const PhotoResizeResult({
    required this.bytes,
    required this.outputFileName,
    required this.width,
    required this.height,
  });
}

class PhotoResizeService {
  const PhotoResizeService();

  static const List<PhotoSizePreset> presets = [
    PhotoSizePreset(id: 'passport', label: 'Passport Size - 413 x 531', width: 413, height: 531),
    PhotoSizePreset(id: 'card', label: 'Card Size - 1050 x 675', width: 1050, height: 675),
    PhotoSizePreset(id: 'postcard', label: '4 x 6 Print - 1200 x 1800', width: 1200, height: 1800),
    PhotoSizePreset(id: 'studio', label: '5 x 7 Print - 1500 x 2100', width: 1500, height: 2100),
    PhotoSizePreset(id: 'profile_hd', label: 'Profile HD - 1080 x 1080', width: 1080, height: 1080),
    PhotoSizePreset(id: 'a4', label: 'A4 Portrait - 2480 x 3508', width: 2480, height: 3508),
  ];

  PhotoResizeResult upscalePhoto({
    required Uint8List bytes,
    required String fileName,
    required PhotoSizePreset preset,
    required bool enableHdMode,
  }) {
    final source = img.decodeImage(bytes);
    if (source == null) {
      throw StateError('Unsupported image format. Please use JPG, PNG, WEBP, or BMP.');
    }

    final prepared = _prepareSource(source, enableHdMode: enableHdMode);
    final canvas = img.Image(width: preset.width, height: preset.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final fitted = _resizeToFit(prepared, preset.width, preset.height);
    final offsetX = ((preset.width - fitted.width) / 2).round();
    final offsetY = ((preset.height - fitted.height) / 2).round();
    img.compositeImage(canvas, fitted, dstX: offsetX, dstY: offsetY);

    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final outputName = '${baseName}_${preset.id}${enableHdMode ? '_hd' : ''}.jpg';

    final encoded = Uint8List.fromList(
      img.encodeJpg(canvas, quality: enableHdMode ? 98 : 94),
    );

    return PhotoResizeResult(
      bytes: encoded,
      outputFileName: outputName,
      width: preset.width,
      height: preset.height,
    );
  }

  img.Image _prepareSource(img.Image source, {required bool enableHdMode}) {
    if (!enableHdMode) {
      return source;
    }

    final boosted = img.adjustColor(
      source,
      contrast: 1.08,
      saturation: 1.03,
      gamma: 0.98,
    );

    return img.copyResize(
      boosted,
      width: (boosted.width * 1.15).round(),
      height: (boosted.height * 1.15).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  img.Image _resizeToFit(img.Image source, int targetWidth, int targetHeight) {
    final sourceRatio = source.width / source.height;
    final targetRatio = targetWidth / targetHeight;

    int outputWidth;
    int outputHeight;

    if (sourceRatio > targetRatio) {
      outputWidth = targetWidth;
      outputHeight = (targetWidth / sourceRatio).round();
    } else {
      outputHeight = targetHeight;
      outputWidth = (targetHeight * sourceRatio).round();
    }

    return img.copyResize(
      source,
      width: outputWidth,
      height: outputHeight,
      interpolation: img.Interpolation.cubic,
    );
  }
}
