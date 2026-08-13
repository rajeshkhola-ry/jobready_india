import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/voice_access_service.dart';

void main() {
  group('VoiceAccessService', () {
    test('returns admin launch state when admin session is active', () {
      final launchReady = VoiceAccessService.shouldLaunchVoiceTool(
        isAdminSession: true,
        isSignedIn: false,
        planId: 'free',
      );

      expect(launchReady, isTrue);
      expect(
        VoiceAccessService.statusLabel(isAdminSession: true, isSignedIn: false),
        'Admin Signed In',
      );
    });

    test('returns launch state for active paid plans', () {
      final launchReady = VoiceAccessService.shouldLaunchVoiceTool(
        isAdminSession: false,
        isSignedIn: true,
        planId: 'Monthly',
      );

      expect(launchReady, isTrue);
      expect(
        VoiceAccessService.statusLabel(isAdminSession: false, isSignedIn: true),
        'User Account',
      );
    });

    test('blocks launch for free users without admin or paid access', () {
      final launchReady = VoiceAccessService.shouldLaunchVoiceTool(
        isAdminSession: false,
        isSignedIn: true,
        planId: 'free',
      );

      expect(launchReady, isFalse);
      expect(
        VoiceAccessService.primaryActionLabel(
          isAdminSession: false,
          isSignedIn: true,
          planId: 'free',
        ),
        'User Account',
      );
    });
  });
}
