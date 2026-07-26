# GETREADYJOB V1.1 Production Baseline (Design System 1.0)

Status: ACTIVE PRODUCTION FREEZE

## Permanent Protection Rules

- Do not overwrite baseline tag: prod/v1.1-baseline
- Do not delete or modify release branch: release/v1.1-baseline
- Keep permanent OneDrive snapshots for every official release
- Keep at least one Git bundle and one ZIP backup for every release
- Never overwrite previous release snapshots

## Design Freeze Rules (V1.1 Foundation)

Future versions must extend this design, not replace it, unless explicitly approved:

- Homepage structure
- Primary navigation
- Upload workflow
- Card system
- Layout behavior
- Visual identity
- Core user experience

## Release Safety Checklist (Every Official Version)

1. Create release tag
2. Create release branch
3. Generate Git bundle
4. Generate ZIP source backup
5. Save release notes and rollback documentation
6. Save all artifacts to OneDrive release folders
7. Verify clean rebuild and redeploy

## OneDrive Standard Structure

- GETREADYJOB/PRODUCTION/V1.1
- GETREADYJOB/RELEASES
- GETREADYJOB/BACKUPS
- GETREADYJOB/DOCUMENTATION
- GETREADYJOB/RECOVERY

## Recovery Guarantee Goal

V1.1 must be restorable within minutes by checking out release/v1.1-baseline (or tag prod/v1.1-baseline), rebuilding main_v1_1.dart, and redeploying.

## Automation

Use script:

- lib/scripts/freeze_release_v1_1.ps1

Example:

powershell
Set-Location C:\JobReadyIndia\jobready_india\lib
.\scripts\freeze_release_v1_1.ps1
