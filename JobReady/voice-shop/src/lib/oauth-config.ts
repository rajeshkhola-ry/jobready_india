export type OAuthProvider = "google" | "microsoft";

export function getOAuthConfig(provider: OAuthProvider) {
  const google = provider === "google";
  return {
    clientId: (google ? process.env.GOOGLE_CLIENT_ID : process.env.MICROSOFT_CLIENT_ID)?.trim() || "",
    clientSecret: (google ? process.env.GOOGLE_CLIENT_SECRET : process.env.MICROSOFT_CLIENT_SECRET)?.trim() || "",
    redirectUri: (google ? process.env.GOOGLE_REDIRECT_URI : process.env.MICROSOFT_REDIRECT_URI)?.trim() || "",
  };
}

export function isOAuthConfigured(provider: OAuthProvider) {
  const config = getOAuthConfig(provider);
  return Boolean(config.clientId && config.clientSecret && config.redirectUri);
}

export function availableOAuthProviders() {
  return {
    google: isOAuthConfigured("google"),
    microsoft: isOAuthConfigured("microsoft"),
  };
}
