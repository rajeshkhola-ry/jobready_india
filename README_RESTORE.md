# Stable Version Backup & Disaster Recovery Plan

## Stable Checkpoint
- Tag: v1.0.0-STABLE
- Website: https://getreadyjob.com
- API: https://jobready-india.onrender.com
- Backup archive target: OneDrive/JobReadyIndia_Backups/Project_Stable_Backup_V1.0.zip

## 3-Step Emergency Restore (Target: under 10 minutes)

1. Roll back code to stable tag
- Command:
  - git fetch --all --tags
  - git checkout v1.0.0-STABLE

2. Redeploy frontend and backend
- Push restore branch from stable tag:
  - git checkout -B restore/v1.0.0-stable
  - git push -f origin restore/v1.0.0-stable
- Trigger GitHub Pages workflow (or push stable commit to deployment branch).
- In Render dashboard, trigger Manual Deploy for the backend service from the same commit/tag.

3. Verify health and recovery
- Frontend: open https://getreadyjob.com/build-info.json and confirm stable commit.
- Backend health: open https://jobready-india.onrender.com/healthz and confirm {"ok":true}.
- API info: open https://jobready-india.onrender.com/api/info.
- Run one smoke conversion/compression test and confirm download modal appears.

## Backup Artifacts to Preserve
- Git tag v1.0.0-STABLE
- OneDrive ZIP backup Project_Stable_Backup_V1.0.zip
- Environment manifest .env.backup

## Notes
- Keep all secrets in Render/GitHub secret stores. Do not commit live credentials.
- After emergency restore, freeze new deployments until RCA is completed.
