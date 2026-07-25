# GETREADYJOB V1.1 Recovery Runbook

## Fast Restore (Primary)

1. Checkout baseline branch:
   git checkout release/v1.1-baseline
2. Confirm baseline tag:
   git tag -l prod/v1.1-baseline
3. Rebuild:
   flutter clean
   flutter pub get
   flutter build web --release -t lib/main_v1_1.dart --base-href "/"
4. Deploy build/web using GitHub Pages workflow.

## Bundle Restore (Disaster Recovery)

1. Obtain baseline bundle from OneDrive RELEASES or PRODUCTION snapshot.
2. Verify bundle:
   git bundle verify <bundle-path>
3. Import refs:
   git fetch <bundle-path> prod/v1.1-baseline:prod/v1.1-baseline release/v1.1-baseline:release/v1.1-baseline
4. Checkout branch:
   git checkout release/v1.1-baseline
5. Rebuild and redeploy as above.

## Mandatory Verification After Restore

- Build command succeeds with lib/main_v1_1.dart
- Homepage loads successfully
- PDF tool navigation works
- Footer/legal pages open
- build-info.json entrypoint is lib/main_v1_1.dart

## Prohibited Actions

- Do not retag prod/v1.1-baseline
- Do not force-push release/v1.1-baseline
- Do not delete OneDrive baseline snapshots
