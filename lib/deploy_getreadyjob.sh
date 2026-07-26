#!/bin/bash
set -e

# GetReadyJob Automated Deployment Script
# Usage: bash deploy_getreadyjob.sh
# Purpose: Full production deployment in one command

echo "========================================="
echo "GetReadyJob Deployment Script Started"
echo "========================================="

# 1. Update system
echo "Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Node.js v24 LTS + npm
echo "Step 2: Installing Node.js v24 LTS + npm..."
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs

# 3. Install Docker + Docker Compose
echo "Step 3: Installing Docker + Docker Compose..."
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
newgrp docker

# 4. Install Nginx
echo "Step 4: Installing Nginx..."
sudo apt install -y nginx

# 5. Clone project
echo "Step 5: Cloning GetReadyJob repository..."
git clone https://github.com/your-repo/GetReadyJob.git /var/www/getreadyjob
cd /var/www/getreadyjob/lib

# 6. Install dependencies
echo "Step 6: Installing Node dependencies..."
npm install

# 7. Start server (background)
echo "Step 7: Starting Node.js server in background..."
nohup npm start > server.log 2>&1 &
sleep 2
echo "Server started with PID: $!"

# 8. Configure Nginx reverse proxy
echo "Step 8: Configuring Nginx reverse proxy..."
cat << 'EOF' | sudo tee /etc/nginx/sites-available/getreadyjob
server {
    listen 80;
    server_name getreadyjob.com www.getreadyjob.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# 9. Enable config
echo "Step 9: Enabling Nginx configuration..."
sudo ln -sf /etc/nginx/sites-available/getreadyjob /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# 10. SSL with Let's Encrypt
echo "Step 10: Setting up SSL/TLS with Let's Encrypt..."
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d getreadyjob.com -d www.getreadyjob.com --non-interactive --agree-tos -m admin@getreadyjob.com

# 11. Verify deployment
echo "Step 11: Verifying deployment..."
sleep 3

# Check HTTPS
echo "Checking HTTPS connection..."
curl -I https://getreadyjob.com || echo "Warning: HTTPS check failed (DNS may not be propagated yet)"

# Check API
echo "Checking API endpoint..."
curl -s https://getreadyjob.com/api/info | head -c 100 || echo "Warning: API check failed"

# Check processes
echo ""
echo "Checking running processes..."
ps aux | grep node || echo "Node.js process not found"
sudo systemctl status nginx --no-pager || echo "Nginx status check failed"

# 12. Output summary
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "✅ Next Steps:"
echo "1. Verify DNS A record points to this server"
echo "2. Wait 5-30 minutes for DNS propagation"
echo "3. Run Post-Launch Test Checklist:"
echo "   → QUICK_LAUNCH_CHECKS.md (10-15 min)"
echo "   → POST_LAUNCH_TEST_CHECKLIST.md (30-45 min)"
echo ""
echo "📍 Server Details:"
echo "   Domain: https://getreadyjob.com"
echo "   Server IP: $(hostname -I | awk '{print $1}')"
echo "   Node process: npm start (port 3000)"
echo "   Nginx: Reverse proxy + SSL/TLS"
echo ""
echo "📋 Monitoring Commands:"
echo "   Node logs: tail -f nohup.log"
echo "   Nginx logs: sudo tail -f /var/log/nginx/access.log"
echo "   Certbot renewal: sudo certbot renew --dry-run"
echo ""
echo "========================================="
