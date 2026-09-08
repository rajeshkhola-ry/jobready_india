import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Decodes [bytes] straight to [width]x[height] using the platform image codec.
///
/// This exists because `compute()` has no isolate on Flutter Web - it runs the
/// callback inline on the one and only UI thread. Decoding a full-resolution
/// camera photo with `package:image` there blocks the browser tab for seconds.
/// `ui.instantiateImageCodec` hands the decode *and* the downscale to the
/// platform codec, so only the small result ever reaches Dart.
///
/// Returns null when the platform codec cannot handle the input, so callers can
/// fall back to the pure-Dart path.
Future<img.Image?> decodeImageScaled(
  Uint8List bytes, {
  required int width,
  required int height,
}) async {
  if (bytes.isEmpty || width <= 0 || height <= 0) {
    return null;
  }

  ui.Codec? codec;
  ui.Image? decoded;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    decoded = frame.image;

    final data = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return null;
    }

    return img.Image.fromBytes(
      width: decoded.width,
      height: decoded.height,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } catch (_) {
    return null;
  } finally {
    decoded?.dispose();
    codec?.dispose();
  }
}
