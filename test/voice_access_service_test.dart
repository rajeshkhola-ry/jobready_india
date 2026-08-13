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

    test('allows direct launch from the voice surface for guest users and free accounts', () {
      final launchReady = VoiceAccessService.shouldLaunchVoiceTool(
        isAdminSession: false,
        isSignedIn: false,
        planId: 'free',
      );

      expect(launchReady, isTrue);
      expect(
        VoiceAccessService.statusLabel(
          isAdminSession: false,
          isSignedIn: false,
        ),
        'Voice Access',
      );
      expect(
        VoiceAccessService.primaryActionLabel(
          isAdminSession: false,
          isSignedIn: false,
          planId: 'free',
        ),
        '🚀 Launch Tool',
      );
    });
  });
}
