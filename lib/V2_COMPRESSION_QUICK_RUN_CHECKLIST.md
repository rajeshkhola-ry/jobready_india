# V2 Compression Quick Run Checklist

## Goal
Fast daily validation for V2 compression core on current site.

## Inputs (3 PDFs)
- [ ] Text-heavy PDF available in `lib/test_assets/`
- [ ] Mixed-content PDF available in `lib/test_assets/`
- [ ] Image-heavy PDF available in `lib/test_assets/`

## Quick Benchmark Steps
1. Run each file in Standard mode and note output size.
2. Run each file in High Compression (Image-Only) mode and note output size.
3. Record reduction percentages for both modes.

## Quick Results Table
| File Type | File Name | Original | Standard | High (Image-Only) | Better Mode |
|---|---|---:|---:|---:|---|
| Text-heavy | <name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |
| Mixed-content | <name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |
| Image-heavy | <name>.pdf | X.XX MB | X.XX MB (-YY%) | X.XX MB (-YY%) | Standard / High |

## Live Site Spot Check
- [ ] Upload each sample via homepage Browse File
- [ ] Toggle Standard vs High works
- [ ] Download works in one-page flow
- [ ] Output files open correctly

## Acceptance
- [ ] Standard mode keeps readability
- [ ] High mode significantly better on image-heavy PDFs
- [ ] Image-heavy test demonstrates aggressive reduction trend toward ~1 MB to ~100 KB when source allows

## Deployment Gate
- [ ] Commit SHA recorded
- [ ] Workflow success confirmed
- [ ] Live build-info commit matches deployed SHA

## Sign-off
- Date: __________
- Owner: __________
- Decision: Pass / Hold
