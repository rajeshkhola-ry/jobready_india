# Security Key Rotation Verification Checklist

Date: 2026-07-27

## 1) Key Rotation Validation
- [ ] Confirm new `BANK_API_KEY` is created in provider dashboard.
- [ ] Confirm new `ADS_API_KEY` is created in provider dashboard.
- [ ] Confirm old Bank API key is revoked/disabled in provider dashboard.
- [ ] Confirm old Ads API key is revoked/disabled in provider dashboard.
- [ ] Confirm backend secret store has only new keys.
- [ ] Confirm no API keys are hardcoded in repository.

## 2) Live Site Exposure Validation
- [ ] Homepage does not show "Bank & Ads API Files" panel.
- [ ] `/downloads/bank_api_packet_v1_1.md` returns 404 or 410.
- [ ] `/downloads/ads_api_packet_v1_1.md` returns 404 or 410.
- [ ] `/downloads/bank_ads_api_packet_v1_1.html` returns 404 or 410.
- [ ] `/downloads/bank_ads_api_packet_v1_1.pdf` returns 404 or 410.

## 3) Monitoring and Alerts
- [ ] Daily task `GetReadyJob API Key Monitor` exists and is enabled.
- [ ] Task runs successfully at least once (last result `0x0`).
- [ ] Access logs include: timestamp, IP, region, endpoint, status.
- [ ] Allowed IP/domain restrictions are configured at provider side.
- [ ] Alert channel is configured (SIEM/email/Slack/PagerDuty).

## 4) Abuse Detection Checks
- [ ] Unknown IP access attempts are flagged.
- [ ] Unexpected region access attempts are flagged.
- [ ] Per-hour traffic spikes above threshold are flagged.
- [ ] Any suspicious event is escalated and investigated same day.

## 5) Optional Hard Block While Propagation Completes
- [ ] If DNS/proxy exists (e.g., Cloudflare), add temporary 410 rule for:
  - `/downloads/bank_api_packet_v1_1.md`
  - `/downloads/ads_api_packet_v1_1.md`
  - `/downloads/bank_ads_api_packet_v1_1.html`
  - `/downloads/bank_ads_api_packet_v1_1.pdf`
- [ ] Remove temporary rule after origin + cache confirms 404 and no stale access.
