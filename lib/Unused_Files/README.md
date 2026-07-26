# Unused Files Archive

**Date:** 2026-07-26
**Status:** ✅ All archived files safe — No links broken

---

## 📋 What's In This Folder

This folder contains files that are **NOT actively used** by the GetReadyJob site. They are organized by type and safely archived here.

### 🔴 **IMPORTANT: Site Will Continue to Work Perfectly**

✅ **No code imports these files**
✅ **No navigation links point to these files**
✅ **No build process references these files**
✅ **The site runs exactly the same**

---

## 📁 Organization

### 1. **Old_Main_Versions/** (4 files)
Old versions of the main entry point file — not used:
- `main_v1.dart`
- `main_v1_publish_locked.dart`
- `main_v1_publish_repair.dart`
- `main_v1_yesterday.dart`

**Site uses:** `main.dart` (delegates to `main_v1_1.dart`) and `main_v3.dart`

---

### 2. **Unused_Pages/** (9 files)
Page files that exist but are NOT imported by any active main file:
- `benchmark_history_page.dart`
- `compression_benchmark_page.dart`
- `coming_soon_page_backup.dart`
- `home_page.dart` (old version; site uses `home_page_v2.dart` and `home_page_v3.dart`)
- `launch_readiness_page.dart`
- `launch_runbook_page.dart`
- `plan_features_page.dart`
- `post_launch_control_page.dart`
- `site_content_page.dart`

**Site uses:** 25+ active page files in Pages/ folder (all others are used)

---

### 3. **Live_Comparison_Files/** (5 files)
Downloaded files from production — used for comparison only, never for serving:
- `live_build_info.json`
- `live_flutter_bootstrap.js`
- `live_flutter_service_worker.js`
- `live_index.html`
- `live_main.dart.js`

**Site uses:** Built files only (not downloaded files)

---

### 4. **Backup_Folders/** (3 folders)
Backup and working copy directories from previous development phases:
- `backups/` — Historical backups
- `V2_BACKUP/` — V2 working backup
- `V2_WORKING/` — V2 working copy

**Site uses:** Only current active code in root lib/ folder

---

### 5. **Logs_And_Cache/** (12 files)
Build logs, npm cache, git tracking files, and temporary test files:
- Build logs: `build_v1_1.log`, `npm-debug.log`
- Git/commit tracking: `c6_*.txt`, `precommit_*.txt`, `ci_*.txt`, `phase1_*.txt`
- Test files: `test-compression.ps1`

**Site uses:** Runtime only (not logs or cache)

---

### 6. **Documentation_Archive/** (16 files)
Reference documents, guides, and reports from previous phases:
- Planning docs: `ROADMAP_*.md`, `GETREADYJOB_V2_MASTER_IMPLEMENTATION_PLAN.md`
- Phase docs: `V2_2_1_TO_2_15_CHECKLIST.md`, `PRODUCTION_BASELINE_V1_1.md`
- Guides: `COMPRESSION_*.md`, `RECOVERY_RUNBOOK_V1_1.md`
- Reports: `V1_V2_V3_Audit_Report_*.html/.pdf`, `VERIFICATION_REPORT.md`

**Site uses:** Only active deployment guides in root lib/ folder

---

## ✅ Files KEPT In Root (Active)

**Entry Points:**
- ✅ `main.dart` — Primary entry point
- ✅ `main_v3.dart` — V3 entry point
- ✅ `main_v1_1.dart` — Production build (used by main.dart)

**Active Code:**
- ✅ `Pages/` — 25+ active page files
- ✅ `Services/` — All service files
- ✅ `Widgets/` — All widget components
- ✅ `Models/` — All data models
- ✅ `Utils/` — All utility functions
- ✅ `image/` — Image services
- ✅ `tool/` — Tool directory
- ✅ `test/` — Test directory
- ✅ `test_assets/` — Test assets

**Build & Deployment:**
- ✅ `package.json` — npm dependencies
- ✅ `compression_server.js` — Compression API server
- ✅ `public/` — Compression tool frontend
- ✅ `Dockerfile` — Docker image
- ✅ `docker-compose.yml` — Docker orchestration

**Active Documentation:**
- ✅ `FINAL_LAUNCH_CHECKLIST.md` — Current deployment guide
- ✅ `IMPLEMENTATION_SUMMARY.md` — Current status
- ✅ `YOUR_LAUNCH_CHECKLIST.md` — Quick reference
- ✅ `LAUNCH_GUIDE.md` — Launch instructions
- ✅ `DEPLOYMENT_ACTION_PLAN.md` — Deployment steps
- ✅ `README_DEPLOYMENT.md` — Quick overview
- ✅ `START_HERE_DEPLOYMENT.md` — Start guide
- ✅ `DAILY_STATUS_LOG_V1.md` — Status tracking
- ✅ `DEPLOY_NOW.ps1` — Deployment script
- ✅ `VERIFY_DEPLOYMENT.ps1` — Verification script
- ✅ `BACKUP_STATUS.md` — Backup tracking
- ✅ `DESIGN_SYSTEM_GUIDE.md` — Design system docs

---

## 🔄 If You Need a File Later

**All files are safely archived here:**
1. Go to the folder category where it's stored
2. Retrieve the file
3. Place it back in the root `lib/` or `Pages/` directory
4. Continue using

**Example:**
```
If you need home_page.dart:
→ Open Unused_Files/Unused_Pages/
→ Copy home_page.dart
→ Paste into lib/Pages/
→ Ready to use
```

---

## 📊 Summary

| Category | Count | Status |
|----------|-------|--------|
| **Old Main Versions** | 4 files | ✅ Archived |
| **Unused Pages** | 9 files | ✅ Archived |
| **Live Comparison Files** | 5 files | ✅ Archived |
| **Backup Folders** | 3 folders | ✅ Archived |
| **Logs & Cache** | 12 files | ✅ Archived |
| **Documentation Archive** | 16 files | ✅ Archived |
| **TOTAL** | **49 items** | ✅ **All safe** |

---

## ✨ Site Status After Archiving

```
🟢 SITE CONTINUES TO WORK PERFECTLY
   ✅ All imports still resolve
   ✅ All page routes still work
   ✅ No navigation broken
   ✅ Builds normally
   ✅ Zero code changes needed
```

---

## 🚀 Next Steps

The GetReadyJob site is now **clean and organized** with:
- ✅ Only active code in lib/
- ✅ Unused files safely archived
- ✅ Zero broken links or imports
- ✅ Ready for production launch

**Ready to deploy!**

---

**Created:** 2026-07-26
**Archive Status:** ✅ Complete & Verified
