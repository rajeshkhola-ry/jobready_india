import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Utils/lifetime_device_limit_utils.dart';

void main() {
  group('lifetime device limit checks', () {
    test('allows the first mobile device when no lifetime devices are registered yet', () {
      expect(
        shouldBlockLifetimeDeviceLogin(
          existingDesktopCount: 0,
          existingMobileCount: 0,
          deviceType: 'mobile',
        ),
        isFalse,
      );
    });

    test('blocks a second desktop device once one desktop is already registered', () {
      expect(
        shouldBlockLifetimeDeviceLogin(
          existingDesktopCount: 1,
          existingMobileCount: 0,
          deviceType: 'desktop',
        ),
        isTrue,
      );
    });

    test('blocks a third device once both allowed device slots are already occupied', () {
      expect(
        shouldBlockLifetimeDeviceLogin(
          existingDesktopCount: 1,
          existingMobileCount: 1,
          deviceType: 'mobile',
        ),
        isTrue,
      );
    });

    test('returns a clear lifetime device notice for the UI', () {
      expect(
        buildLifetimeDeviceLimitNotice(),
        contains('1 desktop/laptop'),
      );
      expect(
        buildLifetimeDeviceLimitNotice(),
        contains('1 mobile'),
      );
    });
  });
}
