# Quick Start Guide - PDF/Image Compression Server

## 🚀 Quick Setup (5 minutes)

### Option 1: Local Node.js (Recommended for Development)

```powershell
# 1. Navigate to project directory
cd c:\JobReadyIndia\jobready_india\lib

# 2. Install dependencies
npm install

# 3. Create upload directory (if not exists)
mkdir temp_uploads

# 4. Start server
npm start

# 5. Open browser
Start-Process http://localhost:3000
```

**Expected Output:**
```
✓ Compression server running on http://localhost:3000
✓ Quality range: 50-90%
✓ Max file size: 100MB
```

---

### Option 2: Docker (Recommended for Production)

```powershell
# 1. Build image
docker build -t getreadyjob-compression .

# 2. Run container
docker run -p 3000:3000 -v ${PWD}\temp_uploads:/app/temp_uploads getreadyjob-compression

# 3. Open browser
Start-Process http://localhost:3000
```

---

### Option 3: Docker Compose (Easiest)

```powershell
# 1. Start service
docker-compose up -d

# 2. View logs
docker-compose logs -f compression-server

# 3. Open browser
Start-Process http://localhost:3000

# 4. Stop service
docker-compose down
```

---

## ✅ Verification Steps

1. **Check Server is Running:**
   ```powershell
   Invoke-WebRequest -Uri http://localhost:3000/api/info
   ```

2. **Test Compression (PowerShell):**
   ```powershell
   $file = "C:\path\to\test.pdf"
   $form = @{
       file = [System.IO.File]::ReadAllBytes($file)
       quality = 75
   }
   Invoke-WebRequest -Uri http://localhost:3000/api/compress -Method POST -Form $form
   ```

3. **Web UI Test:**
   - Open http://localhost:3000
   - Upload a test image (< 10MB)
   - Set quality to 70%
   - Click Compress
   - Verify download works

---

## 📊 Performance Testing

Test compression with different file types and qualities:

### Images (Recommended)
```powershell
# JPEG/PNG → WebP at 75% quality
# Expected: 40-50% file size reduction
# Speed: ~0.5-2s for typical images
```

### PDFs
```powershell
# PDF structure optimization
# Expected: 10-30% file size reduction (depends on content)
# Speed: 1-5s depending on file size
# Note: Quality slider has minimal effect on pre-compressed images
```

### Quality Testing
```powershell
# Test with 50% quality (maximum compression)
# Expected: 60-70% reduction for images

# Test with 75% quality (recommended)
# Expected: 40-50% reduction for images

# Test with 90% quality (high quality)
# Expected: 20-30% reduction for images
```

---

## 🔧 Troubleshooting

### Issue: npm install fails
```powershell
# Install build tools
choco install visualstudio2019-workload-vctools

# Then retry
npm install --build-from-source
```

### Issue: Port 3000 already in use
```powershell
# Use different port
$env:PORT=3001
npm start
```

### Issue: Sharp library fails on Windows
```powershell
# Install global sharp
npm install -g sharp

# Or use precompiled binary
npm install --no-save sharp --force
```

### Issue: Large PDF compression is slow
- Compression time depends on PDF complexity
- PDFs with images: 2-10 seconds
- Text PDFs: 0.5-2 seconds
- Large files (50MB+): May take 15-30 seconds

---

## 📝 Configuration

### Change Max File Size

Edit `compression_server.js` line ~20:
```javascript
limits: { fileSize: 200 * 1024 * 1024 } // 200MB instead of 100MB
```

### Change Port

```powershell
$env:PORT=8080
npm start
```

### Change Upload Directory

Edit `compression_server.js` line ~14:
```javascript
dest: path.join(__dirname, 'custom_uploads') // Custom path
```

---

## 🌐 API Usage Examples

### cURL - Compress PDF
```bash
curl -X POST \
  -F "file=@document.pdf" \
  -F "quality=75" \
  http://localhost:3000/api/compress \
  -o compressed.pdf
```

### cURL - Compress Image
```bash
curl -X POST \
  -F "file=@image.jpg" \
  -F "quality=70" \
  -F "format=webp" \
  http://localhost:3000/api/compress \
  -o image.webp
```

### PowerShell - Get Server Info
```powershell
$response = Invoke-WebRequest -Uri http://localhost:3000/api/info
$response.Content | ConvertFrom-Json
```

---

## 📦 Production Deployment

### Using PM2 (Process Manager)

```powershell
# Install PM2 globally
npm install -g pm2

# Start application
pm2 start compression_server.js --name "compression"

# View logs
pm2 logs compression

# Monitor
pm2 monit

# Restart
pm2 restart compression

# Stop
pm2 stop compression
```

### Environment Variables

```powershell
$env:NODE_ENV="production"
$env:PORT=8080
$env:LOG_LEVEL="info"
npm start
```

### HTTPS/SSL (with nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name compression.getreadyjob.com;

    ssl_certificate /etc/letsencrypt/live/getreadyjob.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/getreadyjob.com/privkey.pem;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 📊 Monitoring

### Check System Resources
```powershell
Get-Process node | Select-Object ProcessName, CPU, Memory
```

### View Server Logs
```powershell
# Development (npm start shows logs)
# Production (with PM2)
pm2 logs compression --lines 100
```

---

## 🧹 Cleanup

### Clear Temporary Files
```powershell
Remove-Item -Path ".\temp_uploads\*" -Force -Recurse
```

### Stop All Servers
```powershell
# Local development
# Ctrl+C in terminal

# Docker
docker stop $(docker ps -q)

# PM2
pm2 stop all
```

---

## ✨ Features Overview

| Feature | Status | Notes |
|---------|--------|-------|
| PDF Compression | ✅ | Supports all PDF versions |
| Image Compression | ✅ | JPEG, PNG, WebP support |
| Quality Slider | ✅ | 50-90% range |
| Web UI | ✅ | Drag & drop, real-time progress |
| Error Handling | ✅ | Comprehensive validation |
| File Limits | ✅ | 100MB default |
| Auto Cleanup | ✅ | Temp files auto-deleted |
| Docker Support | ✅ | Container ready |
| HTTPS Ready | ✅ | Reverse proxy compatible |
| Monitoring | ✅ | Health checks included |

---

## 📞 Support

For issues:
1. Check logs: `pm2 logs compression`
2. Verify file types are supported
3. Check file size < 100MB
4. Ensure Node.js 16+

Contact: hello@getreadyjob.com

---

## 🎯 Next Steps

1. ✅ Install and start server
2. ✅ Test with sample PDF/image
3. ✅ Adjust quality settings
4. ✅ Integrate with main application
5. ✅ Deploy to production with Docker

Happy Compressing! 🎉
