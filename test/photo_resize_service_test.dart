import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jobready_india/Services/photo_resize_service.dart';

void main() {
  group('PhotoResizeService output targeting', () {
    test('resolves passport and visa dimensions for the selected DPI', () {
      final passport = PhotoResizeService.resolveOutputDimensions('passport', '300');
      final visa = PhotoResizeService.resolveOutputDimensions('visa', '600');

      expect(passport.width, 413);
      expect(passport.height, 531);
      expect(visa.width, 1200);
      expect(visa.height, 1200);
    });

    test('builds a printable output tag with DPI and size target', () {
      expect(
        PhotoResizeService.buildOutputFileTag('300', 'passport', 50),
        'passport_300dpi_50kb',
      );
    });

    test('compresses output to the requested size target when enabled', () async {
      final service = const PhotoResizeService();
      final source = img.Image(width: 1200, height: 900);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, 120, 160, 220);
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 100));

      final result = await service.upscalePhoto(
        bytes: bytes,
        fileName: 'sample.jpg',
        preset: PhotoResizeService.presets.first,
        enableHdMode: false,
        dpi: '300',
        backgroundColor: '#FFFFFF',
        maxTargetKb: 50,
        aspectPresetId: 'passport',
        enforceFileSizeLimit: true,
      );

      expect(result.bytes.length, lessThanOrEqualTo(50 * 1024));
    });
  });
}
