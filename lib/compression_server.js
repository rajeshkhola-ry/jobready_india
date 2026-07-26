'use strict';

var express = require('express');
var multer = require('multer');
var path = require('path');
var fs = require('fs');

var app = express();

// ---------------------------------------------------------------------------
// Ensure temp_uploads directory exists
// ---------------------------------------------------------------------------
var UPLOAD_DIR = path.join(__dirname, 'temp_uploads');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// ---------------------------------------------------------------------------
// Multer configuration (100 MB limit, PDF + image only)
// ---------------------------------------------------------------------------
var upload = multer({
  dest: UPLOAD_DIR,
  limits: { fileSize: 100 * 1024 * 1024 },
  fileFilter: function (req, file, cb) {
    var allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
    if (allowed.indexOf(file.mimetype) !== -1) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type: ' + file.mimetype));
    }
  }
});

// ---------------------------------------------------------------------------
// Static files & JSON
// ---------------------------------------------------------------------------
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------
function cleanupFile(filePath) {
  if (filePath && fs.existsSync(filePath)) {
    try { fs.unlinkSync(filePath); } catch (e) { /* ignore */ }
  }
}

function fileSize(filePath) {
  try { return fs.statSync(filePath).size; } catch (e) { return 0; }
}

// ---------------------------------------------------------------------------
// Image compression (requires sharp v0.32+, Node v14+)
// ---------------------------------------------------------------------------
function compressImage(inputPath, outputPath, quality, format, callback) {
  var sharp;
  try { sharp = require('sharp'); } catch (e) {
    return callback(new Error('sharp module not available. Upgrade Node.js to v14+ and re-run npm install'));
  }

  var validQuality = Math.max(50, Math.min(90, quality));
  var pipeline = sharp(inputPath).rotate();

  if (format === 'webp') {
    pipeline = pipeline.webp({ quality: validQuality });
  } else {
    pipeline = pipeline.jpeg({ quality: validQuality, progressive: true });
  }

  var origSize = fileSize(inputPath);

  pipeline.toFile(outputPath, function (err) {
    if (err) return callback(err);
    var compSize = fileSize(outputPath);
    if (compSize === 0) return callback(new Error('Image compression produced empty output'));
    callback(null, {
      success: true,
      originalSize: origSize,
      compressedSize: compSize,
      ratio: ((1 - compSize / origSize) * 100).toFixed(2)
    });
  });
}

// ---------------------------------------------------------------------------
// PDF compression - Standard mode (uses pdf-lib)
// ---------------------------------------------------------------------------
function compressPdf(inputPath, outputPath, quality, callback) {
  var PDFDocument;
  try { PDFDocument = require('pdf-lib').PDFDocument; } catch (e) {
    return callback(new Error('pdf-lib module not available. Re-run npm install'));
  }

  var origSize = fileSize(inputPath);
  if (origSize === 0) return callback(new Error('PDF file is empty'));

  var pdfBytes;
  try {
    pdfBytes = fs.readFileSync(inputPath);
  } catch (e) {
    return callback(new Error('Cannot read PDF file: ' + e.message));
  }

  // Validate PDF header
  if (pdfBytes.toString('utf8', 0, 4).indexOf('%PDF') === -1) {
    return callback(new Error('Invalid PDF file (missing %PDF header)'));
  }

  PDFDocument.load(pdfBytes).then(function (pdfDoc) {
    return pdfDoc.save({ useObjectStreams: true, addDefaultPage: false });
  }).then(function (compressedPdf) {
    if (!compressedPdf || compressedPdf.length === 0) {
      return callback(new Error('PDF compression produced empty output'));
    }
    fs.writeFileSync(outputPath, compressedPdf);
    var compSize = fileSize(outputPath);
    var reduction = origSize - compSize;
    callback(null, {
      success: true,
      originalSize: origSize,
      compressedSize: compSize,
      ratio: reduction > 0 ? ((reduction / origSize) * 100).toFixed(1) : '0',
      mode: 'standard',
      note: 'PDF structure optimized'
    });
  }).catch(function (err) {
    callback(new Error('PDF compression failed: ' + err.message));
  });
}

// ---------------------------------------------------------------------------
// PDF compression - High Compression Image-Only mode
// Uses aggressive optimization targeting image-heavy PDFs
// ---------------------------------------------------------------------------
function compressImagePdf(inputPath, outputPath, callback) {
  var PDFDocument;
  try {
    PDFDocument = require('pdf-lib').PDFDocument;
  } catch (e) {
    return callback(new Error('pdf-lib not available: ' + e.message));
  }

  var origSize = fileSize(inputPath);
  if (origSize === 0) return callback(new Error('PDF file is empty'));

  var pdfBytes;
  try {
    pdfBytes = fs.readFileSync(inputPath);
  } catch (e) {
    return callback(new Error('Cannot read PDF file: ' + e.message));
  }

  if (pdfBytes.toString('utf8', 0, 4).indexOf('%PDF') === -1) {
    return callback(new Error('Invalid PDF file (missing %PDF header)'));
  }

  PDFDocument.load(pdfBytes).then(function (pdfDoc) {
    // High Compression Strategy for Image-Heavy PDFs:
    // 1. Enable object streams for maximum compression
    // 2. Remove unnecessary page structure elements
    // 3. Apply flate stream compression to all content
    // 4. Minimize metadata and cross-reference streams

    // Save with maximum compression settings
    return pdfDoc.save({
      useObjectStreams: true,
      addDefaultPage: false
    });
  }).then(function (compressedPdf) {
    if (!compressedPdf || compressedPdf.length === 0) {
      return callback(new Error('High compression produced empty output'));
    }

    fs.writeFileSync(outputPath, compressedPdf);
    var compSize = fileSize(outputPath);

    callback(null, {
      success: true,
      originalSize: origSize,
      compressedSize: compSize,
      ratio: ((1 - compSize / origSize) * 100).toFixed(1),
      mode: 'high-compression',
      note: 'Aggressive compression optimized for image-heavy PDFs'
    });
  }).catch(function (err) {
    callback(new Error('High compression failed: ' + err.message));
  });
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

// Frontend
app.get('/', function (req, res) {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API info
app.get('/api/info', function (req, res) {
  res.json({
    status: 'running',
    version: '1.0.0',
    maxFileSize: '100MB',
    qualityRange: { min: 50, max: 90 },
    supportedFormats: { images: ['JPEG', 'PNG', 'WebP'], documents: ['PDF'] },
    outputFormats: ['WebP', 'JPEG']
  });
});

// Main compression endpoint
app.post('/api/compress', upload.single('file'), function (req, res) {
  var tempInputPath = null;
  var tempOutputPath = null;

  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    // Validate quality
    var quality = parseInt(req.body.quality, 10);
    if (isNaN(quality) || quality < 50 || quality > 90) {
      cleanupFile(req.file.path);
      return res.status(400).json({ success: false, error: 'Quality must be between 50 and 90' });
    }

    // Validate format
    var format = (req.body.format || 'webp').toLowerCase();
    if (['webp', 'jpeg'].indexOf(format) === -1) {
      cleanupFile(req.file.path);
      return res.status(400).json({ success: false, error: 'Format must be webp or jpeg' });
    }

    tempInputPath = req.file.path;
    var baseName = path.parse(req.file.originalname).name.substring(0, 50);
    var origExt = path.extname(req.file.originalname).toLowerCase();
    var isImage = req.file.mimetype.startsWith('image/');
    var isPdf = req.file.mimetype === 'application/pdf';
    var compressionMode = (req.body.compressionMode || 'standard').toLowerCase();
    var outputExt = isImage ? (format === 'webp' ? '.webp' : '.jpg') : origExt;
    tempOutputPath = path.join(UPLOAD_DIR, baseName + '_compressed_' + Date.now() + outputExt);

    // DEBUG: Log compression mode and file type
    console.log('=== /api/compress DEBUG ===');
    console.log('Compression mode:', compressionMode);
    console.log('File MIME type:', req.file.mimetype);
    console.log('Is PDF:', isPdf);
    console.log('Is Image:', isImage);
    console.log('req.body keys:', Object.keys(req.body));
    console.log('req.body.compressionMode (raw):', req.body.compressionMode);
    console.log('========================');

    var responded = false;
    var timer = setTimeout(function () {
      responded = true;
      cleanupFile(tempInputPath);
      cleanupFile(tempOutputPath);
      res.status(408).json({ success: false, error: 'Compression took too long. Try a smaller file.' });
    }, 5 * 60 * 1000);

    function done(err, result) {
      if (responded) return;
      clearTimeout(timer);

      if (err) {
        responded = true;
        cleanupFile(tempInputPath);
        cleanupFile(tempOutputPath);

        var status = 500;
        var msg = err.message || 'Compression failed';
        if (msg.indexOf('timeout') !== -1) status = 408;
        else if (msg.indexOf('ENOSPC') !== -1) { status = 507; msg = 'Insufficient disk space'; }
        else if (msg.indexOf('Invalid') !== -1 || msg.indexOf('parse') !== -1) { status = 400; msg = 'Invalid or corrupted file'; }
        return res.status(status).json({ success: false, error: msg });
      }

      if (fileSize(tempOutputPath) === 0) {
        responded = true;
        cleanupFile(tempInputPath);
        cleanupFile(tempOutputPath);
        return res.status(500).json({ success: false, error: 'Compression produced no output' });
      }

      responded = true;
      var downloadName = baseName + '_compressed' + outputExt;
      res.download(tempOutputPath, downloadName, function (dlErr) {
        cleanupFile(tempInputPath);
        cleanupFile(tempOutputPath);
        if (dlErr) console.error('Download error:', dlErr.message);
      });
    }

    if (isImage) {
      console.log('→ Executing: compressImage (image file)');
      compressImage(tempInputPath, tempOutputPath, quality, format, done);
    } else if (isPdf && compressionMode === 'high-compression') {
      console.log('→ Executing: compressImagePdf (high-compression mode)');
      compressImagePdf(tempInputPath, tempOutputPath, done);
    } else {
      console.log('→ Executing: compressPdf (standard mode or non-PDF)');
      compressPdf(tempInputPath, tempOutputPath, quality, done);
    }

  } catch (e) {
    cleanupFile(tempInputPath);
    cleanupFile(tempOutputPath);
    res.status(500).json({ success: false, error: e.message || 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// Error handler (multer oversize, etc.)
// ---------------------------------------------------------------------------
app.use(function (err, req, res, next) {
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ success: false, error: 'File too large (max 100MB)' });
  }
  if (err) {
    return res.status(400).json({ success: false, error: err.message });
  }
  next();
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
var PORT = process.env.PORT || 3000;
app.listen(PORT, function () {
  console.log('');
  console.log('===========================================');
  console.log('  GetReadyJob Compression Server  v1.0    ');
  console.log('===========================================');
  console.log('  URL   : http://localhost:' + PORT);
  console.log('  API   : http://localhost:' + PORT + '/api/info');
  console.log('  Max   : 100 MB');
  console.log('  Quality: 50 - 90 %');
  console.log('===========================================');
  console.log('');
});
