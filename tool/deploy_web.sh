#!/bin/bash
# Builds the Flutter web release, stamps flutter_bootstrap.js's cache-busting
# version with a fresh value derived from the current git commit + timestamp
# (replacing the __GRJ_BUILD_VERSION__ placeholder left by web/flutter_bootstrap.js),
# then deploys to Firebase Hosting.
#
# This exists because main.dart.js is served with Cache-Control: max-age=3600,
# and flutter_bootstrap.js appends `?v=<entrypointVersion>` to its URL purely
# to bust that cache on deploy. A fixed/hardcoded entrypointVersion means any
# content change to main.dart.js can stay stuck behind a stale cached response
# for up to an hour after every future deploy, not just once - so the version
# must be regenerated here every time, not hand-edited in the source file.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building Flutter web release..."
flutter build web --release

BOOTSTRAP="build/web/flutter_bootstrap.js"
if [ ! -f "$BOOTSTRAP" ]; then
  echo "ERROR: $BOOTSTRAP not found after build" >&2
  exit 1
fi

VERSION="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)-$(date -u +%Y%m%d%H%M%S)"
echo "Stamping build version: $VERSION"

sed -i.bak "s/__GRJ_BUILD_VERSION__/$VERSION/" "$BOOTSTRAP"
rm -f "$BOOTSTRAP.bak"

if ! grep -q "$VERSION" "$BOOTSTRAP"; then
  echo "ERROR: version stamp substitution failed - __GRJ_BUILD_VERSION__ placeholder not found in $BOOTSTRAP" >&2
  exit 1
fi

echo "Deploying to Firebase Hosting..."
npx --yes firebase-tools deploy --only hosting

echo "Deploy complete. main.dart.js cache-buster version: $VERSION"
