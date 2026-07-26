# ⚡ Top 10 Quick Launch Checks (10-15 Minutes)

**When to use:** Right after deployment goes live
**Purpose:** Rapid validation of critical functionality
**Duration:** 10-15 minutes
**Pass/Fail:** All must pass before public announcement

---

## ✅ Quick Check #1: Domain & DNS (1 minute)

```bash
# DNS resolves to your server
nslookup getreadyjob.com

# Should show your server IP address
# If not: DNS not propagated yet, wait 5-30 minutes
```

**Status:** ✅ Pass or ❌ Fail

---

## ✅ Quick Check #2: HTTPS & SSL Certificate (2 minutes)

```bash
# HTTPS connection works
curl -I https://getreadyjob.com

# Should return: HTTP/1.1 200 OK
# If redirect: HTTP/1.1 301 (good, means HTTP→HTTPS working)
```

**Browser verification:**
1. Open https://getreadyjob.com
2. Check URL bar for 🔒 green lock icon
3. Click lock → Certificate should show "getreadyjob.com"
4. Certificate expiration should be >90 days away

**Status:** ✅ Pass or ❌ Fail

---

## ✅ Quick Check #3: Frontend Loads & No Errors (2 minutes)

```
1. Open https://getreadyjob.com in browser
2. Press F12 (Developer Tools)
3. Click "Console" tab
4. Check for red errors (warnings/blue logs are okay)
5. Page should load in <2 seconds
```

**Visual checks:**
- [ ] Page fully loaded (not blank)
- [ ] No spinning loader
- [ ] No error messages displayed
- [ ] Console tab clean (no red errors)

**Status:** ✅ Pass or ❌ Fail

---

## ✅ Quick Check #4: Compression Tool UI (2 minutes)

```
On the loaded page, verify you can see:
[ ] 📦 Compression Tool header
[ ] 📤 Upload area with "Drop files here" text
[ ] Quality Slider (labeled 50-90%)
[ ] Format Selector (WebP/JPEG)
[ ] 💡 Compression Tips panel
[ ] Blue gradient design (matches mockups)
```

**Status:** ✅ All visible or ❌ Missing elements

---

## ✅ Quick Check #5: PDF Compression Works (3 minutes)

```
1. Find any PDF file (5-20MB works best)
2. Drag it to the upload area (or click to select)
3. Set Quality slider to 70%
4. Click "Compress"
5. Wait for progress bar to complete (~30 sec max)
6. Check results show:
   - ✓ Compression Complete
   - Original size: X MB
   - Compressed size: Y MB
   - Reduction percentage (should be 10-40% for PDF)
7. Click "Download"
8. File should download to your default folder
```

**Status:** ✅ Complete compression & download or ❌ Failed

---

## ✅ Quick Check #6: Image Compression Works (2 minutes)

```
1. Find any JPEG or PNG image (2-5MB)
2. Drag to upload area
3. Quality: 75%
4. Click "Compress"
5. Should complete in <30 seconds
6. Results show file size reduction
7. Click "Download"
```

**Status:** ✅ Works or ❌ Failed

---

## ✅ Quick Check #7: Error Handling Works (2 minutes)

```
1. Try uploading a .txt file (not supported)
   → Should show error: "Invalid file type" or similar
   → Should NOT crash the page

2. After error, try a valid PDF again
   → Should work normally (error recovery verified)
```

**Status:** ✅ Error handled gracefully or ❌ Crashed/no error message

---

## ✅ Quick Check #8: Mobile Responsive (2 minutes)

```
Option A - Browser DevTools:
1. Press F12 (Developer Tools)
2. Click device icon (toggle device toolbar)
3. Select iPhone SE (375px width)
4. Reload page
5. Verify:
   [ ] Layout adapts (no horizontal scroll)
   [ ] Upload area still visible
   [ ] Quality slider works
   [ ] Can still upload & compress

Option B - Physical Phone (if available):
1. Get server's local IP: ipconfig (look for IPv4: 192.168.x.x)
2. On phone: Open https://getreadyjob.com or http://192.168.x.x:3000
3. Test upload & compression
```

**Status:** ✅ Mobile layout works or ❌ Issues found

---

## ✅ Quick Check #9: Server Logs Clean (2 minutes)

**SSH into your server:**

```bash
# Check Nginx error log
sudo tail -20 /var/log/nginx/getreadyjob_error.log
# Should be mostly empty (no recent errors)

# Check Node.js is running
ps aux | grep compression_server.js
# Should show the process running

# Check if using Docker:
sudo docker-compose logs --tail=20 jobready-compression
# Should show normal operation messages
```

**Status:** ✅ Logs clean or ❌ Errors found

---

## ✅ Quick Check #10: API Responding (1 minute)

```bash
# Test API health check
curl https://getreadyjob.com/api/info

# Should return JSON response with:
# {
#   "status": "running",
#   "version": "...",
#   "maxFileSize": "...",
#   ...
# }
```

**Status:** ✅ Returns JSON or ❌ Error/timeout

---

## 📊 Quick Results Matrix

| Check | Test | Result | Notes |
|-------|------|--------|-------|
| 1 | DNS resolves | ✅ or ❌ | Should show your server IP |
| 2 | HTTPS/SSL works | ✅ or ❌ | Green 🔒 lock icon present |
| 3 | Frontend loads | ✅ or ❌ | No red console errors |
| 4 | UI fully visible | ✅ or ❌ | All components present |
| 5 | PDF compression | ✅ or ❌ | File size reduced, download works |
| 6 | Image compression | ✅ or ❌ | Completes successfully |
| 7 | Error handling | ✅ or ❌ | Invalid file rejected gracefully |
| 8 | Mobile responsive | ✅ or ❌ | Works on 375px viewport |
| 9 | Server logs | ✅ or ❌ | No recent errors |
| 10 | API responds | ✅ or ❌ | Returns JSON with status:running |

---

## ✨ Decision Matrix

### All 10 checks pass ✅
**→ Ready to announce to users!**
- Update IMPLEMENTATION_SUMMARY.md status to 🟢 LIVE
- Send announcement email
- Post on social media
- Monitor logs for first 24 hours

### Any check fails ❌
**→ Do NOT announce yet. Troubleshoot:**

| Failed Check | Likely Issue | Action |
|--------------|--------------|--------|
| 1 (DNS) | DNS not propagated | Wait 5-30 min, retry |
| 2 (HTTPS) | SSL cert not installed | Check Let's Encrypt setup |
| 3 (Frontend) | Code error | Check console errors, review logs |
| 4 (UI) | CSS not loading | Verify nginx serving static files |
| 5 (PDF) | compression_server.js crashed | Check Docker/process running |
| 6 (Image) | Sharp not installed | Optional - PDF still works without it |
| 7 (Errors) | No error handling | Code issue - check server logs |
| 8 (Mobile) | CSS breakpoints broken | CSS loading issue |
| 9 (Logs) | Errors in logs | Review error message, fix issue |
| 10 (API) | API not responding | Check Node.js process, port 3000 |

---

## 🎯 Quick Troubleshooting

**If DNS check fails:**
```bash
# Wait for propagation (5-30 min)
# Then retry:
nslookup getreadyjob.com
```

**If HTTPS fails:**
```bash
# Check certificate exists:
sudo ls -la /etc/letsencrypt/live/getreadyjob.com/

# Renew certificate if needed:
sudo certbot renew --force-renewal
```

**If frontend loads but UI broken:**
```bash
# Check static files served:
curl https://getreadyjob.com/design-system.css | head -5
# Should show CSS, not HTML error page
```

**If compression fails:**
```bash
# Check Node.js running:
sudo docker-compose ps
# Should show jobready-compression running

# Check logs:
sudo docker-compose logs jobready-compression | tail -30
```

**If server logs show errors:**
```bash
# Check specific error:
sudo tail -50 /var/log/nginx/getreadyjob_error.log

# Common fixes:
# - Permission denied → check file ownership
# - Address already in use → change port or kill process
# - Connection refused → check upstream server running
```

---

## 🚀 Pass All = Go Live!

Once all 10 quick checks pass:

```
1. [ ] Update IMPLEMENTATION_SUMMARY.md
       Status: 🟢 LIVE
       URL: https://getreadyjob.com

2. [ ] Send announcement:
       Subject: GetReadyJob is Now Live! 🚀
       Body: Visit https://getreadyjob.com to compress PDF/images

3. [ ] Monitor logs for 24 hours
       sudo docker-compose logs -f

4. [ ] Track early user feedback
```

---

## ⏱️ Time Allocation

```
Check 1 (DNS):           1 min
Check 2 (HTTPS/SSL):     2 min
Check 3 (Frontend):      2 min
Check 4 (UI):            2 min
Check 5 (PDF):           3 min
Check 6 (Image):         2 min
Check 7 (Error):         2 min
Check 8 (Mobile):        2 min
Check 9 (Logs):          2 min
Check 10 (API):          1 min
─────────────────────────────
TOTAL:                 19 minutes
```

---

**Quick Checklist Version:** v1.0
**Created:** 2026-07-26
**Use After:** PRODUCTION_DEPLOYMENT_GUIDE.md (when site goes live)
**Refer to:** POST_LAUNCH_TEST_CHECKLIST.md (for detailed testing)

🚀 **Run through these 10 checks, pass all = ready to announce!**
