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

    console.log('✓ compressPdf (standard) completed:');
    console.log('  Original size:', origSize, 'bytes');
    console.log('  Compressed size:', compSize, 'bytes');
    console.log('  Ratio:', reduction > 0 ? ((reduction / origSize) * 100).toFixed(1) : '0', '%');

    callback(null, {
      success: true,
      originalSize: origSize,
      compressedSize: compSize,
      ratio: reduction > 0 ? ((reduction / origSize) * 100).toFixed(1) : '0',
      mode: 'standard',
      note: 'PDF structure optimized'
    });
  }).catch(function (err) {
    console.error('✗ compressPdf error:', err.message);
    callback(new Error('PDF compression failed: ' + err.message));
  });
}

// ---------------------------------------------------------------------------
// PDF compression - High Compression Image-Only mode
// Extracts pages as images, re-encodes with lower quality, rebuilds PDF
// ---------------------------------------------------------------------------
function compressImagePdf(inputPath, outputPath, callback) {
  var execFile = require('child_process').execFile;
  var PDFDocument = require('pdf-lib').PDFDocument;
  var sharp;
  try {
    sharp = require('sharp');
  } catch (e) {
    return callback(new Error('sharp module not available'));
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

  // Create temporary directory for page images
  var tempPageDir = path.join(UPLOAD_DIR, 'pages_' + Date.now());
  try {
    if (!fs.existsSync(tempPageDir)) fs.mkdirSync(tempPageDir, { recursive: true });
  } catch (e) {
    return callback(new Error('Cannot create temp directory: ' + e.message));
  }

  // Step 1: Convert PDF pages to JPEG using ghostscript
  console.log('→ Starting PDF to JPEG conversion using ghostscript...');
  var gsCommand = 'gs';
  var gsArgs = [
    '-dQUIET',
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-sDEVICE=jpeg',
    '-r150',
    '-dJPEGQ=60',
    '-o',
    path.join(tempPageDir, 'page_%d.jpg'),
    inputPath
  ];

  execFile(gsCommand, gsArgs, { maxBuffer: 10 * 1024 * 1024 }, function (gsErr, stdout, stderr) {
    // Cleanup function
    function cleanup() {
      try {
        var files = fs.readdirSync(tempPageDir);
        files.forEach(function (f) { cleanupFile(path.join(tempPageDir, f)); });
        fs.rmdirSync(tempPageDir);
      } catch (e) { /* ignore */ }
    }

    if (gsErr) {
      console.error('✗ Ghostscript conversion failed:', gsErr.message);
      cleanup();
      // Fallback to standard compression
      console.log('→ Falling back to standard PDF compression...');
      return compressPdf(inputPath, outputPath, 75, callback);
    }

    // Step 2: Find generated JPEG files
    var jpegFiles = [];
    try {
      var files = fs.readdirSync(tempPageDir).filter(function (f) { return f.endsWith('.jpg'); });
      jpegFiles = files.sort(function (a, b) {
        var numA = parseInt(a.match(/\d+/)[0], 10);
        var numB = parseInt(b.match(/\d+/)[0], 10);
        return numA - numB;
      }).map(function (f) { return path.join(tempPageDir, f); });
    } catch (e) {
      console.error('✗ Cannot read JPEG files:', e.message);
      cleanup();
      return compressPdf(inputPath, outputPath, 75, callback);
    }

    if (jpegFiles.length === 0) {
      console.error('✗ No JPEG pages generated');
      cleanup();
      return compressPdf(inputPath, outputPath, 75, callback);
    }

    console.log('✓ Generated', jpegFiles.length, 'JPEG pages from PDF');

    // Step 3: Re-compress JPEGs with sharp (quality 65)
    console.log('→ Re-compressing JPEG pages with quality 65...');
    var compressedJpegs = [];
    var processed = 0;
    var errorOccurred = false;

    jpegFiles.forEach(function (jpegPath) {
      sharp(jpegPath)
        .jpeg({ quality: 65, progressive: true })
        .toFile(jpegPath + '.compressed', function (err) {
          processed++;

          if (err && !errorOccurred) {
            errorOccurred = true;
            console.error('✗ Sharp compression error:', err.message);
            cleanup();
            return compressPdf(inputPath, outputPath, 75, callback);
          }

          if (!err) {
            compressedJpegs.push(jpegPath + '.compressed');
          }

          // All files processed
          if (processed === jpegFiles.length && !errorOccurred) {
            rebuildPdfFromImages(compressedJpegs, origSize, tempPageDir, cleanup, callback, outputPath);
          }
        });
    });
  });
}

// Helper to rebuild PDF from compressed image pages
function rebuildPdfFromImages(compressedJpegPaths, origSize, tempPageDir, cleanup, callback, outputPath) {
  var PDFDocument = require('pdf-lib').PDFDocument;

  console.log('→ Rebuilding PDF from', compressedJpegPaths.length, 'compressed images...');

  // Create new PDF document
  PDFDocument.create().then(function (pdfDoc) {
    var loaded = 0;
    var images = [];
    var errors = [];

    // Load all compressed images
    compressedJpegPaths.forEach(function (jpegPath, index) {
      var jpegBytes;
      try {
        jpegBytes = fs.readFileSync(jpegPath);
        images[index] = jpegBytes;
      } catch (e) {
        errors.push('Cannot read ' + jpegPath + ': ' + e.message);
      }
      loaded++;

      // All images loaded, now embed them in PDF
      if (loaded === compressedJpegPaths.length) {
        if (errors.length > 0) {
          console.error('✗ Image loading errors:', errors.join(', '));
          cleanup();
          return callback(new Error('Failed to load compressed images'));
        }

        // Embed images in PDF
        images.forEach(function (imageBytes, idx) {
          if (imageBytes) {
            pdfDoc.embedJpg(imageBytes).then(function (image) {
              var page = pdfDoc.addPage([image.width, image.height]);
              page.drawImage(image, { x: 0, y: 0, width: image.width, height: image.height });
            }).catch(function (err) {
              console.error('✗ Error embedding image', idx, ':', err.message);
            });
          }
        });

        // After all images processed, save PDF
        setTimeout(function () {
          pdfDoc.save().then(function (pdfBytes) {
            if (!pdfBytes || pdfBytes.length === 0) {
              console.error('✗ Rebuilt PDF is empty');
              cleanup();
              return callback(new Error('Rebuilt PDF produced empty output'));
            }

            fs.writeFileSync(outputPath, pdfBytes);
            var compSize = fileSize(outputPath);
            var ratio = ((1 - compSize / origSize) * 100).toFixed(1);

            console.log('✓ compressImagePdf (image re-encoding) completed:');
            console.log('  Original size:', origSize, 'bytes');
            console.log('  Compressed size:', compSize, 'bytes');
            console.log('  Ratio:', ratio, '%');
            console.log('  Pages:', compressedJpegPaths.length);

            cleanup();
            callback(null, {
              success: true,
              originalSize: origSize,
              compressedSize: compSize,
              ratio: ratio,
              mode: 'high-compression',
              note: 'Re-encoded from ' + compressedJpegPaths.length + ' JPEG pages at quality 65'
            });
          }).catch(function (err) {
            console.error('✗ PDF save error:', err.message);
            cleanup();
            callback(new Error('PDF save failed: ' + err.message));
          });
        }, 500);
      }
    });
  }).catch(function (err) {
    console.error('✗ PDF creation error:', err.message);
    cleanup();
    callback(new Error('PDF creation failed: ' + err.message));
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
