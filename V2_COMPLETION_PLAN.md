# JOBREADY V2 Completion Plan

This file is the single source of truth for V2 closure.

## Goal
Deliver a stable V2 web app with tested core tools and launch-ready deployment steps.

## Scope Lock
- No large redesigns until bug closure is complete.
- Priority is stability, output correctness, and predictable user flow.
- V1 and V2 remain separate entrypoints until explicit merge approval.

## Core Acceptance Criteria
- Home page loads reliably from one active URL.
- Upload works for single and multiple files.
- Convert produces valid output files.
- Merge generates a downloadable merged PDF.
- Split generates downloadable split files (ZIP package).
- Extract generates downloadable output (text/images where supported).
- Coupon flow works:
  - Generate 100, 80, 20 percent discount.
  - One-time redeem behavior enforced.
  - Optional 7-day active window works.
  - Premium plan amount updates after valid redeem.

## Test Pass Checklist
- Home: navigation and upload card
- Convert: select file, convert, download and open
- Merge: select 2+ PDFs, merge, download and open
- Split: split range, download ZIP, open files
- Extract: extraction path, download result
- Coupon: generate, redeem once, second redeem rejected

## Operating Rules During Closure
- Keep one active runtime port only.
- Provide one confirmed URL after each fix batch.
- Validate with compile checks before handing over for retest.

## Current Runtime
- Active verified URL: http://localhost:54340/#/home
- If URL stops responding, restart with:
  - powershell -ExecutionPolicy Bypass -File scripts/run_v2_port54340.ps1

## Separation Commands
- V1 run: powershell -ExecutionPolicy Bypass -File scripts/run_v1_port54341.ps1
- V2 run: powershell -ExecutionPolicy Bypass -File scripts/run_v2_port54340.ps1
