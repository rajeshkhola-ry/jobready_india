import 'auth_router_service.dart';
import 'owner_admin_access_service.dart';
import 'plan_catalog_service.dart';
import 'user_auth_service.dart';

class VoiceAccessService {
  static bool hasAdminSession({bool? isAdminSession}) {
    if (isAdminSession != null) {
      return isAdminSession;
    }

    final role = AuthRouterService.getCurrentRole();
    final isAdminByStorage = role == 'admin';
    final isUnlockedSession = OwnerAdminAccessService.isUnlocked && OwnerAdminAccessService.isTwoFactorVerifiedForSession;
    return isAdminByStorage || isUnlockedSession;
  }

  static bool hasUserSession({bool? isSignedIn}) {
    if (isSignedIn != null) {
      return isSignedIn;
    }

    return UserAuthService.isSignedIn || AuthRouterService.getCurrentRole() == 'user';
  }

  static bool hasVoiceLaunchAccess({
    String? planId,
    bool? isAdminSession,
    bool? isSignedIn,
  }) {
    final adminSession = hasAdminSession(isAdminSession: isAdminSession);
    if (adminSession) {
      return true;
    }

    final signedIn = hasUserSession(isSignedIn: isSignedIn);
    if (!signedIn) {
      return false;
    }

    return PlanService.hasActiveToolAccess(
      role: 'user',
      planId: planId,
    );
  }

  static String statusLabel({bool? isAdminSession, bool? isSignedIn}) {
    if (hasAdminSession(isAdminSession: isAdminSession)) {
      return 'Admin Signed In';
    }

    if (hasUserSession(isSignedIn: isSignedIn)) {
      return 'User Account';
    }

    return 'Sign in';
  }

  static String primaryActionLabel({
    String? planId,
    bool? isAdminSession,
    bool? isSignedIn,
  }) {
    if (hasVoiceLaunchAccess(
      planId: planId,
      isAdminSession: isAdminSession,
      isSignedIn: isSignedIn,
    )) {
      return '🚀 Launch Tool';
    }

    if (hasUserSession(isSignedIn: isSignedIn)) {
      return 'User Account';
    }

    return 'Sign in';
  }

  static bool shouldLaunchVoiceTool({
    String? planId,
    bool? isAdminSession,
    bool? isSignedIn,
  }) {
    return hasVoiceLaunchAccess(
      planId: planId,
      isAdminSession: isAdminSession,
      isSignedIn: isSignedIn,
    );
  }
}
