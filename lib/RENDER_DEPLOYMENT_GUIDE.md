# 🚀 Deploy to Render.com - Complete Guide

**Platform:** Render.com
**Service Type:** Web Service (Node.js)
**Time to Deploy:** 10-15 minutes
**Cost:** Free tier available

---

## 🎯 QUICK DEPLOYMENT STEPS

### Step 1: Create Render Account (5 minutes)
1. Go to https://render.com
2. Click "Sign Up" (top right)
3. Choose: "Sign up with GitHub" (easiest)
4. Authorize Render to access your GitHub
5. Confirm email if needed

---

### Step 2: Create New Web Service (2 minutes)
1. In Render dashboard, click "New +"
2. Select "Web Service"
3. Click "Connect a repository"

---

### Step 3: Connect GitHub Repository (3 minutes)
1. Find your repository in the list
   - Search for: `jobready_india` or your repo name
2. Click "Connect" next to your repo
3. If you don't see it:
   - Click "Configure account"
   - Grant Render access to your GitHub repos
   - Then select your repo

---

### Step 4: Configure Deployment Settings (5 minutes)

**Fill in these fields:**

| Field | Value |
|-------|-------|
| **Name** | `getreadyjob` (no spaces) |
| **Root Directory** | `lib` (where package.json is) |
| **Environment** | `Node` (auto-detected) |
| **Build Command** | `npm install` |
| **Start Command** | `npm start` |
| **Plan** | `Free` |

---

### Step 5: Set Environment Variables (2 minutes)

Click "Add Environment Variable" and add:

| Key | Value |
|-----|-------|
| `NODE_ENV` | `production` |
| `PORT` | `10000` |

**Note:** Render assigns port dynamically, but set PORT to 10000

---

### Step 6: Deploy! (Click "Create Web Service")
- Render builds your app (~2-3 minutes)
- You'll see: "Deploying..."
- Then: "Live" (with green checkmark)
- Your URL will be displayed (e.g., `https://getreadyjob.onrender.com`)

---

## ✅ AFTER DEPLOYMENT

### Get Your Public URL
Once deployment completes:
```
Your app is live at:
https://getreadyjob.onrender.com
```

### Test the API Endpoint
```bash
# Test API health
curl https://getreadyjob.onrender.com/api/info

# Expected response:
{
  "status": "running",
  "version": "1.0.0",
  "maxFileSize": "100MB",
  ...
}
```

### Test Compression Endpoint
```bash
# Test compression API
curl -X POST https://getreadyjob.onrender.com/api/compress \
  -F "file=@your-file.pdf" \
  -F "quality=70"
```

---

## 📋 DETAILED STEP-BY-STEP WITH SCREENSHOTS GUIDE

### 1️⃣ Sign Up to Render.com

**Step A: Visit Render**
- Open: https://render.com
- Click: "Sign Up" (top right)

**Step B: Choose Login Method**
- Recommended: "Sign up with GitHub" (fastest)
- Alternative: Email signup

**Step C: Authorize GitHub (if using GitHub signup)**
- Click "Authorize render-oss"
- Your GitHub account grants Render permission to access repos

**Step D: Confirm Email**
- Check your email
- Click confirmation link
- Account ready! ✅

---

### 2️⃣ Create New Web Service

**On Render Dashboard:**
1. Look for button: "New +" (top right)
2. Hover over it → Select "Web Service"
3. Next screen: "Connect a repository"

---

### 3️⃣ Connect Your GitHub Repository

**Finding Your Repository:**
1. You'll see a list of your GitHub repos
2. Find: `jobready_india` (or whatever your repo is called)
3. Click: "Connect" button next to it

**If Repo Not Showing:**
1. Click: "Configure account" (link at bottom)
2. Select: "Install at My Repositories"
3. Grant permissions to Render
4. Go back and select your repo

**After Connecting:**
- Render shows: "Repository connected ✅"
- Ready for next step

---

### 4️⃣ Configure Service Settings

**Fill In These Settings:**

**Service Name:**
- Input: `getreadyjob` (lowercase, no spaces)
- This becomes part of your URL

**Branch:**
- Select: `main` (or your default branch)

**Root Directory:**
- Input: `lib` (this is where your package.json is)
- Important! Don't leave blank

**Environment:**
- Select: `Node` (should auto-detect)

**Build Command:**
- Input: `npm install`
- Render runs this when building

**Start Command:**
- Input: `npm start`
- This starts your server

---

### 5️⃣ Add Environment Variables

**Step 1: Find "Environment" Section**
- Scroll down on the settings page
- Look for: "Environment Variables"

**Step 2: Add Variables**
Click "Add Environment Variable" for each:

**Variable 1: NODE_ENV**
```
Key:   NODE_ENV
Value: production
```

**Variable 2: PORT**
```
Key:   PORT
Value: 10000
```

**Variable 3 (Optional): LOG_LEVEL**
```
Key:   LOG_LEVEL
Value: info
```

---

### 6️⃣ Select Plan & Deploy

**Choose Plan:**
- Click: "Free" plan (bottom option)
- Shows: $0/month

**Final Check:**
- Review all settings
- Confirm root directory is `lib`
- Confirm start command is `npm start`

**Deploy:**
- Click: "Create Web Service" (blue button)
- Render starts building! 🚀

---

## 🔄 DEPLOYMENT PROGRESS

### What You'll See:

```
Step 1: Building...
├─ Cloning repository
├─ Installing dependencies (npm install)
└─ Duration: ~1-2 minutes

Step 2: Starting Service
├─ Running: npm start
├─ Checking health
└─ Duration: ~30 seconds

Step 3: Live!
├─ Status: ✅ Live (green)
├─ URL: https://getreadyjob.onrender.com
└─ Ready for use!
```

### Monitor Progress:
1. Go to your service dashboard
2. Click "Logs" to see real-time output
3. Wait for "Server listening on port 10000"

---

## ✅ VERIFY DEPLOYMENT

### Check #1: Service Status
- Dashboard shows: "Live" (green checkmark)
- URL is accessible

### Check #2: Test HTTPS
```bash
curl -I https://getreadyjob.onrender.com

# Should return:
# HTTP/1.1 200 OK
```

### Check #3: Test API Endpoint
```bash
curl https://getreadyjob.onrender.com/api/info

# Should return JSON:
# {"status":"running","version":"1.0.0",...}
```

### Check #4: SSL Certificate
- Open: https://getreadyjob.onrender.com
- Look for: 🔒 green lock icon
- Click lock → Certificate should show Render domain
- Render provides free SSL automatically ✅

---

## 📊 AFTER DEPLOYMENT

### Your Public Backend URL:
```
https://getreadyjob.onrender.com
```

### API Endpoints Available:
```
GET  https://getreadyjob.onrender.com/api/info
POST https://getreadyjob.onrender.com/api/compress
```

### Update Your Frontend:
If frontend needs to know backend URL:
```javascript
const API_URL = 'https://getreadyjob.onrender.com';

// API calls now use:
fetch(`${API_URL}/api/compress`, { ... })
```

---

## 🆘 TROUBLESHOOTING

### Issue: "Build Failed"
```
❌ Error during npm install
```
**Solution:**
1. Check package.json syntax (must be valid JSON)
2. Check Node version compatibility
3. Look at "Logs" tab for specific error
4. Fix issue locally, push to GitHub
5. Render auto-redeploys

---

### Issue: "Service Won't Start"
```
❌ Status shows "Crashed"
```
**Solution:**
1. Click "Logs" tab
2. Look for error message
3. Common causes:
   - Port not set correctly
   - Environment variables missing
   - Code syntax error
4. Fix locally, push, Render redeploys

---

### Issue: "503 Service Unavailable"
```
❌ API returns error
```
**Likely Causes:**
- Service crashed (check Logs)
- Still deploying (wait 2-3 minutes)
- Root directory wrong (should be `lib`)

**Fix:**
1. Check logs for errors
2. Wait for deployment to complete
3. Redeploy: Settings → "Restart Service"

---

### Issue: API Timeout
```
❌ Request takes too long
```
**Solutions:**
- Free tier has limited resources
- Compression operations might timeout
- Consider upgrading to paid tier
- Or optimize compression logic

---

## 📱 TEST COMPRESSION API

### Using cURL (Command Line)

**Test 1: Get API Info**
```bash
curl https://getreadyjob.onrender.com/api/info
```

**Test 2: Upload & Compress PDF**
```bash
# Requires a PDF file
curl -X POST \
  -F "file=@/path/to/file.pdf" \
  -F "quality=70" \
  https://getreadyjob.onrender.com/api/compress
```

**Test 3: Compress Image**
```bash
curl -X POST \
  -F "file=@/path/to/image.jpg" \
  -F "quality=75" \
  -F "format=webp" \
  https://getreadyjob.onrender.com/api/compress
```

---

### Using Browser (Simple Test)

1. Open: https://getreadyjob.onrender.com
2. If you have frontend UI:
   - Upload a PDF
   - Set quality: 70%
   - Click "Compress"
   - Should work! ✅

---

## 🎯 NEXT STEPS

### After Successful Deployment:

1. **Note Your Backend URL:**
   ```
   https://getreadyjob.onrender.com
   ```

2. **Update Your Frontend** (if needed):
   - Point API calls to this URL
   - Update `compression_server.js` if necessary

3. **Run Post-Deployment Tests:**
   ```bash
   # Test API endpoint
   curl https://getreadyjob.onrender.com/api/info

   # Test compression
   curl -X POST \
     -F "file=@test.pdf" \
     https://getreadyjob.onrender.com/api/compress
   ```

4. **Monitor Performance:**
   - Render dashboard shows usage
   - Free tier has usage limits
   - Upgrade if needed

5. **Setup Auto-Redeploy** (Optional):
   - Render auto-redeploys when you push to GitHub
   - Enable/disable in: Settings → "Auto Deploy"

---

## ⚙️ OPTIONAL: CONFIGURE AUTO-DEPLOY

**To Auto-Deploy on GitHub Push:**

1. Go to your Render service
2. Click: "Settings" (top)
3. Find: "Auto Deploy"
4. Enable: "Yes"
5. Now every GitHub push auto-deploys! ✅

---

## 💰 RENDER FREE TIER LIMITS

**What's Included:**
- ✅ Free SSL/HTTPS
- ✅ 750 free compute hours/month
- ✅ 0.5 GB RAM
- ✅ Shared vCPU
- ✅ 100 GB bandwidth/month

**Limitations:**
- Services spin down after 15 min inactivity
- Cold start: ~30 seconds first request
- Limited CPU during peak
- No custom domain on free tier

**When to Upgrade:**
- Running 24/7 (production)
- High compression volume
- Need consistent performance
- Custom domain

---

## 📊 DEPLOYMENT SUMMARY

| Component | Status | URL |
|-----------|--------|-----|
| Backend API | 🟢 Live | https://getreadyjob.onrender.com |
| SSL/TLS | 🟢 Auto | Free (included) |
| Auto Deploy | 🟢 Optional | From GitHub push |
| Monitoring | 🟢 Built-in | Render dashboard |
| Scaling | 🟡 Limited | Free tier has limits |

---

## 🎉 YOU'RE DONE!

**Your Node.js backend is now live on Render! 🚀**

### Quick Reference:
- **Backend URL:** https://getreadyjob.onrender.com
- **API Endpoint:** https://getreadyjob.onrender.com/api/compress
- **Dashboard:** https://dashboard.render.com
- **Logs:** Your service → "Logs" tab

### Next: Test & Monitor
1. Run API tests
2. Monitor performance in Render dashboard
3. Check logs for any errors
4. Upgrade plan if needed

---

**Render Deployment Guide - v1.0**
**Created:** 2026-07-26
**Status:** Ready to Deploy ✅

🚀 **Go to https://render.com and follow the steps above to deploy!**
