import 'dart:isolate';
import 'dart:math';
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

  static PhotoSizePreset presetById(String presetId) {
    return presets.firstWhere(
      (preset) => preset.id == presetId,
      orElse: () => presets.first,
    );
  }

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
      if (quality > 42) {
        quality -= quality > 80 ? 4 : 6;
        encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
        continue;
      }

      final nextWidth = (workingImage.width * 0.92).round();
      final nextHeight = (workingImage.height * 0.92).round();
      if (nextWidth < 220 || nextHeight < 220) {
        break;
      }

      workingImage = img.copyResize(
        workingImage,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.cubic,
      );
      workingImage = _applyUnsharpMask(workingImage, amount: 0.22, radius: 1, threshold: 3);
      quality = 74;
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
    final resized = img.copyResize(
      boosted,
      width: (boosted.width * safeScale).round(),
      height: (boosted.height * safeScale).round(),
      interpolation: img.Interpolation.cubic,
    );
    final contrasted = _applyAutoContrast(resized);
    return _applyUnsharpMask(contrasted, amount: 0.20, radius: 1, threshold: 4);
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

    final resized = _progressiveResize(
      source,
      width: outputWidth,
      height: outputHeight,
      interpolation: img.Interpolation.cubic,
    );
    final contrasted = _applyAutoContrast(resized);
    return _applyUnsharpMask(contrasted, amount: 0.24, radius: 1, threshold: 3);
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

  img.Image _progressiveResize(
    img.Image source, {
    required int width,
    required int height,
    required img.Interpolation interpolation,
  }) {
    var working = source;
    while (working.width > width * 2 || working.height > height * 2) {
      final nextWidth = max(width, (working.width * 0.75).round());
      final nextHeight = max(height, (working.height * 0.75).round());
      if (nextWidth == working.width && nextHeight == working.height) {
        break;
      }
      working = img.copyResize(
        working,
        width: nextWidth,
        height: nextHeight,
        interpolation: interpolation,
      );
    }

    return img.copyResize(
      working,
      width: width,
      height: height,
      interpolation: interpolation,
    );
  }

  img.Image _applyAutoContrast(img.Image source) {
    final histogram = List<int>.filled(256, 0);
    final result = img.copyResize(
      source,
      width: source.width,
      height: source.height,
      interpolation: img.Interpolation.nearest,
    );

    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
        histogram[luminance]++;
      }
    }

    final totalPixels = result.width * result.height;
    final lowCut = (totalPixels * 0.01).round();
    final highCut = (totalPixels * 0.99).round();

    var running = 0;
    var low = 0;
    for (; low < 255; low++) {
      running += histogram[low];
      if (running >= lowCut) {
        break;
      }
    }

    running = 0;
    var high = 255;
    for (; high > 0; high--) {
      running += histogram[high];
      if (running >= totalPixels - highCut) {
        break;
      }
    }

    if (high <= low + 8) {
      return result;
    }

    final span = (high - low).toDouble();
    final contrastBoost = min(1.10, 255 / span);
    final adjusted = img.copyResize(
      result,
      width: result.width,
      height: result.height,
      interpolation: img.Interpolation.nearest,
    );

    for (var y = 0; y < adjusted.height; y++) {
      for (var x = 0; x < adjusted.width; x++) {
        final pixel = adjusted.getPixel(x, y);
        final r = _stretchChannel(pixel.r, low, high, contrastBoost);
        final g = _stretchChannel(pixel.g, low, high, contrastBoost);
        final b = _stretchChannel(pixel.b, low, high, contrastBoost);
        adjusted.setPixelRgb(x, y, r, g, b);
      }
    }

    return adjusted;
  }

  int _stretchChannel(num value, int low, int high, double contrastBoost) {
    final clamped = value.clamp(0, 255).toDouble();
    if (high <= low) {
      return clamped.round().clamp(0, 255);
    }

    final normalized = ((clamped - low) / (high - low)).clamp(0.0, 1.0);
    final centered = (normalized - 0.5) * contrastBoost + 0.5;
    return (centered * 255).round().clamp(0, 255);
  }

  img.Image _applyUnsharpMask(
    img.Image source, {
    required double amount,
    required int radius,
    required int threshold,
  }) {
    final blurred = _boxBlur(source, radius: radius);
    final result = img.copyResize(
      source,
      width: source.width,
      height: source.height,
      interpolation: img.Interpolation.nearest,
    );

    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final original = source.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final rDiff = original.r - blur.r;
        final gDiff = original.g - blur.g;
        final bDiff = original.b - blur.b;

        final diffMagnitude = ((rDiff.abs() + gDiff.abs() + bDiff.abs()) / 3).round();
        if (diffMagnitude < threshold) {
          result.setPixelRgb(x, y, original.r.round(), original.g.round(), original.b.round());
          continue;
        }

        final r = (original.r + (rDiff * amount)).round().clamp(0, 255);
        final g = (original.g + (gDiff * amount)).round().clamp(0, 255);
        final b = (original.b + (bDiff * amount)).round().clamp(0, 255);
        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }

  img.Image _boxBlur(img.Image source, {required int radius}) {
    final result = img.copyResize(
      source,
      width: source.width,
      height: source.height,
      interpolation: img.Interpolation.nearest,
    );

    final diameter = radius * 2 + 1;
    final sampleCount = diameter * diameter;

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        var r = 0.0;
        var g = 0.0;
        var b = 0.0;

        for (var oy = -radius; oy <= radius; oy++) {
          final sy = (y + oy).clamp(0, source.height - 1);
          for (var ox = -radius; ox <= radius; ox++) {
            final sx = (x + ox).clamp(0, source.width - 1);
            final pixel = source.getPixel(sx, sy);
            r += pixel.r;
            g += pixel.g;
            b += pixel.b;
          }
        }

        result.setPixelRgb(
          x,
          y,
          (r / sampleCount).round().clamp(0, 255),
          (g / sampleCount).round().clamp(0, 255),
          (b / sampleCount).round().clamp(0, 255),
        );
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
