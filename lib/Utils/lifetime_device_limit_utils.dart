String buildLifetimeDeviceLimitNotice() {
  return 'Lifetime Plan device limit reached. This account can be used on 1 desktop/laptop and 1 mobile device only.';
}

bool shouldBlockLifetimeDeviceLogin({
  required int existingDesktopCount,
  required int existingMobileCount,
  required String deviceType,
}) {
  final normalizedType = deviceType.trim().toLowerCase();
  final isDesktop = normalizedType == 'desktop';
  final isMobile = normalizedType == 'mobile';

  if ((isDesktop && existingDesktopCount >= 1) ||
      (isMobile && existingMobileCount >= 1) ||
      (existingDesktopCount + existingMobileCount) >= 2) {
    return true;
  }

  return false;
}
