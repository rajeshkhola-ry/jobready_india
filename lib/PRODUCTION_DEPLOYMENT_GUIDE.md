# GetReadyJob Production Deployment Guide

**Date:** 2026-07-26
**Version:** v2.0 with Modern Compression Server
**Status:** Ready for Production

---

## 📋 Overview

This guide walks you through deploying GetReadyJob to production with:
- ✅ Node.js compression server (express + multer + pdf-lib)
- ✅ Modern frontend UI with drag-drop upload
- ✅ SSL/TLS security (Let's Encrypt)
- ✅ Nginx reverse proxy
- ✅ Docker containerization (optional)
- ✅ Domain pointing to server (getreadyjob.com)

**Expected Time:** 2-3 hours for complete setup

---

## 🎯 Deployment Architecture

```
Internet (HTTPS)
    ↓
Nginx Reverse Proxy (port 443 SSL/TLS)
    ↓
Node.js Server (port 3000)
    ├── /api/compress (compression API)
    ├── / (serves index.html)
    └── /public/* (static files)
```

---

## 📦 Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Server Details:**
  - Linux server (Ubuntu 20.04+ or CentOS 8+)
  - Public IP address or domain-ready
  - 50GB+ free disk space
  - SSH access (username + key/password)
  - Port 3000 available (or port you choose)

- [ ] **Domain:**
  - getreadyjob.com registered
  - DNS registrar access (GoDaddy, Namecheap, Cloudflare, etc.)
  - Ability to update A record

- [ ] **Code & Configuration:**
  - ✅ compression_server.js (ready)
  - ✅ public/index.html (ready)
  - ✅ public/design-system.css (ready)
  - ✅ package.json (ready)
  - ✅ Dockerfile (ready)
  - ✅ docker-compose.yml (ready)
  - ✅ Nginx config template (provided below)

---

## 🚀 PRODUCTION DEPLOYMENT STEPS

### PHASE 1: Server Preparation (30 minutes)

#### Step 1.1 - SSH into Server

```bash
ssh username@server_ip
# or
ssh -i /path/to/key.pem username@server_ip
```

#### Step 1.2 - Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

#### Step 1.3 - Install Docker & Docker Compose

**Option A - Docker (Recommended for containerization):**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
```

**Option B - Node.js Direct (if not using Docker):**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version  # verify v20+
npm --version   # verify v9+
```

#### Step 1.4 - Install Nginx

```bash
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Step 1.5 - Install SSL/TLS (Certbot & Let's Encrypt)

```bash
sudo apt-get install -y certbot python3-certbot-nginx
```

---

### PHASE 2: Deploy Code (30 minutes)

#### Step 2.1 - Clone/Upload Code

**Option A - Git Clone:**
```bash
cd /var/www
sudo git clone https://github.com/YOUR_REPO/jobready_india.git
sudo chown -R $USER:$USER jobready_india
cd jobready_india/lib
```

**Option B - SCP Upload:**
```bash
# From your local machine:
scp -r c:\JobReadyIndia\jobready_india\lib username@server_ip:/var/www/jobready

# Then SSH in:
ssh username@server_ip
cd /var/www/jobready
```

#### Step 2.2 - Verify Files Exist

```bash
ls -la
# Should show: compression_server.js, package.json, public/, Dockerfile, docker-compose.yml
```

#### Step 2.3 - Deploy with Docker (Recommended)

```bash
# Build and start
sudo docker-compose build
sudo docker-compose up -d

# Verify it's running
sudo docker-compose ps
sudo docker-compose logs -f jobready-compression  # watch logs
```

**To Stop:**
```bash
sudo docker-compose down
```

---

**OR: Deploy with Node.js Direct**

```bash
npm install
npm start &  # runs in background

# Verify
ps aux | grep node
netstat -tulpn | grep 3000
```

---

### PHASE 3: Configure Domain (15 minutes)

#### Step 3.1 - Update DNS A Record

1. Log in to your domain registrar (GoDaddy, Namecheap, Cloudflare, etc.)
2. Find DNS settings
3. Update **A record:**
   - **Name:** @ (or leave blank)
   - **Value:** `your_server_ip`
   - **TTL:** 3600 (1 hour)
4. Click Save

**Verify DNS propagation:**
```bash
nslookup getreadyjob.com
# Should return your server IP
```

#### Step 3.2 - Wait for DNS (5-30 minutes)

DNS can take up to 30 minutes to propagate globally. Check status:
```bash
curl -I http://getreadyjob.com
# Should not timeout
```

---

### PHASE 4: Configure SSL/TLS (20 minutes)

#### Step 4.1 - Get SSL Certificate

```bash
sudo certbot certonly --nginx -d getreadyjob.com -d www.getreadyjob.com
# Follow prompts (enter email, agree to terms)
```

**Verify certificate created:**
```bash
sudo ls -la /etc/letsencrypt/live/getreadyjob.com/
# Should show: privkey.pem, fullchain.pem, etc.
```

---

### PHASE 5: Configure Nginx Reverse Proxy (20 minutes)

#### Step 5.1 - Create Nginx Config

```bash
sudo nano /etc/nginx/sites-available/getreadyjob
```

**Paste this configuration:**

```nginx
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name getreadyjob.com www.getreadyjob.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name getreadyjob.com www.getreadyjob.com;

    # SSL certificates (from Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/getreadyjob.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/getreadyjob.com/privkey.pem;

    # SSL configuration (recommended)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Compression
    gzip on;
    gzip_types text/html text/plain text/css text/javascript application/json application/javascript;
    gzip_min_length 1000;

    # Root directory (if serving static files)
    root /var/www/jobready/lib/public;

    # Logging
    access_log /var/log/nginx/getreadyjob_access.log;
    error_log /var/log/nginx/getreadyjob_error.log;

    # Proxy to Node.js server
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # API routes
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        client_max_body_size 100M;
    }
}
```

#### Step 5.2 - Enable Nginx Site

```bash
sudo ln -s /etc/nginx/sites-available/getreadyjob /etc/nginx/sites-enabled/
```

#### Step 5.3 - Test Nginx Config

```bash
sudo nginx -t
# Should output: "test is successful"
```

#### Step 5.4 - Restart Nginx

```bash
sudo systemctl restart nginx
```

---

### PHASE 6: Verify Production Deployment (30 minutes)

#### Step 6.1 - Test HTTP Redirect

```bash
curl -I http://getreadyjob.com
# Should redirect to https
```

#### Step 6.2 - Test HTTPS & SSL

```bash
curl -I https://getreadyjob.com
# Should return 200 OK with SSL certificate
```

**Or in browser:**
```
https://getreadyjob.com
```

Should show:
- ✅ 🔒 Green lock icon (SSL/TLS secure)
- ✅ Compression tool UI loaded
- ✅ No console errors

#### Step 6.3 - Test Compression API

```bash
curl https://getreadyjob.com/api/info
# Should return JSON with server info
```

Expected response:
```json
{
  "status": "running",
  "version": "1.0.0",
  "maxFileSize": "100MB",
  "qualityRange": { "min": 50, "max": 90 },
  "supportedFormats": { "input": ["pdf", "jpeg", "png", "webp"], "output": ["webp", "jpeg"] }
}
```

#### Step 6.4 - Test Frontend (Manual)

1. Open https://getreadyjob.com in browser
2. Try uploading a PDF or image file
3. Adjust quality slider (50-90)
4. Click "Compress"
5. Verify download works

---

### PHASE 7: Monitor & Maintain (Ongoing)

#### Check Server Logs

```bash
# Docker logs
sudo docker-compose logs -f jobready-compression

# OR Node.js logs
ps aux | grep node
```

#### Monitor Resources

```bash
# CPU, Memory, Disk
top
df -h

# Network connections
netstat -tulpn | grep 3000
```

#### SSL Certificate Auto-Renewal

Certbot auto-renews certificates 30 days before expiration:
```bash
# Check renewal status
sudo certbot renew --dry-run
```

---

## 📊 Checklist: Pre-Launch Verification

Before announcing to users, verify everything:

**Server Accessibility:**
- [ ] https://getreadyjob.com loads in browser
- [ ] 🔒 Green lock icon visible
- [ ] No SSL warnings
- [ ] Page loads in <2 seconds

**Compression Tool:**
- [ ] Upload area visible
- [ ] Quality slider works (50-90%)
- [ ] Format selector shows options
- [ ] Upload a test file
- [ ] Compression completes
- [ ] Download works
- [ ] File size reduced

**Error Handling:**
- [ ] Upload >100MB file → error shown
- [ ] Upload invalid format → error shown
- [ ] Cancel compression → works
- [ ] No server crashes in logs

**Mobile Responsive:**
- [ ] Resize browser to 480px → layout adapts
- [ ] Resize to 768px → layout works
- [ ] Resize to 1200px → desktop view
- [ ] Test on actual phone (same WiFi)

**API Verification:**
```bash
curl -s https://getreadyjob.com/api/info | jq .
```

Expected output has `"status": "running"`

**Performance:**
- [ ] Page load time <2 seconds
- [ ] CSS loads without errors
- [ ] No JavaScript console errors
- [ ] Network tab shows all resources loading

---

## 🎯 Troubleshooting

### Server Won't Start

**Check logs:**
```bash
sudo docker-compose logs jobready-compression
# OR
journalctl -xe
```

**Common issues:**
- Port 3000 already in use → `sudo lsof -i :3000` to find process
- Permissions → `sudo chown -R www-data:www-data /var/www/jobready`
- Node version → `node --version` (must be v14+)

### Domain Not Working

**Check DNS:**
```bash
nslookup getreadyjob.com
# Should return your server IP
```

**Check Nginx:**
```bash
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl status nginx
```

### SSL Certificate Issues

**Check certificate:**
```bash
sudo certbot certificates
```

**Renew manually:**
```bash
sudo certbot renew --force-renewal
sudo systemctl restart nginx
```

### Compression Not Working

**Check Node.js:**
```bash
curl http://localhost:3000/api/info
```

**Verify sharp installed (for image compression):**
```bash
npm list sharp
```

If missing: `npm install sharp --save`

---

## 📞 Support & Rollback

### Rollback to Previous Version

```bash
# If using Docker
sudo docker-compose down
git checkout previous_commit
sudo docker-compose build
sudo docker-compose up -d

# If using Node.js
npm list  # check version
# Replace files with previous version
npm install
npm start &
```

### Emergency Stop

```bash
# Docker
sudo docker-compose stop

# Node.js
ps aux | grep node
kill -9 PID
```

---

## 🚀 Launch Checklist: Go-Live Steps

Once verified (all checks above passed):

1. [ ] **Notify team** → "GetReadyJob going live in 5 minutes"
2. [ ] **Monitor logs** → `sudo docker-compose logs -f`
3. [ ] **Announce to users** → "GetReadyJob is now live at getreadyjob.com! 🎉"
4. [ ] **Update status** → Mark `IMPLEMENTATION_SUMMARY.md` as LIVE
5. [ ] **Monitor for 1 hour** → Check logs, error rates, performance
6. [ ] **Backup database** → If applicable
7. [ ] **Document deployment** → Save deployment notes

---

## 📝 Post-Deployment Documentation

Update `IMPLEMENTATION_SUMMARY.md`:

```markdown
## ✅ DEPLOYMENT COMPLETE

**Date:** [DATE]
**Status:** 🟢 LIVE
**URL:** https://getreadyjob.com
**Server:** [SERVER_IP]
**SSL:** ✅ Let's Encrypt Certificate
**Unused Files:** ✅ Archived in Unused_Files/ folder

### Deployment Details
- Compression Server: Running (Node.js v24, port 3000)
- Frontend: Live with modern UI/UX
- Domain: getreadyjob.com (A record pointing to SERVER_IP)
- SSL/TLS: Configured with auto-renewal
- Nginx: Reverse proxy configured
- Uptime Monitoring: [Configure if available]
```

---

## 🎉 You're Live!

GetReadyJob is now live at **https://getreadyjob.com** with:
- ✅ Modern compression tool frontend
- ✅ Secure SSL/TLS connection
- ✅ Fast Nginx reverse proxy
- ✅ Professional error handling
- ✅ Mobile-responsive design

**Monitor logs regularly and celebrate! 🚀**

---

**Questions?** Check troubleshooting section or review FINAL_LAUNCH_CHECKLIST.md for additional details.
