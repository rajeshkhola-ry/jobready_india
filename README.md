# JOBREADY

Flutter web application for document workflows (compress, convert, merge, split, extract) with pricing and coupon testing.

## Version Separation (Important)

- V1 is kept separate for stability checks.
- V2 development continues separately and will be merged into V1 only after your approval.

## V1 Stable Local Run

Use this command:

```
powershell -ExecutionPolicy Bypass -File scripts/run_v1_port54341.ps1
```

Then open:

```
http://localhost:54341/#/home
```

## V2 Stable Local Run

Use this command:

```
powershell -ExecutionPolicy Bypass -File scripts/run_v2_port54340.ps1
```

Then open:

```
http://localhost:54340/#/home
```

## Create Release Package

V1 package:

```
powershell -ExecutionPolicy Bypass -File scripts/package_web_release_v1.ps1
```

V2 package:

```
powershell -ExecutionPolicy Bypass -File scripts/package_web_release_v2.ps1
```

Legacy combined V2 package script (still available):

```
powershell -ExecutionPolicy Bypass -File scripts/package_web_release.ps1
```

Output files:

```
release/jobready_v1_web.zip
release/jobready_v2_web.zip
release/jobready_web.zip
```

## Project Tracking

- V2 closure checklist: [V2_COMPLETION_PLAN.md](V2_COMPLETION_PLAN.md)
- Internet launch guide: [INTERNET_LAUNCH_GUIDE.md](INTERNET_LAUNCH_GUIDE.md)

## Notes

- Keep one active runtime port to avoid stale UI confusion.
- For V2 testing, use the same URL during a single test session.
