# Integration Guide - Compression Server with JobReady App

This guide explains how to integrate the PDF/Image compression server with the main JobReady Flutter web application.

## Overview

The compression server can be:
1. **Embedded** - Run on the same backend server
2. **Standalone** - Run as separate microservice
3. **Cloud-hosted** - Deployed on AWS/GCP/Azure

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  JobReady Web App                        │
│  (Flutter Web / Main Application)                        │
└────────────────────┬─────────────────────────────────────┘
                     │
                     │ HTTP/WebSocket
                     ▼
┌──────────────────────────────────────────────────────────┐
│          Compression Server (Node.js/Express)           │
│  - File Upload Handling                                  │
│  - PDF/Image Processing                                 │
│  - Quality Control                                       │
│  - File Serving                                          │
└──────────────────────────────────────────────────────────┘
                     │
                     ▼
         ┌─────────────────────────┐
         │  sharp (Image Lib)      │
         │  pdf-lib (PDF Lib)      │
         │  multer (Upload)        │
         └─────────────────────────┘
```

---

## Option 1: Standalone Service (Recommended)

### Setup

1. **Keep compression server on separate port:**
   ```bash
   # Main app: port 80/3000
   # Compression: port 3001
   npm start  # Runs on port 3001
   ```

2. **Update Flutter/web app to call compression API:**

   **Dart (Flutter Web):**
   ```dart
   Future<void> compressFile(File file, int quality) async {
     final Uri uri = Uri.parse('http://localhost:3001/api/compress');
     final request = http.MultipartRequest('POST', uri)
       ..fields['quality'] = quality.toString()
       ..fields['format'] = 'webp'
       ..files.add(await http.MultipartFile.fromPath('file', file.path));

     final response = await request.send();
     if (response.statusCode == 200) {
       // Handle compressed file
       final compressed = await response.stream.toBytes();
       // Save or download
     }
   }
   ```

   **JavaScript (React/Vue):**
   ```javascript
   async function compressFile(file, quality) {
     const formData = new FormData();
     formData.append('file', file);
     formData.append('quality', quality);
     formData.append('format', 'webp');

     const response = await fetch('http://localhost:3001/api/compress', {
       method: 'POST',
       body: formData
     });

     if (response.ok) {
       const blob = await response.blob();
       return blob;
     }
   }
   ```

### CORS Configuration

If running on different ports/domains, add CORS to `compression_server.js`:

```javascript
import cors from 'cors';

app.use(cors({
  origin: ['http://localhost:3000', 'http://getreadyjob.com'],
  methods: ['POST', 'GET', 'OPTIONS'],
  credentials: true
}));
```

Install CORS:
```bash
npm install cors
```

---

## Option 2: Integrated Service

### Combine with Express app

If your main backend is also Node.js/Express:

```javascript
// main-app.js
import express from 'express';
import compression from 'express-compression';

const app = express();

// Main routes
app.get('/api/data', (req, res) => { /* ... */ });

// Mount compression service
import('./compression_server.js').then(module => {
  app.use('/compression', module.router);
});

app.listen(3000);
```

### Shared middleware

```javascript
// shared-middleware.js
export const secureUpload = [
  authenticate(),    // Your auth middleware
  rateLimit(),       // Rate limiting
  validateFile()     // File validation
];

// Use in compression server
app.post('/api/compress', secureUpload, upload.single('file'), /* ... */);
```

---

## Option 3: Docker Compose (Production)

Run multiple services together:

```yaml
# docker-compose.prod.yml
version: '3.9'

services:
  main-app:
    build: ./main-app
    ports:
      - "3000:3000"
    depends_on:
      - compression-server
    environment:
      - COMPRESSION_URL=http://compression-server:3000

  compression-server:
    build: ./compression-server
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/info"]
      interval: 30s
      timeout: 10s
      retries: 3
```

Start:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

---

## Configuration for Integration

### Environment Variables

Create `.env` file:

```env
# Main app
MAIN_APP_PORT=3000
MAIN_APP_URL=http://localhost:3000

# Compression service
COMPRESSION_PORT=3001
COMPRESSION_URL=http://localhost:3001
COMPRESSION_MAX_FILE_SIZE=100M
COMPRESSION_QUALITY_MIN=50
COMPRESSION_QUALITY_MAX=90

# Database/Storage
DATABASE_URL=mongodb://localhost/jobready
STORAGE_BUCKET=getreadyjob-uploads
```

Load in app:
```javascript
import dotenv from 'dotenv';
dotenv.config();

const COMPRESSION_URL = process.env.COMPRESSION_URL || 'http://localhost:3001';
```

---

## Frontend Integration Examples

### 1. Simple Upload Button

```html
<form id="compressForm">
  <input type="file" id="fileInput" accept=".pdf,.jpg,.png" />
  <input type="range" id="quality" min="50" max="90" value="70" />
  <button type="submit">Compress & Download</button>
</form>

<script>
document.getElementById('compressForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const file = document.getElementById('fileInput').files[0];
  const quality = document.getElementById('quality').value;

  const formData = new FormData();
  formData.append('file', file);
  formData.append('quality', quality);

  try {
    const response = await fetch('http://localhost:3001/api/compress', {
      method: 'POST',
      body: formData
    });
    const blob = await response.blob();

    // Trigger download
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `compressed_${file.name}`;
    a.click();
  } catch (error) {
    console.error('Compression failed:', error);
  }
});
</script>
```

### 2. React Component

```jsx
import React, { useState } from 'react';

function CompressionTool() {
  const [file, setFile] = useState(null);
  const [quality, setQuality] = useState(70);
  const [loading, setLoading] = useState(false);

  const handleCompress = async (e) => {
    e.preventDefault();
    if (!file) return;

    setLoading(true);
    const formData = new FormData();
    formData.append('file', file);
    formData.append('quality', quality);

    try {
      const response = await fetch('http://localhost:3001/api/compress', {
        method: 'POST',
        body: formData
      });
      const blob = await response.blob();

      // Download
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `compressed_${file.name}`;
      link.click();
    } catch (error) {
      alert(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleCompress}>
      <input
        type="file"
        onChange={(e) => setFile(e.target.files?.[0])}
        accept=".pdf,.jpg,.png"
      />
      <input
        type="range"
        min="50"
        max="90"
        value={quality}
        onChange={(e) => setQuality(Number(e.target.value))}
      />
      <p>Quality: {quality}%</p>
      <button type="submit" disabled={!file || loading}>
        {loading ? 'Compressing...' : 'Compress'}
      </button>
    </form>
  );
}

export default CompressionTool;
```

### 3. Vue.js Component

```vue
<template>
  <div class="compression-tool">
    <form @submit.prevent="handleCompress">
      <input
        type="file"
        @change="file = $event.target.files?.[0]"
        accept=".pdf,.jpg,.png"
      />

      <div>
        <label>Quality: {{ quality }}%</label>
        <input
          type="range"
          v-model="quality"
          min="50"
          max="90"
        />
      </div>

      <button :disabled="!file || loading">
        {{ loading ? 'Compressing...' : 'Compress' }}
      </button>

      <div v-if="error" class="error">{{ error }}</div>
    </form>
  </div>
</template>

<script>
export default {
  data() {
    return {
      file: null,
      quality: 70,
      loading: false,
      error: null
    };
  },
  methods: {
    async handleCompress() {
      if (!this.file) return;

      this.loading = true;
      this.error = null;

      try {
        const formData = new FormData();
        formData.append('file', this.file);
        formData.append('quality', this.quality);

        const response = await fetch('http://localhost:3001/api/compress', {
          method: 'POST',
          body: formData
        });

        if (!response.ok) throw new Error('Compression failed');

        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `compressed_${this.file.name}`;
        link.click();
      } catch (err) {
        this.error = err.message;
      } finally {
        this.loading = false;
      }
    }
  }
};
</script>
```

---

## API Endpoints for Integration

### Compression Endpoint

**POST** `/api/compress`

```bash
curl -X POST \
  -F "file=@document.pdf" \
  -F "quality=75" \
  http://localhost:3001/api/compress \
  -o result.pdf
```

### Server Info Endpoint

**GET** `/api/info`

```bash
curl http://localhost:3001/api/info
```

Response:
```json
{
  "maxFileSize": "100MB",
  "qualityRange": { "min": 50, "max": 90 },
  "supportedFormats": {
    "images": ["JPEG", "PNG", "WebP"],
    "documents": ["PDF"]
  },
  "outputFormats": ["WebP", "JPEG"]
}
```

---

## PDF Compression Expectations

### What to Expect
- **Text-heavy PDFs**: 5-15% smaller
- **Mixed content**: 15-30% smaller
- **Image-heavy**: Limited compression (10-20%) - external tools needed

### Why PDFs Have Limited Compression

The server optimizes PDF structure but doesn't re-encode embedded images because:
1. **Library limitation**: pdf-lib doesn't provide image extraction API
2. **Complexity**: Extracting, recompressing, and re-embedding images requires external tools
3. **Format**: Most PDFs already have compressed images

### For Better PDF Compression

If you need better PDF compression for image-heavy documents, integrate **Ghostscript** externally:

```javascript
// Optional: Call Ghostscript for better compression
import { exec } from 'child_process';

async function compressPdfGhostscript(input, output, quality) {
  return new Promise((resolve, reject) => {
    const setting = quality < 60 ? '/screen' : quality < 80 ? '/ebook' : '/printer';
    const cmd = `gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=${setting} -dNOPAUSE -dQUIET -dBATCH -sOutputFile=${output} ${input}`;
    exec(cmd, (err) => err ? reject(err) : resolve());
  });
}
```

---

### Local Development

1. Start main app (port 3000)
2. Start compression server (port 3001)
3. Update config to point to compression server
4. Test compression functionality

### Production

1. Deploy main app to production server
2. Deploy compression server to same/different server
3. Update environment variables with production URLs
4. Configure CORS for production domain
5. Set up SSL/TLS certificates
6. Configure reverse proxy (nginx)

### Docker Deployment

```bash
# Build both services
docker-compose build

# Start services
docker-compose up -d

# Verify
curl http://localhost:3001/api/info
```

---

## Performance Optimization

### Caching

```javascript
// Cache compression results (5 min)
app.use(compression({ filter: (req, res) => true }));

// Cache API responses
const redis = require('redis');
const client = redis.createClient();

app.get('/api/info', (req, res) => {
  client.get('api:info', (err, cached) => {
    if (cached) return res.json(JSON.parse(cached));

    const data = { /* info */ };
    client.setex('api:info', 300, JSON.stringify(data));
    res.json(data);
  });
});
```

### Load Balancing

```nginx
upstream compression {
  server localhost:3001;
  server localhost:3002;
  server localhost:3003;
}

server {
  location /api/compress {
    proxy_pass http://compression;
  }
}
```

---

## Monitoring & Logging

### Application Insights

```javascript
import appInsights from 'applicationinsights';

appInsights.setup(process.env.APPINSIGHTS_KEY)
  .setAutoDependencyCorrelation(true)
  .start();

app.post('/api/compress', (req, res) => {
  const client = appInsights.defaultClient;
  client.trackEvent({
    name: 'compression_started',
    properties: {
      fileSize: req.file.size,
      quality: req.body.quality
    }
  });
});
```

### Winston Logger

```javascript
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

logger.info('Compression server started');
```

---

## Troubleshooting Integration

| Issue | Solution |
|-------|----------|
| CORS errors | Add CORS middleware, check origin URLs |
| Connection refused | Verify compression server is running |
| Large files slow | Increase quality slider tolerance |
| Memory issues | Reduce max file size, add caching |
| Timeouts | Increase request timeout in client |

---

## Next Steps

1. ✅ Review architecture options
2. ✅ Choose integration approach
3. ✅ Update main app config
4. ✅ Add compression to UI
5. ✅ Test end-to-end
6. ✅ Deploy to staging
7. ✅ Deploy to production

---

Need help? Contact: hello@getreadyjob.com
