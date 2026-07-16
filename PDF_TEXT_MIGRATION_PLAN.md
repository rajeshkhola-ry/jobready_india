# PDF Text Migration Plan

## Current Plugin
- Package: `pdf_text`
- Declared as a direct dependency in root `pubspec.yaml`.
- Locked version: `0.5.0`.
- Direct evidence in project:
  - `c:/JobReadyIndia/jobready_india/pubspec.yaml` contains `pdf_text: ^0.5.0`.
  - `c:/JobReadyIndia/jobready_india/pubspec.lock` contains `pdf_text` with `dependency: "direct main"` and `version: "0.5.0"`.

## Why It Fails
- `pdf_text` is outdated for modern Flutter/Android toolchains.
- Upstream package metadata shows old SDK bounds:
  - `sdk: ">=2.12.0 <3.0.0"`
  - `flutter: ">=1.12.0"`
- Last published release (from pub.dev API): `2021-03-14`.
- The plugin uses legacy Android stack assumptions (older Android Gradle plugin/Kotlin era), which conflicts with current Flutter 3.x + modern Gradle/AGP.
- Your build history already showed repeated Android resolution/tooling failures around this path, consistent with legacy plugin incompatibility.

## Maintenance Status
- `pdf_text`: effectively unmaintained for current Flutter ecosystem (no release since 2021; Dart <3 upper bound).
- `syncfusion_flutter_pdf`: actively maintained (latest release from pub.dev API is recent: `34.1.31` published `2026-07-14`).
- `google_mlkit_text_recognition`: actively maintained (latest release from pub.dev API is `0.16.0` published `2026-07-07`).

## Recommended Replacement
### Primary replacement
- Replace `pdf_text` with `syncfusion_flutter_pdf` for embedded text extraction.
- Reason:
  - Fully Dart-first package, modern Flutter compatibility.
  - Already present in your project and already used in multiple services/pages.
  - Minimizes migration scope and risk.

### Optional OCR layer (for scanned/image PDFs)
- Add `google_mlkit_text_recognition` only if you need on-device OCR.
- Keep OCR behind a feature path so basic PDF text extraction remains stable.

## Files To Modify (planned, not yet changed)
- `c:/JobReadyIndia/jobready_india/pubspec.yaml`
  - Remove `pdf_text` dependency.
  - (Optional) Add `google_mlkit_text_recognition` if OCR is needed.
- `c:/JobReadyIndia/jobready_india/pubspec.lock`
  - Regenerate via `flutter pub get` after dependency changes.
- Potential cleanup (only if found):
  - Any Dart files importing `package:pdf_text/...`.
  - Any code paths using `PDFDoc`/`PDFText` APIs.

## Migration Effort Estimate
- Scenario A: `pdf_text` only in dependencies (no runtime imports): **30-60 minutes**
  - Remove dependency, run pub get, run build/test sanity checks.
- Scenario B: small amount of legacy `pdf_text` API usage exists: **2-4 hours**
  - Refactor extraction calls to `syncfusion_flutter_pdf`, verify edge cases.
- Scenario C: include new on-device OCR path with ML Kit: **0.5-1.5 days**
  - Add OCR package, implement image-per-page pipeline, QA performance/device behavior.

## Risks
- Removing `pdf_text` may expose hidden/unreachable legacy code paths if any still depend on it.
- `syncfusion_flutter_pdf` extracts embedded text only; scanned PDFs still need OCR.
- OCR integration introduces platform setup and performance variance across devices.
- If Android build scripts were manually patched in Pub cache earlier, those patches are non-reproducible; migration should avoid relying on cache patching.

## Recommendation Summary
- Proceed with dependency cleanup first: remove `pdf_text` and standardize on `syncfusion_flutter_pdf`.
- Keep OCR as a separate, controlled phase if required for scanned PDF support.
- This is the lowest-risk, Flutter 3.x-compatible migration path for your current codebase.
