# V2 Release Candidate — Known Issues & Limitations

**Release**: V2 RC (2026-07-18)
**Severity Summary**: 1 Critical (Fixed), 0 Open
**Recommended Action**: No blockers remain — clear for production RC

---

## 🔧 Fixed Issues (Checkpoint 16)

### CRITICAL (Fixed in C16)
**PDF Tools Page - Code Corruption** ✅ FIXED
- **Severity**: 🔴 CRITICAL (Build-blocking)
- **Issue**: File contained incorrectly merged code from legacy ConvertToolPage (PDF to Word logic in a navigation hub)
- **Impact**: Build failed with 30+ compilation errors in pdf_tools_page.dart
- **Root Cause**: Legacy code was accidentally left in file during earlier refactoring
- **Fix Applied**: Restored pdf_tools_page.dart to clean V2 navigation-hub-only version (293 lines)
- **Verification**: 0 errors, build now successful
- **Status**: ✅ **RESOLVED** (Commit: TBD)

---

## ⚠️ Known Limitations (Not Bugs - Design Decisions)

### 1. Web Runtime Constraints
**Description**: PDF rendering on web runtime has limitations
**Affected**: Compression Benchmark, PDF Editor (partial OCR support)
**Workaround**: Use desktop/mobile runtime for full PDF feature support
**Severity**: Low (documented in UI)
**Status**: Documented in UI warnings

### 2. File Upload Size Limits
**Description**: Large file uploads (>500MB) may timeout
**Affected**: Merge, Combine operations
**Workaround**: Break large operations into smaller files
**Severity**: Low (edge case)
**Status**: Document in help/FAQ

### 3. OCR Language Support
**Description**: OCR currently optimized for English text
**Affected**: Extract Tool (OCR mode), PDF Editor (OCR mode)
**Workaround**: Manual text entry or English-focused PDFs
**Severity**: Low (multilingual rollout planned post-launch)
**Status**: **DEFERRED FEATURE** (See section below)

---

## 🚫 Known Defects (Acknowledged, Not Critical)

**None currently identified** — All release-blocking defects have been fixed.

---

## 📋 Deferred Features (Post-Launch)

These features are intentionally deferred to post-launch phases:

### Phase 2 (Post-Launch)
1. **Multilingual Support**
   - Currently: English-only UI
   - Planned: Phased rollout (Spanish, French, German, Hindi)
   - Effort: Medium
   - Timeline: Q3/Q4 2026

2. **Advanced OCR Languages**
   - Currently: English optimized
   - Planned: Chinese, Japanese, Arabic, Indic scripts
   - Effort: High
   - Timeline: Q3/Q4 2026

3. **Cloud Storage Integration**
   - Currently: Local storage only
   - Planned: Google Drive, OneDrive, Dropbox integration
   - Effort: High
   - Timeline: Q4 2026

4. **Batch API**
   - Currently: Web UI only
   - Planned: REST API for batch operations
   - Effort: High
   - Timeline: 2027 Q1

5. **Advanced Compression Options**
   - Currently: Standard, High, Maximum quality levels
   - Planned: Custom compression profiles, format-specific optimization
   - Effort: Medium
   - Timeline: Q3 2026

6. **PDF Annotation Tools**
   - Currently: Basic PDF editing
   - Planned: Comments, highlights, stamps, signatures
   - Effort: High
   - Timeline: Q4 2026

### Phase 3 (Extended)
1. Desktop applications (Windows, macOS, Linux)
2. Mobile native apps (iOS, Android)
3. Chrome extension for quick conversions
4. Integration with third-party services
5. Enterprise features (SSO, usage analytics, admin panel)

---

## 🔍 Pre-Launch Testing Recommendations

### Browser Compatibility (Recommended)
- ✅ Chrome/Edge (latest 2 versions)
- ✅ Firefox (latest 2 versions)
- ✅ Safari (latest 2 versions)
- ⚠️ Mobile browsers (supported but may have touch UX refinements needed)

### File Type Testing
- ✅ PDF (all variants)
- ✅ DOCX, XLSX, PPTX
- ✅ JPG, PNG, GIF, BMP
- ✅ TXT, CSV
- ⚠️ Complex embedded PDFs (some edge cases)

### Load Testing Recommendations
- Max file size: Test up to 200MB
- Batch operations: Test with 50+ files
- Concurrent users: Test up to 100 simultaneous users
- Network conditions: Test on 3G/4G/5G

---

## 📊 Issue Resolution Summary

| Category | Count | Status |
|----------|-------|--------|
| Critical Issues | 1 | ✅ Fixed |
| High Priority | 0 | ✅ None |
| Medium Priority | 0 | ✅ None |
| Low Priority | 3 | ⚠️ Known (Not critical) |
| Feature Requests | 12+ | 📋 Deferred |
| **TOTAL BLOCKERS** | **0** | ✅ **CLEAR** |

---

## ✅ Release Readiness

- **Blocker Defects**: 0 remaining ✅
- **Build Status**: Successful ✅
- **Analyzer Status**: 0 new issues ✅
- **Navigation Status**: All routes verified ✅
- **Branding Status**: Complete ✅
- **Documentation Status**: Complete ✅

**Recommendation**: ✅ **CLEAR FOR PRODUCTION RC** — No known blockers remain.
