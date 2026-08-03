import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  final String outputLabel;

  const PhotoResizeResult({
    required this.bytes,
    required this.outputFileName,
    required this.width,
    required this.height,
    this.outputLabel = '',
  });
}

class PhotoRenderRequest {
  final Uint8List bytes;
  final String fileName;
  final PhotoSizePreset preset;
  final bool enableHdMode;
  final String dpi;
  final String backgroundColor;
  final int maxTargetKb;
  final String aspectPresetId;
  final bool enforceFileSizeLimit;
  final bool previewOnly;

  const PhotoRenderRequest({
    required this.bytes,
    required this.fileName,
    required this.preset,
    required this.enableHdMode,
    required this.dpi,
    required this.backgroundColor,
    required this.maxTargetKb,
    required this.aspectPresetId,
    required this.enforceFileSizeLimit,
    required this.previewOnly,
  });
}

class PhotoResizeService {
  const PhotoResizeService();

  static const List<PhotoSizePreset> presets = [
    PhotoSizePreset(id: 'passport', label: 'Passport Size - 413 x 531', width: 413, height: 531),
    PhotoSizePreset(id: 'visa', label: 'US Visa / Universal - 2 x 2 in', width: 1200, height: 1200),
    PhotoSizePreset(id: 'card', label: 'Card Size - 1050 x 675', width: 1050, height: 675),
    PhotoSizePreset(id: 'postcard', label: '4 x 6 Print - 1200 x 1800', width: 1200, height: 1800),
    PhotoSizePreset(id: 'studio', label: '5 x 7 Print - 1500 x 2100', width: 1500, height: 2100),
    PhotoSizePreset(id: 'profile_hd', label: 'Profile HD - 1080 x 1080', width: 1080, height: 1080),
    PhotoSizePreset(id: 'a4', label: 'A4 Portrait - 2480 x 3508', width: 2480, height: 3508),
  ];

  static const List<String> dpiOptions = ['300', '600'];
  static const List<String> backgroundOptions = ['#FFFFFF', '#E0F2FE'];

  static ({int width, int height}) resolveOutputDimensions(String presetId, String dpi) {
    final basePreset = presets.firstWhere(
      (preset) => preset.id == presetId,
      orElse: () => presets.first,
    );

    final multiplier = dpi == '600' ? 2 : 1;
    return (
      width: basePreset.width * multiplier,
      height: basePreset.height * multiplier,
    );
  }

  static String buildOutputFileTag(String dpi, String presetId, int maxKb) {
    return '${presetId}_${dpi}dpi_${maxKb}kb';
  }

  static ({int width, int height}) resolvePreviewTargetDimensions(
    PhotoSizePreset preset,
    String aspectPresetId,
    String dpi,
  ) {
    final fullDimensions = resolveOutputDimensions(preset.id, dpi);
    final scale = fullDimensions.width > 1200 || fullDimensions.height > 1200 ? 0.4 : 0.7;
    final previewWidth = (fullDimensions.width * scale).round().clamp(240, fullDimensions.width);
    final previewHeight = (fullDimensions.height * scale).round().clamp(240, fullDimensions.height);

    final aspectRatio = previewWidth / previewHeight;
    final targetRatio = aspectPresetId == 'square'
        ? 1.0
        : (preset.width / preset.height);

    if (aspectRatio.abs() > 0.001) {
      return (
        width: previewWidth,
        height: previewHeight,
      );
    }

    return (
      width: previewWidth,
      height: previewHeight,
    );
  }

  Future<PhotoResizeResult> upscalePhoto({
    required Uint8List bytes,
    required String fileName,
    required PhotoSizePreset preset,
    required bool enableHdMode,
    required String dpi,
    required String backgroundColor,
    required int maxTargetKb,
    required String aspectPresetId,
    bool enforceFileSizeLimit = true,
    bool previewOnly = false,
  }) async {
    final request = PhotoRenderRequest(
      bytes: bytes,
      fileName: fileName,
      preset: preset,
      enableHdMode: enableHdMode,
      dpi: dpi,
      backgroundColor: backgroundColor,
      maxTargetKb: maxTargetKb,
      aspectPresetId: aspectPresetId,
      enforceFileSizeLimit: enforceFileSizeLimit,
      previewOnly: previewOnly,
    );

    // Flutter web does not support the isolate primitives used by Isolate.run
    // (RawReceivePort). Run processing inline on web and keep isolate offload
    // for native targets.
    if (kIsWeb) {
      return _renderPhotoInIsolate(request);
    }

    try {
      return await Isolate.run(() => _renderPhotoInIsolate(request));
    } on UnsupportedError {
      return _renderPhotoInIsolate(request);
    }
  }

  Uint8List _encodeToTargetSize(
    img.Image image, {
    required bool enableHdMode,
    required int maxTargetKb,
    required bool enforceFileSizeLimit,
  }) {
    final maxTargetBytes = enforceFileSizeLimit ? maxTargetKb * 1024 : null;
    if (maxTargetBytes == null) {
      return Uint8List.fromList(img.encodeJpg(image, quality: enableHdMode ? 98 : 94));
    }

    var quality = enableHdMode ? 98 : 94;
    var workingImage = image;
    var encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));

    while (encoded.length > maxTargetBytes) {
      if (quality > 30) {
        quality -= 8;
        encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
        continue;
      }

      final nextWidth = (workingImage.width * 0.9).round();
      final nextHeight = (workingImage.height * 0.9).round();
      if (nextWidth < 200 || nextHeight < 200) {
        break;
      }

      workingImage = img.copyResize(
        workingImage,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.cubic,
      );
      quality = 70;
      encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
    }

    return encoded;
  }

  img.ColorRgb8 _parseBackgroundColor(String colorHex) {
    final normalized = colorHex.replaceFirst('#', '').toUpperCase();
    if (normalized.length != 6) {
      return img.ColorRgb8(255, 255, 255);
    }

    final r = int.tryParse(normalized.substring(0, 2), radix: 16) ?? 255;
    final g = int.tryParse(normalized.substring(2, 4), radix: 16) ?? 255;
    final b = int.tryParse(normalized.substring(4, 6), radix: 16) ?? 255;
    return img.ColorRgb8(r, g, b);
  }

  img.Image _prepareSource(img.Image source, {required bool enableHdMode}) {
    if (!enableHdMode) {
      return source;
    }

    // Keep the processing conservative and identity-safe: only mild color correction,
    // gentle upscaling, and clarity cleanup. No face reconstruction, no aggressive
    // synthesis, and no facial feature replacement.
    final boosted = _applyGentleColorBalance(source);
    final safeScale = 1.03;
    return img.copyResize(
      boosted,
      width: (boosted.width * safeScale).round(),
      height: (boosted.height * safeScale).round(),
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

  img.Image _applyGentleColorBalance(img.Image source) {
    final result = img.copyResize(
      source,
      width: source.width,
      height: source.height,
      interpolation: img.Interpolation.nearest,
    );

    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = (pixel.r * 1.01).round().clamp(0, 255);
        final g = (pixel.g * 1.005).round().clamp(0, 255);
        final b = (pixel.b * 1.005).round().clamp(0, 255);
        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }

  img.Image _sanitizeCanvas(img.Image canvas) {
    final result = img.copyResize(
      canvas,
      width: canvas.width,
      height: canvas.height,
      interpolation: img.Interpolation.nearest,
    );

    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.clamp(0, 255);
        final g = pixel.g.clamp(0, 255);
        final b = pixel.b.clamp(0, 255);
        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }
}

PhotoResizeResult _renderPhotoInIsolate(PhotoRenderRequest request) {
  final source = img.decodeImage(request.bytes);
  if (source == null) {
    throw StateError('Unsupported image format. Please use JPG, PNG, WEBP, or BMP.');
  }

  final prepared = _prepareSourceInIsolate(source, enableHdMode: request.enableHdMode);
  final targetDimensions = request.previewOnly
      ? PhotoResizeService.resolvePreviewTargetDimensions(request.preset, request.aspectPresetId, request.dpi)
      : _resolveTargetDimensions(request.preset, request.aspectPresetId, request.dpi);
  final fitted = _resizeToFitInIsolate(prepared, targetDimensions.width, targetDimensions.height);
  final canvas = img.Image(width: targetDimensions.width, height: targetDimensions.height);
  final bg = _parseBackgroundColorInIsolate(request.backgroundColor);
  img.fill(canvas, color: bg);

  final offsetX = ((targetDimensions.width - fitted.width) / 2).round();
  final offsetY = ((targetDimensions.height - fitted.height) / 2).round();
  img.compositeImage(canvas, fitted, dstX: offsetX, dstY: offsetY);

  final baseName = request.fileName.contains('.')
      ? request.fileName.substring(0, request.fileName.lastIndexOf('.'))
      : request.fileName;
  final outputName = '${baseName}_${request.preset.id}_${request.dpi}dpi_${request.maxTargetKb}kb${request.enableHdMode ? '_hd' : ''}.jpg';

  final safeCanvas = _sanitizeCanvasInIsolate(canvas);
  final encoded = _encodeToTargetSizeInIsolate(
    safeCanvas,
    enableHdMode: request.enableHdMode,
    maxTargetKb: request.maxTargetKb,
    enforceFileSizeLimit: request.enforceFileSizeLimit,
    previewOnly: request.previewOnly,
  );

  final outputLabel = '${request.aspectPresetId.toUpperCase()} • ${request.dpi} DPI • ≤ ${request.maxTargetKb}KB';

  return PhotoResizeResult(
    bytes: encoded,
    outputFileName: outputName,
    width: targetDimensions.width,
    height: targetDimensions.height,
    outputLabel: outputLabel,
  );
}

({int width, int height}) _resolveTargetDimensions(PhotoSizePreset preset, String aspectPresetId, String dpi) {
  final multiplier = dpi == '600' ? 2 : 1;
  switch (aspectPresetId) {
    case 'passport':
      return (width: 413 * multiplier, height: 531 * multiplier);
    case 'visa':
      return (width: 1200, height: 1200);
    case 'square':
      return (width: preset.width * multiplier, height: preset.width * multiplier);
    default:
      return (width: preset.width * multiplier, height: preset.height * multiplier);
  }
}

img.Image _prepareSourceInIsolate(img.Image source, {required bool enableHdMode}) {
  if (!enableHdMode) {
    return source;
  }

  final boosted = _applyGentleColorBalanceInIsolate(source);
  final safeScale = 1.03;
  return img.copyResize(
    boosted,
    width: (boosted.width * safeScale).round(),
    height: (boosted.height * safeScale).round(),
    interpolation: img.Interpolation.cubic,
  );
}

img.Image _resizeToFitInIsolate(img.Image source, int targetWidth, int targetHeight) {
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

img.Image _applyGentleColorBalanceInIsolate(img.Image source) {
  final result = img.copyResize(
    source,
    width: source.width,
    height: source.height,
    interpolation: img.Interpolation.nearest,
  );

  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = (pixel.r * 1.01).round().clamp(0, 255);
      final g = (pixel.g * 1.005).round().clamp(0, 255);
      final b = (pixel.b * 1.005).round().clamp(0, 255);
      result.setPixelRgb(x, y, r, g, b);
    }
  }

  return result;
}

img.ColorRgb8 _parseBackgroundColorInIsolate(String colorHex) {
  final normalized = colorHex.replaceFirst('#', '').toUpperCase();
  if (normalized.length != 6) {
    return img.ColorRgb8(255, 255, 255);
  }

  final r = int.tryParse(normalized.substring(0, 2), radix: 16) ?? 255;
  final g = int.tryParse(normalized.substring(2, 4), radix: 16) ?? 255;
  final b = int.tryParse(normalized.substring(4, 6), radix: 16) ?? 255;
  return img.ColorRgb8(r, g, b);
}

img.Image _sanitizeCanvasInIsolate(img.Image canvas) {
  final result = img.copyResize(
    canvas,
    width: canvas.width,
    height: canvas.height,
    interpolation: img.Interpolation.nearest,
  );

  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = pixel.r.clamp(0, 255);
      final g = pixel.g.clamp(0, 255);
      final b = pixel.b.clamp(0, 255);
      result.setPixelRgb(x, y, r, g, b);
    }
  }

  return result;
}

Uint8List _encodeToTargetSizeInIsolate(
  img.Image image, {
    required bool enableHdMode,
    required int maxTargetKb,
    required bool enforceFileSizeLimit,
    required bool previewOnly,
  }) {
  if (previewOnly) {
    return Uint8List.fromList(img.encodeJpg(image, quality: 82));
  }

  final maxTargetBytes = enforceFileSizeLimit ? maxTargetKb * 1024 : null;
  if (maxTargetBytes == null) {
    return Uint8List.fromList(img.encodeJpg(image, quality: enableHdMode ? 98 : 94));
  }

  var quality = enableHdMode ? 98 : 94;
  var workingImage = image;
  var encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));

  while (encoded.length > maxTargetBytes) {
    if (quality > 30) {
      quality -= 8;
      encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
      continue;
    }

    final nextWidth = (workingImage.width * 0.9).round();
    final nextHeight = (workingImage.height * 0.9).round();
    if (nextWidth < 200 || nextHeight < 200) {
      break;
    }

    workingImage = img.copyResize(
      workingImage,
      width: nextWidth,
      height: nextHeight,
      interpolation: img.Interpolation.cubic,
    );
    quality = 70;
    encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
  }

  return encoded;
}
