# 🚀 QUICK START: DEPLOY GETREADYJOB V2.0 TO PRODUCTION NOW

**Goal**: Get https://www.getreadyjob.com live
**Duration**: 30-60 minutes
**Difficulty**: Medium

---

## ⚡ WHAT YOUR INFRASTRUCTURE TEAM NEEDS TO DO

### Step 1: Get the Build Files (2 min)

Location: `C:\JobReadyIndia\jobready_india\build\web\`

These files need to go to your web server:
```
build/web/
├── index.html
├── main.dart.js (4.57 MB - main bundle)
├── assets/
├── canvaskit/
├── service-worker.js
└── manifest.json
```

**Total size**: ~6 MB

---

### Step 2: Prepare Your Server (5 min)

**Before uploading files:**

1. **Backup existing website** (if any)
   ```bash
   cp -r /var/www/html /var/www/html.backup.$(date +%Y%m%d_%H%M%S)
   ```

2. **Check SSL certificate**
   - Must be valid for: `getreadyjob.com` and `www.getreadyjob.com`
   - Get free certificate from LetsEncrypt if needed

3. **Enable GZIP compression**

   **Apache** (`/etc/apache2/mods-enabled/deflate.conf`):
   ```apache
   <IfModule mod_deflate.c>
     AddOutputFilterByType DEFLATE text/html text/plain text/javascript text/css
     AddOutputFilterByType DEFLATE application/javascript application/json
   </IfModule>
   ```

   **Nginx** (`/etc/nginx/nginx.conf`):
   ```nginx
   gzip on;
   gzip_types text/html text/plain text/javascript text/css application/javascript;
   gzip_min_length 1000;
   ```

4. **Restart web server**
   ```bash
   # Apache
   sudo systemctl restart apache2

   # Nginx
   sudo systemctl restart nginx
   ```

---

### Step 3: Upload Build Files (10 min)

**Option A: SSH/SFTP (Recommended)**

```bash
# On your local machine:
scp -r build/web/* user@your-server.com:/var/www/html/

# Verify upload:
ssh user@your-server.com
ls -la /var/www/html/
# Should show: index.html, main.dart.js, assets/, canvaskit/, etc.
```

**Option B: Hosting Control Panel**

1. Login to hosting dashboard
2. File Manager
3. Navigate to web root (usually `public_html/` or `html/`)
4. Upload folder contents from `build/web/`
5. Overwrite existing files

**Option C: Git/CI-CD**

```bash
# If using automated deployment:
git push production work/today-updates-2026-07-17
# CI/CD automatically deploys build/web/ contents
```

---

### Step 4: Verify Files Uploaded (5 min)

```bash
# Connect to server
ssh user@your-server.com

# Verify key files exist
ls -lh /var/www/html/index.html
ls -lh /var/www/html/main.dart.js
ls -lh /var/www/html/service-worker.js

# Should see:
# -rw-r--r-- 1 www-data www-data 1.8K Jul 18 10:00 index.html
# -rw-r--r-- 1 www-data www-data 4.5M Jul 18 10:00 main.dart.js
# -rw-r--r-- 1 www-data www-data  10K Jul 18 10:00 service-worker.js
```

---

### Step 5: Configure Web Server (5 min)

**Set Cache Headers for Performance**

**Apache** (add to `.htaccess` in web root):
```apache
# Cache static assets for 1 year
<FilesMatch "\.(js|css|png|jpg|gif|ico|woff|woff2|ttf)$">
    Header set Cache-Control "max-age=31536000, public"
</FilesMatch>

# Cache HTML for 1 hour
<FilesMatch "\.html$">
    Header set Cache-Control "max-age=3600, public"
</FilesMatch>

# Don't cache service worker
<FilesMatch "service-worker\.js$">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
</FilesMatch>

# Enable GZIP
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/javascript text/css
    AddOutputFilterByType DEFLATE application/javascript application/json
</IfModule>

# Redirect HTTP to HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

**Nginx** (add to server block in `/etc/nginx/sites-available/getreadyjob.com`):
```nginx
server {
    listen 443 ssl http2;
    server_name getreadyjob.com www.getreadyjob.com;
    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/getreadyjob.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/getreadyjob.com/privkey.pem;

    # GZIP compression
    gzip on;
    gzip_types text/html text/plain text/javascript text/css application/javascript application/json;
    gzip_min_length 1000;

    # Cache headers
    location ~* \.(js|css|png|jpg|gif|ico|woff|woff2|ttf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    location = /service-worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # SPA routing - send all URLs to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name getreadyjob.com www.getreadyjob.com;
    return 301 https://$server_name$request_uri;
}
```

---

### Step 6: Test Site (5 min)

**Test from server**:
```bash
# Test HTTP redirect
curl -I http://getreadyjob.com
# Should show: HTTP/1.1 301 Moved Permanently
# Location: https://getreadyjob.com

# Test HTTPS
curl -I https://getreadyjob.com
# Should show: HTTP/1.1 200 OK
```

**Test from browser**:
1. Open https://www.getreadyjob.com
2. Should load homepage
3. Check for SSL lock icon (🔒)
4. No mixed content warnings
5. No 404 errors in browser console (F12)

**Test from mobile**:
1. Visit https://www.getreadyjob.com on iPhone/Android
2. Should be responsive
3. Should load without zooming needed
4. Touch buttons work

---

## ✅ QUICK VERIFICATION CHECKLIST

After uploading files, verify:

- [ ] **Files exist on server**
  ```bash
  ls -la /var/www/html/ | grep -E "index.html|main.dart.js"
  ```

- [ ] **Site loads via HTTPS**
  - Open browser: https://www.getreadyjob.com
  - Should load homepage
  - Should show SSL lock icon

- [ ] **No 404 errors**
  - Press F12 to open developer console
  - Reload page
  - No 404 errors for assets
  - Should see: main.dart.js loaded

- [ ] **HTTPS redirect works**
  - Try http://getreadyjob.com
  - Should redirect to https://getreadyjob.com

- [ ] **Responsive on mobile**
  - Open on phone browser
  - Should be responsive (no sideways scroll)
  - Touch buttons work

- [ ] **Service worker registered**
  - Open DevTools (F12)
  - Go to Application → Service Workers
  - Should show registered service worker

---

## 🔥 IMMEDIATE NEXT STEPS

1. **Share this guide** with your infrastructure/hosting team
2. **They follow steps 1-6** above (30-60 min)
3. **You test the site** at https://www.getreadyjob.com
4. **Site is LIVE** ✅

---

## 📝 AFTER DEPLOYMENT

Once site is live:

1. **Run full validation** (1 hour)
   - See: V2_POST_DEPLOYMENT_VALIDATION.md

2. **Test all browsers** (3-4 hours, optional but recommended)
   - See: BROWSER_COMPATIBILITY_CHECKLIST.md

3. **Begin RC phase monitoring** (1-2 weeks)
   - See: PRODUCT_HEALTH_DASHBOARD.md

---

## ⚠️ TROUBLESHOOTING

### Site shows 404
**Cause**: Files not in correct location
**Fix**: Verify files in `/var/www/html/` match paths above

### SSL certificate error
**Cause**: Certificate not configured or expired
**Fix**: Install new certificate with LetsEncrypt or your provider

### Page loads slowly
**Cause**: GZIP not enabled
**Fix**: Enable GZIP compression (see Step 5 above)

### Service worker error
**Cause**: HTTPS not working
**Fix**: Verify HTTPS is configured (service worker requires HTTPS)

### Files download instead of loading
**Cause**: MIME types not configured
**Fix**: Add to web server config:
```
application/javascript
application/wasm
text/html
```

---

## 💡 TIPS FOR SUCCESS

1. **Test locally first**: Before uploading, verify no files missing
2. **Backup**: Always backup existing site before uploading
3. **Verify upload**: Check key files exist after upload (index.html, main.dart.js, service-worker.js)
4. **Clear browser cache**: Ctrl+Shift+Delete if seeing old version
5. **Check console**: F12 → Console to see any errors
6. **Test on mobile**: Mobile users are important - test responsive design

---

## 🚀 READY TO LAUNCH

**You have everything needed:**
✅ Production build (build/web/ directory)
✅ Deployment instructions (this guide)
✅ Verification checklist (above)
✅ Support materials (if issues)

**Next**: Give this to your infrastructure team and they can have you live in 30-60 minutes!

---

**Status**: 🟢 **READY FOR DEPLOYMENT**

**Estimated time to live**: 1-2 hours (including testing)

Let's make https://www.getreadyjob.com live! 🎊

