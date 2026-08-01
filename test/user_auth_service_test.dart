import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/user_account_service.dart';
import 'package:jobready_india/Services/user_auth_service.dart';

void main() {
  group('UserAuthService.canProceedToPayment', () {
    test('allows signed-in users even when the profile is incomplete', () {
      final incompleteProfile = UserAccountProfile.initial();

      final canProceed = UserAuthService.canProceedToPayment(
        profile: incompleteProfile,
        isSignedInOverride: true,
      );

      expect(canProceed, isTrue);
    });

    test('blocks signed-out users when the profile is incomplete', () {
      final incompleteProfile = UserAccountProfile.initial();

      final canProceed = UserAuthService.canProceedToPayment(
        profile: incompleteProfile,
        isSignedInOverride: false,
      );

      expect(canProceed, isFalse);
    });

    test('allows signed-out users when the profile is complete', () {
      final completeProfile = UserAccountProfile.initial().copyWith(
        displayName: 'Ada Lovelace',
        email: 'ada@example.com',
        country: 'India',
        mobileNumber: '9876543210',
      );

      final canProceed = UserAuthService.canProceedToPayment(
        profile: completeProfile,
        isSignedInOverride: false,
      );

      expect(canProceed, isTrue);
    });
  });
}
