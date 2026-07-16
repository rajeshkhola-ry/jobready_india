# JOBREADY Internet Launch Guide

You do not need deep deployment knowledge. We can split responsibilities clearly.

## Who Does What
- Copilot (me):
  - Prepare build scripts and deployment-ready output.
  - Set routing and static hosting requirements.
  - Validate launch checklist and smoke tests.
- You:
  - Own account login and billing approvals on hosting platform.
  - Own domain purchase/DNS access if using custom domain.

## Fastest Launch Path (Recommended)
Use Netlify Drop first for a quick public test URL.

### Steps
1. Build release files:
   - powershell -ExecutionPolicy Bypass -File scripts/package_web_release.ps1
2. Open Netlify Drop:
   - https://app.netlify.com/drop
3. Upload file:
   - release/jobready_web.zip (or unzip and upload build/web contents)
4. Netlify gives a public URL instantly.

## Production Launch Path (After Final QA)
Choose one platform:
- Netlify
- Firebase Hosting
- Vercel (static)

For first launch, Netlify is simplest and fastest.

## Domain Connection (Optional)
1. Buy domain or use existing domain.
2. In hosting dashboard, connect domain.
3. Add DNS records in your domain provider panel.

## Pre-Launch Checklist
- Final V2 QA pass complete.
- No blocking errors in core tools.
- Download outputs validated for convert/merge/split/extract.
- Coupon one-time and 7-day behavior validated.

## Post-Launch Essentials
- Monitor first 24 hours for errors.
- Keep rollback copy of previous stable build.
- Collect first user feedback and issue list.
