# ⚡ Render.com Quick Deploy (10-15 Minutes)

**Cost:** Free tier available
**Time:** 10-15 minutes
**Difficulty:** Very Easy
**Result:** Backend live at https://getreadyjob.onrender.com

---

## 🚀 FASTEST PATH (Copy-Paste Guide)

### 1. Sign Up (2 minutes)
```
→ Go to https://render.com
→ Click "Sign Up"
→ Choose "Sign up with GitHub"
→ Authorize Render
→ Confirm email
```

### 2. Create Web Service (2 minutes)
```
→ Dashboard → "New +"
→ Select "Web Service"
→ Click "Connect a repository"
→ Find your repo: jobready_india
→ Click "Connect"
```

### 3. Configure Service (5 minutes)
```
Service Name:       getreadyjob
Root Directory:     lib
Build Command:      npm install
Start Command:      npm start
Plan:               Free
```

### 4. Add Environment Variables (2 minutes)
```
NODE_ENV  =  production
PORT      =  10000
```

### 5. Deploy! (1 minute)
```
→ Click "Create Web Service"
→ Wait 2-3 minutes
→ Status: Live ✅
→ Your URL: https://getreadyjob.onrender.com
```

---

## ✅ AFTER DEPLOYMENT

### Test API
```bash
curl https://getreadyjob.onrender.com/api/info

# Should return:
# {"status":"running",...}
```

### Test Compression
```bash
curl -X POST \
  -F "file=@file.pdf" \
  -F "quality=70" \
  https://getreadyjob.onrender.com/api/compress
```

---

## 📊 YOUR PUBLIC BACKEND URL

```
https://getreadyjob.onrender.com
```

**Use this in your frontend/tests!**

---

## 🆘 TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| Build fails | Check package.json syntax, look at Logs |
| Service crashes | Check root directory is `lib`, verify commands |
| API returns error | Wait for deployment, check Logs tab |
| Still deploying | Wait 2-3 minutes, patience! |

---

## 🎯 NEXT STEPS

1. ✅ Deploy to Render (using steps above)
2. ✅ Test API endpoint (using curl commands)
3. ✅ Update frontend to point to new URL
4. ✅ Run post-launch tests
5. ✅ Announce site is live!

---

**Total Time to Live: ~15 minutes ⚡**

For detailed guide: See [RENDER_DEPLOYMENT_GUIDE.md](RENDER_DEPLOYMENT_GUIDE.md)
