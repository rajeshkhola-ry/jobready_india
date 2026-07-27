# V2 Compression Core Benchmark Report

## Scope
- Project: GET READY JOB (current site)
- Feature: PDF/Image Compression Core (V2)
- Modes under test:
  - Standard
  - High Compression (Image-Only)

## Objective
Validate compression effectiveness and usability before rollout confirmation on live site.

## Test Assets
Place three sample PDFs in `lib/test_assets/`:
1. Text-heavy PDF (mostly text, minimal images)
2. Mixed-content PDF (text + some images)
3. Image-heavy PDF (scanned/photo-based pages)

## Benchmark Procedure
1. Run compression for each sample in Standard mode.
2. Run compression for each sample in High Compression (Image-Only) mode.
3. Record original size, compressed size, and reduction percentage.
4. Compare readability and output stability.

## Benchmark Results
| File Type | Sample File | Original Size | Standard Mode | High Compression Mode | Winner |
|---|---|---:|---:|---:|---|
| Text-heavy | <file_name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |
| Mixed content | <file_name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |
| Image-heavy | <file_name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |

## Acceptance Targets
- Standard mode: maintain readability with moderate reduction.
- High mode: strong reduction for image-heavy documents.
- Stretch target for image-heavy docs: around 1 MB to around 100 KB when source characteristics allow.

## Live Verification Checklist (getreadyjob.com)
- [ ] Upload each sample PDF from homepage Browse File flow.
- [ ] Toggle between Standard and High Compression (Image-Only).
- [ ] Download output for each mode and record final size.
- [ ] Confirm one-page flow (no unexpected redirects).
- [ ] Confirm output files open correctly.

## Deployment Evidence
- Branch: <branch_name>
- Commit SHA: <sha>
- Workflow run URL: <url>
- build-info.json commit: <sha>
- Live test URL: https://getreadyjob.com/

## Final Sign-off
- [ ] V2 compression core benchmark completed
- [ ] Live verification completed
- [ ] Deployment completed
- [ ] Approval: V2 compression core validated and live on current site

## Notes
- Any inability to hit target size should be documented with source characteristics.
- Include quality/readability observations for each output file.
