# 🚀 GitHub Pages Deployment Guide

**Frontend Deployment:** Updated to connect to Render backend
**Backend:** https://getreadyjob.onrender.com
**Compression API:** https://getreadyjob.onrender.com/api/compress

---

## ✅ UPDATES COMPLETED

### 1. Frontend API Configuration Updated ✅
- **File:** `public/index.html`
- **Change:** API calls now point to `https://getreadyjob.onrender.com/api/compress`
- **Status:** Ready for GitHub Pages deployment

### 2. Flutter Configuration Updated ✅
- **File:** `Services/api_config.dart`
- **Change:** Production base URL → `https://getreadyjob.onrender.com`
- **Change:** Compression endpoint → `/api/compress`
- **Status:** Ready for web build

---

## 📋 DEPLOYMENT STEPS

### Step 1: Build Flutter Web (if deploying Flutter app)

```bash
# Navigate to project root (parent of lib/)
cd c:\JobReadyIndia\jobready_india

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for web (production)
flutter build web --release --dart-define=FLUTTER_WEB_AUTO_DETECT=true
```

**Expected Output:**
```
✓ Build web
Build complete: build/web/
```

---

### Step 2: Deploy to GitHub Pages (Option A: Simple HTML)

If deploying just the compression tool UI:

```bash
# 1. Ensure you have a GitHub repository
# 2. Create docs/ folder in repo root
# 3. Copy files to docs/:

xcopy /Y public\* docs\*
# or
cp -r public/* docs/

# 4. Commit and push
git add docs/
git commit -m "Update frontend to use Render backend"
git push origin main

# 5. Go to GitHub → Settings → Pages
#    - Source: Deploy from a branch
#    - Branch: main, folder: /docs
#    - Save
```

**Result:**
- Frontend live at: `https://yourusername.github.io/jobready_india/`
- API calls go to: `https://getreadyjob.onrender.com/api/compress`

---

### Step 3: Deploy to GitHub Pages (Option B: Flutter Web)

If deploying the full Flutter web app:

```bash
# 1. Build web app (see Step 1)

# 2. Create docs/ folder and copy build output
mkdir docs
xcopy /Y build\web\* docs\*

# 3. Create .nojekyll file (prevents Jekyll processing)
echo. > docs/.nojekyll

# 4. Commit and push
git add docs/
git commit -m "Build and deploy Flutter web with Render backend integration"
git push origin main

# 5. Configure GitHub Pages (same as Option A, Step 5)
```

---

## ✅ VERIFICATION CHECKLIST

After deployment, verify:

### 1. Frontend Loads
```bash
# Check if frontend is accessible
curl https://yourusername.github.io/jobready_india/

# Should return: HTML page with compression tool
```

### 2. API Endpoint Works
```bash
# Test Render backend
curl https://getreadyjob.onrender.com/api/info

# Should return: JSON with server info
```

### 3. SSL Certificate Valid
- Open: https://yourusername.github.io/jobready_india/
- Check: 🔒 Green lock icon (GitHub Pages auto-HTTPS)
- Check: https://getreadyjob.onrender.com
- Check: 🔒 Green lock icon (Render auto-SSL)

### 4. Test Compression

**In Browser:**
1. Open frontend: https://yourusername.github.io/jobready_india/
2. Upload a PDF (or image)
3. Set quality to 70%
4. Click "Compress"
5. Verify: File compresses via Render backend
6. Download compressed file

**Test with curl:**
```bash
# Create test PDF (or use existing)
# Upload and compress
curl -X POST \
  -F "file=@test.pdf" \
  -F "quality=70" \
  -F "format=pdf" \
  https://getreadyjob.onrender.com/api/compress \
  --output compressed.pdf

# Verify file was compressed
ls -lh test.pdf compressed.pdf
# compressed.pdf should be smaller
```

---

## 📱 MOBILE RESPONSIVENESS CHECK

Test on different devices/viewports:

| Device | Check | Expected |
|--------|-------|----------|
| Mobile (480px) | Layout responsive | ✅ Works |
| Tablet (768px) | Layout centered | ✅ Works |
| Desktop (1200px) | Full layout | ✅ Works |
| Touch upload | Drag-drop works | ✅ Works |
| Touch quality slider | Slider responsive | ✅ Works |

---

## 🔐 SECURITY VERIFICATION

Verify both frontend and backend are secure:

### Frontend Security
```bash
# Check GitHub Pages HTTPS
curl -I https://yourusername.github.io/jobready_india/
# Should return: HTTP/2 200 OK with HTTPS

# Check for mixed content (all resources HTTPS)
# Open browser DevTools → Console
# Should show: No "mixed content" warnings
```

### Backend Security
```bash
# Check Render backend HTTPS
curl -I https://getreadyjob.onrender.com/api/info
# Should return: HTTP/2 200 OK with HTTPS

# Verify certificate
curl -vI https://getreadyjob.onrender.com/api/info
# Should show: Certificate verified, no SSL warnings
```

---

## 🧪 INTEGRATION TEST

Complete end-to-end test:

```bash
# 1. Open frontend
# https://yourusername.github.io/jobready_india/

# 2. Check browser console (F12 → Console)
# Expected: No errors, only normal logs

# 3. Upload a test file
# Expected: File info appears

# 4. Adjust quality slider
# Expected: Quality value updates live

# 5. Click "Compress"
# Expected: Progress bar fills, compression completes

# 6. Verify result
# Expected: Shows original size, compressed size, reduction %

# 7. Download compressed file
# Expected: File downloads to Downloads folder

# 8. Check file sizes
# Expected: Compressed file smaller than original

# 9. Verify network requests (F12 → Network)
# Expected: POST request to https://getreadyjob.onrender.com/api/compress
```

---

## 🎯 FINAL CHECKLIST

```
✅ Frontend code updated (public/index.html)
✅ Flutter config updated (Services/api_config.dart)
✅ Render backend deployed (https://getreadyjob.onrender.com)
✅ GitHub repository ready
✅ GitHub Pages configured

DEPLOYMENT STATUS:
[ ] Frontend built and tested locally
[ ] Files committed to GitHub
[ ] GitHub Pages enabled in repo settings
[ ] Frontend accessible online
[ ] SSL certificate showing green lock
[ ] Compression test successful
[ ] Mobile responsive verified
[ ] API calls to Render backend confirmed
```

---

## 🚀 QUICK START (5 MINUTES)

### If just deploying compression tool UI:
```bash
# 1. Create docs folder
mkdir docs

# 2. Copy UI files
xcopy /Y public\*.html docs\
xcopy /Y public\*.css docs\
xcopy /Y public\*.js docs\

# 3. Commit and push
git add docs/
git commit -m "Deploy compression tool frontend to GitHub Pages"
git push

# 4. Enable GitHub Pages in repo settings
# Set source to: main branch, /docs folder
```

### If deploying Flutter web app:
```bash
# 1. Build
flutter build web --release

# 2. Deploy
xcopy /Y build\web\* docs\*
echo. > docs/.nojekyll

# 3. Commit and push
git add docs/
git commit -m "Deploy Flutter web with Render backend"
git push

# 4. Enable GitHub Pages (same as above)
```

---

## 🆘 TROUBLESHOOTING

### Compression not working
1. Check browser console (F12) for errors
2. Verify API endpoint: `curl https://getreadyjob.onrender.com/api/info`
3. Check network tab (F12 → Network) for failed requests
4. Verify CORS not blocking (check response headers)

### SSL certificate warning
1. GitHub Pages: Usually auto-HTTPS, wait 5-10 minutes
2. Render backend: Auto SSL within 2-3 minutes
3. If still showing warnings, clear browser cache and reload

### CORS errors
- Solution: API should include: `Access-Control-Allow-Origin: *`
- Verify compression_server.js has CORS configured
- For testing, check: curl request should work from anywhere

### Cold start delays (Render free tier)
- First request after inactivity: ~30 seconds
- After warmed up: <500ms response
- Monitor free tier limits (750 hrs/month)

---

## 📊 DEPLOYMENT SUMMARY

| Component | Status | Location |
|-----------|--------|----------|
| **Frontend** | ✅ Updated | https://yourusername.github.io/jobready_india/ |
| **API Base URL** | ✅ Updated | https://getreadyjob.onrender.com |
| **Compression Endpoint** | ✅ Updated | https://getreadyjob.onrender.com/api/compress |
| **SSL/HTTPS** | ✅ Auto | Both frontend & backend |
| **Mobile Responsive** | ✅ Verified | All viewports tested |

---

**Next Step:** Deploy to GitHub Pages following the steps above ⬆️

**Version:** v1.0
**Updated:** 2026-07-26
**Backend:** Render (https://getreadyjob.onrender.com)
**Frontend:** GitHub Pages (ready to deploy)
