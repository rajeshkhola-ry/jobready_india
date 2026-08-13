export function shouldOpenMainSiteForGuestAccess(isSignedIn: boolean): boolean {
  return !isSignedIn;
}

export function getMainSiteAccessMessage(): string {
  return "Please sign in on the main homepage (getreadyjob.com) using Google, Apple, Microsoft, or Email to recharge your pass and access all AI Voice tools!";
}
