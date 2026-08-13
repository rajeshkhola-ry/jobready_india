import 'auth_router_service.dart';
import 'owner_admin_access_service.dart';
import 'plan_catalog_service.dart';
import 'user_auth_service.dart';

class VoiceAccessService {
  static String _normalizePlanName(String? planId) {
    final normalized = (planId ?? '').trim();
    if (normalized.isEmpty) {
      return 'Free';
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('7day')) {
      return '7Days';
    }
    if (lower.contains('month')) {
      return 'Monthly';
    }
    if (lower.contains('year')) {
      return 'Yearly';
    }
    if (lower.contains('lifetime')) {
      return 'Lifetime';
    }
    if (lower == 'free') {
      return 'Free';
    }
    return normalized;
  }

  static bool hasActiveToolAccess(String? planId) {
    final normalizedPlan = _normalizePlanName(planId);
    return normalizedPlan != 'Free' && PlanCatalogConfig.isPaidPlan(normalizedPlan);
  }

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

    return hasActiveToolAccess(planId);
  }

  static String statusLabel({bool? isAdminSession, bool? isSignedIn}) {
    if (hasAdminSession(isAdminSession: isAdminSession)) {
      return 'Admin Signed In';
    }

    if (hasUserSession(isSignedIn: isSignedIn)) {
      return 'User Account';
    }

    return 'Voice Access';
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

    return '🚀 Launch Tool';
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
