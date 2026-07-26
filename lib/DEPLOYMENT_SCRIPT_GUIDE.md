# 🚀 One-Command Deployment Script Guide

**File:** `deploy_getreadyjob.sh`
**Purpose:** Fully automated production deployment in one command
**Duration:** 15-20 minutes (depending on internet speed)
**Difficulty:** Easy (just run the script)

---

## ⚡ Quick Start

### Step 1: Prerequisites (Have Ready)
```
✅ Linux server (Ubuntu 20.04+ or CentOS 8+)
✅ SSH access to the server
✅ Git installed on server (or install during script)
✅ Sudo/root privileges
✅ Domain: getreadyjob.com (DNS registrar access)
✅ Email for Let's Encrypt: admin@getreadyjob.com
```

### Step 2: Upload Script to Server
```bash
# Option A: SCP (from your local machine)
scp deploy_getreadyjob.sh username@your-server-ip:/home/username/

# Option B: SSH in and create manually
ssh username@your-server-ip
nano deploy_getreadyjob.sh
# Paste the script content, save (Ctrl+X, Y, Enter)
```

### Step 3: Run the Script
```bash
# SSH into your server
ssh username@your-server-ip

# Make script executable
chmod +x deploy_getreadyjob.sh

# Run it
bash deploy_getreadyjob.sh

# Or with sudo if needed:
sudo bash deploy_getreadyjob.sh
```

### Step 4: Wait for Completion
Script will:
- ✅ Update system (1-2 min)
- ✅ Install Node.js v24, Docker, Nginx (3-5 min)
- ✅ Clone your repository (1-2 min)
- ✅ Install npm dependencies (3-5 min)
- ✅ Configure Nginx reverse proxy (30 sec)
- ✅ Setup SSL/TLS with Let's Encrypt (2-3 min)
- ✅ Verify deployment (1 min)

**Total: 15-20 minutes**

---

## 📋 What the Script Does (Step by Step)

### Step 1: Update System
```bash
sudo apt update && sudo apt upgrade -y
```
- Updates all system packages to latest versions
- **Time:** 1-2 minutes

### Step 2: Install Node.js v24 LTS + npm
```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
```
- Installs Node.js v24.18.0 LTS (production-ready)
- Includes npm v11.16.0
- **Time:** 2-3 minutes

### Step 3: Install Docker + Docker Compose
```bash
sudo apt install -y docker.io docker-compose
```
- Installs Docker for containerization
- Installs Docker Compose for multi-container orchestration
- **Time:** 2-3 minutes

### Step 4: Install Nginx
```bash
sudo apt install -y nginx
```
- Installs Nginx as reverse proxy
- Will sit in front of Node.js server
- Handles SSL/TLS and static file serving
- **Time:** 1-2 minutes

### Step 5: Clone Project
```bash
git clone https://github.com/your-repo/GetReadyJob.git /var/www/getreadyjob
cd /var/www/getreadyjob/lib
```
- Downloads your GetReadyJob repository
- Places in `/var/www/getreadyjob`
- Navigates to `/lib` directory
- **Note:** Replace `https://github.com/your-repo/GetReadyJob.git` with your actual repository URL
- **Time:** 1-2 minutes

### Step 6: Install Dependencies
```bash
npm install
```
- Installs express, multer, pdf-lib, nodemon, etc.
- Creates `node_modules/` folder
- Installs ~90+ packages
- **Time:** 3-5 minutes

### Step 7: Start Node Server
```bash
nohup npm start > server.log 2>&1 &
```
- Starts Node.js compression server in background
- Server listens on `http://localhost:3000`
- Output logged to `server.log`
- Runs with `nohup` (persists after SSH logout)
- **Time:** < 1 minute

### Step 8: Configure Nginx Reverse Proxy
```nginx
server {
    listen 80;
    server_name getreadyjob.com www.getreadyjob.com;

    location / {
        proxy_pass http://localhost:3000;
        # WebSocket support
        # Caching headers
        # Compression settings
    }
}
```
- Creates Nginx configuration for reverse proxy
- Routes HTTP traffic from port 80 → Node.js on port 3000
- Enables WebSocket support for real-time features
- Adds caching headers for static assets
- Enables gzip compression
- **Time:** < 1 minute

### Step 9: Enable Nginx Configuration
```bash
sudo ln -sf /etc/nginx/sites-available/getreadyjob /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```
- Creates symlink to enable the site
- Tests Nginx configuration for errors
- Restarts Nginx to apply changes
- **Time:** < 1 minute

### Step 10: Setup SSL/TLS with Let's Encrypt
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d getreadyjob.com -d www.getreadyjob.com \
  --non-interactive --agree-tos -m admin@getreadyjob.com
```
- Installs Certbot (Let's Encrypt client)
- Automatically:
  - ✅ Verifies domain ownership
  - ✅ Generates SSL certificate
  - ✅ Updates Nginx config for HTTPS
  - ✅ Sets up auto-renewal (runs daily)
  - ✅ HTTP → HTTPS redirect
- **Certificate Valid For:** 90 days (auto-renews before expiry)
- **Time:** 2-3 minutes

### Step 11: Verify Deployment
```bash
curl -I https://getreadyjob.com
curl -s https://getreadyjob.com/api/info
ps aux | grep node
sudo systemctl status nginx
```
- Tests HTTPS connection
- Tests API endpoint
- Verifies Node.js is running
- Verifies Nginx is running
- **Time:** < 1 minute

---

## ✅ Expected Output

After script completes, you should see:

```
=========================================
GetReadyJob Deployment Script Started
=========================================
Step 1: Updating system packages...
[Package updates...]

Step 2: Installing Node.js v24 LTS + npm...
[Node installation...]

Step 3: Installing Docker + Docker Compose...
[Docker installation...]

... (continues) ...

=========================================
Deployment Complete!
=========================================

✅ Next Steps:
1. Verify DNS A record points to this server
2. Wait 5-30 minutes for DNS propagation
3. Run Post-Launch Test Checklist:
   → QUICK_LAUNCH_CHECKS.md (10-15 min)
   → POST_LAUNCH_TEST_CHECKLIST.md (30-45 min)

📍 Server Details:
   Domain: https://getreadyjob.com
   Server IP: 123.45.67.89
   Node process: npm start (port 3000)
   Nginx: Reverse proxy + SSL/TLS

📋 Monitoring Commands:
   Node logs: tail -f nohup.log
   Nginx logs: sudo tail -f /var/log/nginx/access.log
   Certbot renewal: sudo certbot renew --dry-run

=========================================
```

---

## ⚠️ Important Before Running

### 1. Update Repository URL
**Line 21 in script:**
```bash
# CURRENT (CHANGE THIS):
git clone https://github.com/your-repo/GetReadyJob.git /var/www/getreadyjob

# SHOULD BE (your actual repo):
git clone https://github.com/YOUR-USERNAME/jobready_india.git /var/www/getreadyjob
```

### 2. Update Email Address
**Line 61 in script:**
```bash
# CURRENT (CHANGE THIS):
sudo certbot --nginx -d getreadyjob.com -d www.getreadyjob.com --non-interactive --agree-tos -m admin@getreadyjob.com

# SHOULD BE (your email):
sudo certbot --nginx -d getreadyjob.com -d www.getreadyjob.com --non-interactive --agree-tos -m your-email@example.com
```

### 3. Verify DNS A Record is Set
Before running:
```bash
# Check if DNS is already pointing to your server
nslookup getreadyjob.com
# Should show your server's IP address
```

If DNS not set yet:
1. Go to your domain registrar (GoDaddy, Namecheap, etc.)
2. Update DNS A record to point to your server IP
3. Wait 5-30 minutes for propagation
4. Run script

---

## 🔧 Troubleshooting During Script Execution

### Issue: Permission Denied
```bash
# Solution: Run with explicit sudo
sudo bash deploy_getreadyjob.sh
```

### Issue: Repository Not Found
```bash
# Solution: Update the git clone URL in script to your actual repo
# Edit line 21 with your GitHub repo URL
```

### Issue: Let's Encrypt Certificate Fails
```bash
# Reason: DNS not propagated yet or Let's Encrypt rate limit hit
# Solution: Wait 30 minutes, check DNS, try again
nslookup getreadyjob.com
```

### Issue: Port 80/443 Already in Use
```bash
# Solution: Check what's using the port
sudo lsof -i :80
sudo lsof -i :443

# Kill the process or reconfigure
sudo systemctl stop apache2  # if Apache is running
```

---

## ✨ After Script Completes

### Immediately After (DNS Propagation Wait)
```bash
# 1. Check if DNS is propagated yet
nslookup getreadyjob.com
# If still shows old IP, wait 5-30 more minutes

# 2. Monitor server logs
ssh username@server-ip
tail -f /home/username/nohup.log
```

### After DNS Propagates (Usually 5-30 min)
```bash
# Run Quick Checks
# Open QUICK_LAUNCH_CHECKS.md in your editor
# Run 10 checks (10-15 minutes)
```

### If Quick Checks Pass
```bash
# Run Comprehensive Tests
# Open POST_LAUNCH_TEST_CHECKLIST.md in your editor
# Run 14 test suites (30-45 minutes)
```

### If All Tests Pass
```bash
# Announce to users!
# Update IMPLEMENTATION_SUMMARY.md status to 🟢 LIVE
# Send announcement email
```

---

## 📊 Timeline Example

```
2:00 PM: SSH into server
2:02 PM: Upload script and run: bash deploy_getreadyjob.sh
2:22 PM: Script completes (15-20 min execution time)
2:22 PM: Verify: curl -I https://getreadyjob.com (may timeout if DNS not ready)
2:30 PM: DNS propagates (wait 5-10 more minutes)
2:35 PM: Run QUICK_LAUNCH_CHECKS.md (10-15 min)
2:50 PM: Run POST_LAUNCH_TEST_CHECKLIST.md (30-45 min)
3:20 PM: All tests pass ✅
3:25 PM: Announce to users! 🎉
```

**Total Time: ~1.5 hours from script start to public announcement**

---

## 🎯 One-Line Summary

**Save script → Upload to server → Run `bash deploy_getreadyjob.sh` → Wait 15-20 min → Site is live with HTTPS! 🚀**

---

## 📚 Reference Commands (After Script Completes)

### Check Logs
```bash
# Node.js server logs
tail -f nohup.log

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Get server status
ps aux | grep node
sudo systemctl status nginx
```

### Troubleshooting
```bash
# Check if Node.js is running
curl http://localhost:3000

# Check if Nginx is running
sudo systemctl status nginx

# Restart services
sudo systemctl restart nginx
pkill -f "npm start" ; npm start &

# SSL certificate info
sudo certbot certificates
sudo certbot renew --dry-run
```

### Monitoring
```bash
# CPU/Memory usage
top

# Disk space
df -h

# Network connections
netstat -tlnp | grep LISTEN
```

---

**Script Version:** v1.0
**Created:** 2026-07-26
**For:** GetReadyJob Production Deployment

🚀 **Ready to deploy? Save the script and run it on your server!**
