'use strict';

var express = require('express');
var multer = require('multer');
var path = require('path');
var fs = require('fs');
var crypto = require('crypto');
var Razorpay = require('razorpay');
var QRCode = require('qrcode');
var razorpayUtils = require('./Utils/razorpay');
var adminAuth = require('./Utils/adminAuth');
var adminRateLimiter = require('./Utils/adminRateLimiter');

var app = express();

var allowedCorsOrigins = [
  'https://getreadyjob.com',
  'https://www.getreadyjob.com',
  'https://jobready-india.onrender.com',
  'http://localhost:3000',
  'http://localhost:5000',
  'http://localhost:8080'
];

function resolveCorsOrigin(origin) {
  if (!origin) {
    return '';
  }
  if (allowedCorsOrigins.indexOf(origin) !== -1) {
    return origin;
  }
  return '';
}

app.use('/api', function (req, res, next) {
  var origin = req.headers && req.headers.origin ? String(req.headers.origin) : '';
  var allowedOrigin = resolveCorsOrigin(origin);

  if (allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else {
    // Allow non-credentialed cross-origin requests for public API usage.
    res.setHeader('Access-Control-Allow-Origin', '*');
  }

  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  next();
});

var adminPlans = [];
var adminPlansNextId = 1;
var planMatrix = {};
var quotaRules = {};
var quotaUsage = {};
var salesTransactions = [];
var pendingOrders = {};
var toolUsageEvents = [];
var userAccounts = [];
var transactionalEmailEvents = [];
var promoCodes = [];
var auditLogs = [];
var platformSettings = {
  maintenanceMode: false,
  announcement: '',
  gatewayKeys: {
    stripeApiKey: '',
    razorpayKeyId: ''
  }
};
var rateLimiterStore = {};
var backupDir = path.join(__dirname, 'backups');
var adminTwoFactorStatePath = process.env.ADMIN_2FA_STATE_FILE || path.join(backupDir, 'admin-2fa-state.json');
var emailTransporter = null;
var emailConfig = {
  host: process.env.SMTP_HOST || '',
  port: parseInt(process.env.SMTP_PORT || '587', 10),
  user: process.env.SMTP_USER || '',
  pass: process.env.SMTP_PASS || '',
  from: process.env.SMTP_FROM || 'hello@getreadyjob.com'
};

function getCanonicalPlanCatalog() {
  return [
    {
      id: 'weekly-pass',
      name: 'Weekly Pass',
      durationDays: 7,
      validFrom: '',
      validTo: '',
      basePriceUsd: 0.99,
      basePriceInr: 79,
      multiplier: 1,
      access: { compression: true, convert: true, merge: true, split: true, extract: true, edit: true },
      isLifetime: false
    },
    {
      id: 'pro-monthly',
      name: 'Pro Monthly',
      durationDays: 30,
      validFrom: '',
      validTo: '',
      basePriceUsd: 2.99,
      basePriceInr: 249,
      multiplier: 1,
      access: { compression: true, convert: true, merge: true, split: true, extract: true, edit: true },
      isLifetime: false
    },
    {
      id: 'lifetime-pro',
      name: 'Lifetime Pro',
      durationDays: 365,
      validFrom: '',
      validTo: '',
      basePriceUsd: 24.99,
      basePriceInr: 1999,
      multiplier: 1,
      access: { compression: true, convert: true, merge: true, split: true, extract: true, edit: true },
      isLifetime: true
    }
  ];
}

function seedDefaultPlans() {
  if (adminPlans.length > 0) {
    adminPlans.forEach(function (plan) {
      if (plan && /shared pool|quota test|shared pool plan|shared pool check/i.test(plan.name || '')) {
        if (plan.id === 'weekly-pass' || plan.id === 'pro-monthly' || plan.id === 'lifetime-pro') {
          return;
        }
      }
    });
    return;
  }

  var catalog = getCanonicalPlanCatalog();
  catalog.forEach(function (plan) {
    adminPlans.push(plan);
    planMatrix[plan.id] = planMatrix[plan.id] || { planId: plan.id, tools: {} };
    quotaRules[plan.id] = quotaRules[plan.id] || [];
    quotaUsage[plan.id] = quotaUsage[plan.id] || { used: 0 };
    if (plan.id === 'weekly-pass') {
      quotaRules[plan.id] = [{ tool: 'global', limit: '50' }];
    } else if (plan.id === 'pro-monthly') {
      quotaRules[plan.id] = [{ tool: 'global', limit: '200' }];
    } else if (plan.id === 'lifetime-pro') {
      quotaRules[plan.id] = [{ tool: 'global', limit: 'unlimited' }];
    }
  });
  adminPlansNextId = 4;
}
var invoiceTaxConfig = {
  domesticGstRate: 0.18,
  foreignGstRate: 0
};

var invoiceSellerProfile = {
  companyName: 'Get Ready Job',
  proprietorName: 'Rajesh Kumar Yadav',
  address: 'RZ 7 Dabri Extension Main, New Delhi 110045, India',
  pan: 'AAQPY2264A',
  sacCode: '998313'
};

function normalizeCountry(country) {
  var normalized = String(country || '').trim().toLowerCase();
  if (!normalized || normalized === 'india' || normalized === 'in') {
    return 'India';
  }
  return String(country || '').trim() || 'International';
}

function isDomesticCountry(country) {
  var normalized = String(country || '').trim().toLowerCase();
  return normalized === 'india' || normalized === 'in';
}

function calculateTaxBreakdown(baseAmount, country) {
  var normalizedCountry = normalizeCountry(country);
  var isDomestic = isDomesticCountry(normalizedCountry);
  var gstRate = isDomestic ? Number(invoiceTaxConfig.domesticGstRate || 0.18) : Number(invoiceTaxConfig.foreignGstRate || 0);
  var taxableAmount = Number(baseAmount || 0);
  var gstAmount = taxableAmount * gstRate;
  var totalAmount = taxableAmount + gstAmount;
  return {
    country: normalizedCountry,
    isDomestic: isDomestic,
    gstRate: gstRate,
    baseAmount: taxableAmount,
    gstAmount: gstAmount,
    totalAmount: totalAmount,
    cgstAmount: isDomestic ? gstAmount / 2 : 0,
    sgstAmount: isDomestic ? gstAmount / 2 : 0,
    igstAmount: isDomestic ? 0 : gstAmount
  };
}

function escapePdfText(text) {
  return String(text || '').replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
}

function buildInvoicePdfBuffer(transaction) {
  var billing = transaction && transaction.billing ? transaction.billing : {};
  var taxBreakdown = transaction && transaction.taxBreakdown ? transaction.taxBreakdown : {};
  var seller = transaction && transaction.seller ? transaction.seller : invoiceSellerProfile;
  var lines = [
    'Get Ready Job (Proprietorship: ' + seller.proprietorName + ')',
    'Transaction ID: ' + transaction.transactionId,
    'Supplier: ' + seller.companyName,
    'Proprietor: ' + seller.proprietorName,
    'PAN: ' + seller.pan,
    'SAC: ' + seller.sacCode,
    'Address: ' + seller.address,
    'Plan: ' + (transaction.planName || transaction.planId || 'Standard'),
    'Customer: ' + (billing.name ? billing.name : 'Guest User'),
    'Company: ' + (billing.company ? billing.company : '-'),
    'Address: ' + (billing.address ? billing.address : '-'),
    'Country: ' + (transaction.country || 'India'),
    'GSTIN: ' + (billing.gstin ? billing.gstin : 'Not provided'),
    'Plan Category: ' + (billing.company ? 'Business' : 'Personal'),
    'Amount: ₹' + Number(transaction.amount || 0).toFixed(2),
    'Tax: ₹' + Number(taxBreakdown.gstAmount || 0).toFixed(2),
    'Total: ₹' + Number(transaction.totalAmount || 0).toFixed(2),
    'Status: ' + (transaction.status || 'paid'),
    'Issued: ' + (transaction.createdAt || new Date().toISOString())
  ];
  var content = '';
  lines.forEach(function (line, index) {
    content += 'BT /F1 12 Tf 50 ' + String(760 - index * 14) + ' Td (' + escapePdfText(line) + ') Tj ET\n';
  });
  var stream = '<< /Length 0 >>\nstream\n' + content + 'endstream';
  var objects = [];
  objects.push('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj');
  objects.push('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj');
  objects.push('3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj');
  objects.push('4 0 obj ' + stream + ' endobj');
  objects.push('5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj');
  var pdf = '%PDF-1.4\n';
  var offsets = [0];
  objects.forEach(function (obj) {
    offsets.push(pdf.length);
    pdf += obj + '\n';
  });
  var xrefOffset = pdf.length;
  pdf += 'xref\n0 ' + String(objects.length + 1) + '\n';
  pdf += '0000000000 65535 f \n';
  for (var i = 1; i <= objects.length; i++) {
    pdf += String(offsets[i]).padStart(10, '0') + ' 00000 n \n';
  }
  pdf += 'trailer\n<< /Size ' + String(objects.length + 1) + ' /Root 1 0 R >>\n';
  pdf += 'startxref\n' + String(xrefOffset) + '\n%%EOF\n';
  return Buffer.from(pdf, 'utf8');
}

function triggerTransactionalEmail(eventType, payload) {
  var event = {
    id: 'email-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    eventType: eventType,
    payload: payload || {},
    createdAt: new Date().toISOString()
  };
  transactionalEmailEvents.push(event);
  console.log('[email-hook]', eventType, payload && payload.email ? payload.email : 'no-recipient');
  return event;
}

function logAuditEvent(actor, action, details) {
  var entry = {
    id: 'audit-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    actor: actor || 'system',
    action: action || 'event',
    details: details || {},
    createdAt: new Date().toISOString()
  };
  auditLogs.push(entry);
  return entry;
}

function getPlatformSettingsSnapshot() {
  return {
    maintenanceMode: Boolean(platformSettings.maintenanceMode),
    announcement: platformSettings.announcement || '',
    gatewayKeys: {
      stripeApiKey: platformSettings.gatewayKeys && platformSettings.gatewayKeys.stripeApiKey ? platformSettings.gatewayKeys.stripeApiKey : '',
      razorpayKeyId: platformSettings.gatewayKeys && platformSettings.gatewayKeys.razorpayKeyId ? platformSettings.gatewayKeys.razorpayKeyId : ''
    }
  };
}

function applyPromoCode(code, amount, currency) {
  var normalizedCode = String(code || '').trim().toUpperCase();
  if (!normalizedCode) {
    return { success: true, applied: false, discountAmount: 0, finalAmount: Number(amount || 0), currency: currency || 'INR' };
  }
  var promo = promoCodes.find(function (item) {
    return String(item.code || '').toUpperCase() === normalizedCode;
  });
  if (!promo) {
    return { success: false, error: 'Promo code not found.' };
  }
  if (promo.validUntil && new Date(promo.validUntil).getTime() < Date.now()) {
    return { success: false, error: 'Promo code expired.' };
  }
  if (promo.usageLimit && Number(promo.usedCount || 0) >= Number(promo.usageLimit)) {
    return { success: false, error: 'Promo code usage limit reached.' };
  }
  var baseAmount = Number(amount || 0);
  var discountAmount = 0;
  if (Number(promo.discountPercent || 0) > 0) {
    discountAmount = Math.round(baseAmount * Number(promo.discountPercent || 0) / 100);
  } else if (Number(promo.discountFlat || 0) > 0) {
    discountAmount = Number(promo.discountFlat || 0);
  }
  var finalAmount = Math.max(0, baseAmount - discountAmount);
  promo.usedCount = Number(promo.usedCount || 0) + 1;
  return { success: true, applied: true, promo: promo, discountAmount: discountAmount, finalAmount: finalAmount, currency: currency || 'INR' };
}

function buildGatewayContext(billing, currency) {
  var country = String(billing && billing.country ? billing.country : 'India').trim();
  var normalizedCountry = country.toLowerCase();
  var effectiveCurrency = String(currency || 'INR').toUpperCase();
  var isDomestic = normalizedCountry === 'india' || normalizedCountry === 'in';
  var provider = 'razorpay';
  if (!isDomestic || effectiveCurrency === 'USD') {
    provider = 'stripe';
  }
  return {
    country: country || 'India',
    isDomestic: isDomestic,
    currency: effectiveCurrency,
    provider: provider,
    taxRate: isDomestic ? 0.18 : 0
  };
}

function resolveTaxBreakdown(baseAmount, billing, currency) {
  var gatewayContext = buildGatewayContext(billing, currency);
  var taxRate = gatewayContext.isDomestic ? 0.18 : 0;
  var taxableAmount = Number(baseAmount || 0);
  var gstAmount = Math.round(taxableAmount * taxRate);
  var totalAmount = taxableAmount + gstAmount;
  return {
    country: gatewayContext.country,
    isDomestic: gatewayContext.isDomestic,
    currency: gatewayContext.currency,
    provider: gatewayContext.provider,
    baseAmount: taxableAmount,
    gstRate: taxRate,
    gstAmount: gstAmount,
    totalAmount: totalAmount,
    cgstAmount: gatewayContext.isDomestic ? Math.round(gstAmount / 2) : 0,
    sgstAmount: gatewayContext.isDomestic ? Math.round(gstAmount / 2) : 0,
    igstAmount: gatewayContext.isDomestic ? 0 : gstAmount
  };
}

function ensureBackupDir() {
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }
}

function triggerBackup(reason) {
  ensureBackupDir();
  var stamp = new Date().toISOString().replace(/[:.]/g, '-');
  var snapshot = {
    generatedAt: new Date().toISOString(),
    reason: reason || 'manual',
    plans: adminPlans,
    quotaRules: quotaRules,
    quotaUsage: quotaUsage,
    transactions: salesTransactions,
    users: userAccounts,
    promos: promoCodes,
    settings: getPlatformSettingsSnapshot()
  };
  var backupPath = path.join(backupDir, 'backup-' + stamp + '.json');
  fs.writeFileSync(backupPath, JSON.stringify(snapshot, null, 2));
  return backupPath;
}

function rateLimitMiddleware(req, res, next) {
  var key = (req.ip || 'unknown') + '|' + (req.originalUrl || '');
  var now = Date.now();
  var bucket = rateLimiterStore[key] || { count: 0, windowStart: now };
  if (now - bucket.windowStart > 60000) {
    bucket = { count: 0, windowStart: now };
  }
  bucket.count += 1;
  rateLimiterStore[key] = bucket;
  var limit = req.path.indexOf('/api/admin') === 0 ? 120 : (req.path.indexOf('/api/checkout') === 0 ? 30 : 60);
  if (bucket.count > limit) {
    return res.status(429).json({ success: false, error: 'Rate limit exceeded. Please try again shortly.' });
  }
  next();
}

function getEmailTransporter() {
  if (emailTransporter) {
    return emailTransporter;
  }
  if (!emailConfig.host || !emailConfig.user || !emailConfig.pass) {
    return null;
  }
  try {
    var nodemailer = require('nodemailer');
    emailTransporter = nodemailer.createTransport({
      host: emailConfig.host,
      port: emailConfig.port || 587,
      secure: Boolean(emailConfig.port === 465),
      auth: { user: emailConfig.user, pass: emailConfig.pass }
    });
    return emailTransporter;
  } catch (e) {
    console.warn('Nodemailer unavailable, email dispatch will be logged only.', e.message);
    return null;
  }
}

function dispatchEmail(message) {
  var transport = getEmailTransporter();
  var payload = Object.assign({
    from: emailConfig.from,
    subject: 'Get Ready Job Notification',
    text: 'Thank you for using Get Ready Job.'
  }, message || {});
  triggerTransactionalEmail(payload.subject, { email: payload.to, type: payload.subject, content: payload.text });
  if (!transport) {
    console.log('[email-fallback]', payload.subject, payload.to);
    return Promise.resolve({ success: true, fallback: true });
  }
  return transport.sendMail(payload).catch(function (err) {
    console.error('Email dispatch failed:', err && err.message ? err.message : err);
    return { success: false, error: err && err.message ? err.message : 'send failed' };
  });
}

function upsertUserAccount(payload) {
  var normalizedEmail = String(payload && payload.email ? payload.email : '').trim().toLowerCase();
  var existing = userAccounts.find(function (item) {
    return normalizedEmail && item.email && item.email.toLowerCase() === normalizedEmail;
  });
  var user = existing || {
    id: 'user-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    email: normalizedEmail,
    name: payload && payload.name ? payload.name : '',
    company: payload && payload.company ? payload.company : '',
    mobile: payload && payload.mobile ? payload.mobile : '',
    billingCountry: payload && payload.country ? payload.country : 'India',
    gstin: payload && payload.gstin ? payload.gstin : '',
    planId: payload && payload.planId ? payload.planId : '',
    planName: payload && payload.planName ? payload.planName : '',
    planStatus: payload && payload.planStatus ? payload.planStatus : 'active',
    accessExpiresAt: payload && payload.accessExpiresAt ? payload.accessExpiresAt : null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  if (!existing) {
    userAccounts.push(user);
  }
  if (payload) {
    user.name = payload.name || user.name;
    user.company = payload.company || user.company;
    user.mobile = payload.mobile || user.mobile;
    user.billingCountry = payload.country || user.billingCountry || 'India';
    user.gstin = payload.gstin || user.gstin;
    user.planId = payload.planId || user.planId;
    user.planName = payload.planName || user.planName;
    user.planStatus = payload.planStatus || user.planStatus;
    user.accessExpiresAt = payload.accessExpiresAt || user.accessExpiresAt;
    user.updatedAt = new Date().toISOString();
  }
  return user;
}

function getUserPlanStatus(user) {
  if (!user) return 'inactive';
  if (user.planStatus === 'revoked') return 'revoked';
  if (!user.accessExpiresAt) return user.planStatus || 'active';
  return new Date(user.accessExpiresAt).getTime() <= Date.now() ? 'expired' : (user.planStatus || 'active');
}

function recordToolUsageEvent(planId, tool, metadata) {
  var plan = getPlanById(planId);
  var isPaid = Boolean(planId && plan);
  toolUsageEvents.push({
    id: 'usage-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    planId: planId || null,
    planName: plan ? plan.name : 'Free',
    tool: tool || 'compression',
    userType: isPaid ? 'paid' : 'free',
    createdAt: new Date().toISOString(),
    metadata: metadata || {}
  });
}

function filterAnalyticsByRange(events, range, fromDate, toDate) {
  var now = new Date();
  var start = null;
  var end = null;
  if (range === 'custom' && fromDate) {
    start = new Date(fromDate);
  } else if (range === 'this-week') {
    var day = now.getDay();
    var diff = day === 0 ? -6 : 1 - day;
    start = new Date(now);
    start.setDate(now.getDate() + diff);
    start.setHours(0, 0, 0, 0);
  } else if (range === 'this-month') {
    start = new Date(now.getFullYear(), now.getMonth(), 1);
  } else if (range === 'this-year') {
    start = new Date(now.getFullYear(), 0, 1);
  } else {
    start = new Date(now.getFullYear(), now.getMonth(), 1);
  }
  if (range === 'custom' && toDate) {
    end = new Date(toDate);
    end.setHours(23, 59, 59, 999);
  }
  return (events || []).filter(function (item) {
    var ts = new Date(item.createdAt || item.paidAt || item.timestamp || item.updatedAt || new Date());
    if (start && ts < start) return false;
    if (end && ts > end) return false;
    return true;
  });
}

function getAnalyticsSales(range, fromDate, toDate) {
  var filtered = filterAnalyticsByRange(salesTransactions, range, fromDate, toDate);
  var breakdown = [];
  var summary = { transactions: filtered.length, revenue: 0, plans: {}, currencies: {} };
  filtered.forEach(function (item) {
    summary.revenue += Number(item.totalAmount || 0);
    summary.plans[item.planName || item.planId || 'Unknown'] = (summary.plans[item.planName || item.planId || 'Unknown'] || 0) + 1;
    summary.currencies[item.currency || 'INR'] = (summary.currencies[item.currency || 'INR'] || 0) + Number(item.totalAmount || 0);
    breakdown.push({
      planName: item.planName || item.planId || 'Unknown',
      currency: item.currency || 'INR',
      transactions: 1,
      revenue: Number(item.totalAmount || 0),
      date: item.createdAt || item.paidAt || item.timestamp || ''
    });
  });
  return {
    range: range,
    summary: summary,
    breakdown: breakdown
  };
}

function getAnalyticsTools(range, fromDate, toDate) {
  var filtered = filterAnalyticsByRange(toolUsageEvents, range, fromDate, toDate);
  var grouped = {};
  filtered.forEach(function (item) {
    var key = item.tool || 'unknown';
    grouped[key] = grouped[key] || { tool: key, free: 0, paid: 0 };
    if (item.userType === 'paid') grouped[key].paid += 1; else grouped[key].free += 1;
  });
  return {
    range: range,
    summary: filtered.length,
    leaderboard: Object.keys(grouped).map(function (key) {
      return grouped[key];
    }).sort(function (a, b) { return (b.paid + b.free) - (a.paid + a.free); })
  };
}

function parseBooleanEnv(value) {
  var normalized = String(value || '').trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on';
}

function normalizeRecoveryCode(code) {
  return String(code || '').trim().toUpperCase();
}

function hashRecoveryCode(code) {
  return crypto.createHash('sha256').update(normalizeRecoveryCode(code)).digest('hex');
}

function timingSafeStringEqual(a, b) {
  var aBuf = Buffer.from(String(a || ''), 'utf8');
  var bBuf = Buffer.from(String(b || ''), 'utf8');
  if (aBuf.length !== bBuf.length) {
    return false;
  }
  return crypto.timingSafeEqual(aBuf, bBuf);
}

function parseBase32Secret(secret) {
  var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var normalized = String(secret || '').replace(/=+/g, '').replace(/\s+/g, '').toUpperCase();
  var bits = 0;
  var value = 0;
  var out = [];

  for (var i = 0; i < normalized.length; i++) {
    var idx = alphabet.indexOf(normalized[i]);
    if (idx < 0) {
      continue;
    }
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }

  return Buffer.from(out);
}

function generateBase32Secret(byteLength) {
  var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var bytes = crypto.randomBytes(byteLength || 20);
  var output = '';
  var bits = 0;
  var value = 0;

  for (var i = 0; i < bytes.length; i++) {
    value = (value << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      output += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }

  if (bits > 0) {
    output += alphabet[(value << (5 - bits)) & 31];
  }

  return output;
}

function buildAdminOtpAuthUri(secret) {
  var issuer = 'GETREADYJOB';
  var account = ADMIN_CONFIG.email;
  return 'otpauth://totp/' + encodeURIComponent(issuer + ':' + account) +
    '?secret=' + encodeURIComponent(secret) +
    '&issuer=' + encodeURIComponent(issuer) +
    '&period=30&digits=6&algorithm=SHA1';
}

function generateTotp(secret, timeStep) {
  var key = parseBase32Secret(secret);
  if (!key.length) {
    return '';
  }

  var counter = Buffer.alloc(8);
  var value = Number(timeStep || 0);
  for (var i = 7; i >= 0; i--) {
    counter[i] = value & 0xff;
    value = Math.floor(value / 256);
  }

  var digest = crypto.createHmac('sha1', key).update(counter).digest();
  var offset = digest[digest.length - 1] & 0x0f;
  var binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);

  var otp = binary % 1000000;
  return String(otp).padStart(6, '0');
}

function verifyTotpCode(secret, code) {
  var normalizedCode = String(code || '').trim();
  if (!/^\d{6}$/.test(normalizedCode)) {
    return false;
  }

  var currentTimeStep = Math.floor(Date.now() / 1000 / 30);
  for (var offset = -1; offset <= 1; offset++) {
    if (generateTotp(secret, currentTimeStep + offset) === normalizedCode) {
      return true;
    }
  }

  return false;
}

function splitCsvValues(value) {
  return String(value || '')
    .split(',')
    .map(function (entry) { return entry.trim(); })
    .filter(function (entry) { return entry.length > 0; });
}

function normalizeEmailValue(value) {
  return String(value || '').trim().toLowerCase();
}

function readAdminTwoFactorState() {
  try {
    if (!fs.existsSync(adminTwoFactorStatePath)) {
      return null;
    }
    var raw = fs.readFileSync(adminTwoFactorStatePath, 'utf8');
    var parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return parsed;
  } catch (err) {
    console.error('Failed to read admin 2FA state:', err.message || err);
    return null;
  }
}

function persistAdminTwoFactorState(reason) {
  try {
    ensureBackupDir();
    var payload = {
      enabled: Boolean(ADMIN_CONFIG && ADMIN_CONFIG.twoFactorEnabled),
      secret: String((ADMIN_CONFIG && ADMIN_CONFIG.twoFactorSecret) || '').trim(),
      recoveryHashes: Array.isArray(ADMIN_TWO_FACTOR_RECOVERY_HASHES)
        ? ADMIN_TWO_FACTOR_RECOVERY_HASHES
        : [],
      updatedAt: new Date().toISOString(),
      reason: reason || 'runtime-update'
    };
    var tempPath = adminTwoFactorStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(payload, null, 2), 'utf8');
    fs.renameSync(tempPath, adminTwoFactorStatePath);
  } catch (err) {
    console.error('Failed to persist admin 2FA state:', err.message || err);
  }
}

var adminPrimaryEmail = normalizeEmailValue(process.env.ADMIN_EMAIL || 'admin@getreadyjob.com');
var defaultAllowedAdminEmails = 'admin@getreadyjob.com,hello@getreadyjob.com,rajesh.khola@gmail.com';
var adminAllowedEmails = splitCsvValues(
  process.env.ADMIN_ALLOWED_EMAILS || process.env.ADMIN_EMAILS || defaultAllowedAdminEmails
)
  .map(normalizeEmailValue)
  .filter(function (entry) { return entry.length > 0; });

if (adminAllowedEmails.indexOf(adminPrimaryEmail) === -1) {
  adminAllowedEmails.push(adminPrimaryEmail);
}

var ADMIN_CONFIG = {
  email: adminPrimaryEmail,
  allowedEmails: adminAllowedEmails,
  passwordHash: process.env.ADMIN_PASSWORD_HASH || adminAuth.hashPassword(process.env.ADMIN_PASSWORD || 'Admin@2026!'),
  jwtSecret: process.env.ADMIN_JWT_SECRET || 'dev-secret',
  tokenExpiryMinutes: parseInt(process.env.ADMIN_TOKEN_EXPIRY_MINUTES || '60', 10),
  rateLimitMaxAttempts: parseInt(process.env.ADMIN_LOGIN_RATE_LIMIT_MAX || '5', 10),
  rateLimitWindowMs: parseInt(process.env.ADMIN_LOGIN_RATE_LIMIT_WINDOW_MS || '900000', 10),
  twoFactorEnabled: parseBooleanEnv(process.env.ADMIN_2FA_ENABLED || (process.env.ADMIN_2FA_SECRET ? 'true' : 'false')),
  twoFactorSecret: String(process.env.ADMIN_2FA_SECRET || '').trim(),
  twoFactorChallengeTtlSec: parseInt(process.env.ADMIN_2FA_CHALLENGE_TTL_SEC || '300', 10),
  twoFactorMaxAttempts: parseInt(process.env.ADMIN_2FA_MAX_ATTEMPTS || '6', 10)
};

var persistedAdminTwoFactorState = readAdminTwoFactorState();
if (persistedAdminTwoFactorState) {
  if (persistedAdminTwoFactorState.secret) {
    ADMIN_CONFIG.twoFactorSecret = String(persistedAdminTwoFactorState.secret).trim();
  }
  if (persistedAdminTwoFactorState.enabled === true) {
    ADMIN_CONFIG.twoFactorEnabled = true;
  }
}

if (!ADMIN_CONFIG.twoFactorSecret) {
  ADMIN_CONFIG.twoFactorSecret = generateBase32Secret(20);
  persistAdminTwoFactorState('generated-initial-secret');
}

var ADMIN_TWO_FACTOR_RECOVERY_HASHES = splitCsvValues(process.env.ADMIN_2FA_RECOVERY_HASHES);
if (ADMIN_TWO_FACTOR_RECOVERY_HASHES.length === 0) {
  ADMIN_TWO_FACTOR_RECOVERY_HASHES = splitCsvValues(process.env.ADMIN_2FA_RECOVERY_CODES)
    .map(function (code) { return hashRecoveryCode(code); });
}

if (persistedAdminTwoFactorState && Array.isArray(persistedAdminTwoFactorState.recoveryHashes) && persistedAdminTwoFactorState.recoveryHashes.length > 0) {
  ADMIN_TWO_FACTOR_RECOVERY_HASHES = persistedAdminTwoFactorState.recoveryHashes.map(function (entry) {
    return String(entry || '').trim();
  }).filter(function (entry) {
    return entry.length > 0;
  });
}

if (ADMIN_CONFIG.twoFactorSecret) {
  persistAdminTwoFactorState('startup-sync');
}

var adminUsedRecoveryCodes = {};
var adminTwoFactorChallenges = {};
var adminSetupQrIssued = false;

function cleanupExpiredTwoFactorChallenges() {
  var now = Date.now();
  Object.keys(adminTwoFactorChallenges).forEach(function (token) {
    var challenge = adminTwoFactorChallenges[token];
    if (!challenge || challenge.expiresAt <= now) {
      delete adminTwoFactorChallenges[token];
    }
  });
}

function createTwoFactorChallenge(email, isSetup) {
  cleanupExpiredTwoFactorChallenges();
  var token = crypto.randomBytes(24).toString('hex');
  adminTwoFactorChallenges[token] = {
    email: String(email || '').toLowerCase(),
    createdAt: Date.now(),
    expiresAt: Date.now() + (Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec) * 1000),
    attempts: 0,
    isSetup: isSetup === true
  };
  return token;
}

function consumeValidTwoFactorChallenge(challengeToken) {
  cleanupExpiredTwoFactorChallenges();
  var token = String(challengeToken || '').trim();
  if (!token) {
    return null;
  }
  return adminTwoFactorChallenges[token] || null;
}

function markRecoveryCodeAsUsed(hash) {
  if (!hash) {
    return;
  }
  adminUsedRecoveryCodes[hash] = Date.now();
}

function verifyRecoveryCode(code) {
  var normalized = normalizeRecoveryCode(code);
  if (!normalized) {
    return false;
  }

  var candidateHash = hashRecoveryCode(normalized);
  if (adminUsedRecoveryCodes[candidateHash]) {
    return false;
  }

  for (var i = 0; i < ADMIN_TWO_FACTOR_RECOVERY_HASHES.length; i++) {
    if (timingSafeStringEqual(candidateHash, ADMIN_TWO_FACTOR_RECOVERY_HASHES[i])) {
      markRecoveryCodeAsUsed(candidateHash);
      return true;
    }
  }

  return false;
}

function loadEnvFile() {
  var envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) {
    return;
  }

  var contents = fs.readFileSync(envPath, 'utf8');
  contents.split(/\r?\n/).forEach(function (line) {
    var trimmed = line.trim();
    if (!trimmed || trimmed.indexOf('#') === 0) {
      return;
    }

    var separatorIndex = trimmed.indexOf('=');
    if (separatorIndex === -1) {
      return;
    }

    var key = trimmed.substring(0, separatorIndex).trim();
    var value = trimmed.substring(separatorIndex + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value.replace(/^['"]|['"]$/g, '');
    }
  });
}

loadEnvFile();

var razorpay = null;
if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
  razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET
  });
}

var BLOCKED_DOWNLOAD_PATHS = new Set([
  '/downloads/bank_api_packet_v1_1.md',
  '/downloads/ads_api_packet_v1_1.md',
  '/downloads/bank_ads_api_packet_v1_1.html',
  '/downloads/bank_ads_api_packet_v1_1.pdf'
]);

// ---------------------------------------------------------------------------
// Ensure temp_uploads directory exists
// ---------------------------------------------------------------------------
var UPLOAD_DIR = path.join(__dirname, 'temp_uploads');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

function ensureUploadDirectory() {
  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }
  return UPLOAD_DIR;
}

function persistUploadedFile(file, req) {
  try {
    ensureUploadDirectory();
    var targetName = 'upload_' + Date.now() + '_' + crypto.randomBytes(4).toString('hex') + path.extname(file.originalname || '');
    var targetPath = path.join(UPLOAD_DIR, targetName);
    fs.copyFileSync(file.path, targetPath);
    if (file.path && file.path !== targetPath) {
      cleanupFile(file.path);
    }
    return targetPath;
  } catch (e) {
    return file && file.path ? file.path : null;
  }
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
app.use(function (req, res, next) {
  var requestedPath = (req.path || '').toLowerCase();
  if (BLOCKED_DOWNLOAD_PATHS.has(requestedPath)) {
    return res.status(410).json({
      success: false,
      error: 'Requested file is no longer publicly available'
    });
  }
  next();
});

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

app.get('/healthz', function (req, res) {
  ensureUploadDirectory();
  res.json({
    success: true,
    status: 'ok',
    uploadDir: UPLOAD_DIR,
    uploadDirExists: fs.existsSync(UPLOAD_DIR)
  });
});
app.use('/api/admin', rateLimitMiddleware);
app.use('/api/checkout', rateLimitMiddleware);
app.use('/api/user/invoice', rateLimitMiddleware);
app.use('/api/checkout', function (req, res, next) {
  if (platformSettings.maintenanceMode) {
    return res.status(503).json({ success: false, error: 'Platform is in maintenance mode.' });
  }
  next();
});

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

function getPlanById(planId) {
  seedDefaultPlans();
  if (!planId) return null;
  for (var i = 0; i < adminPlans.length; i++) {
    if (String(adminPlans[i].id) === String(planId)) {
      return adminPlans[i];
    }
  }
  return null;
}

function isLifetimePlan(plan) {
  if (!plan) return false;
  if (plan.isLifetime === true) return true;
  return String(plan.name || '').toLowerCase().indexOf('lifetime') !== -1;
}

function getDefaultToolNames() {
  return ['compression', 'convert', 'merge', 'split', 'extract', 'edit'];
}

function getPlanDisplayName(planId) {
  var plan = getPlanById(planId);
  return plan && plan.name ? plan.name : '';
}

function normalizeQuotaRules(planId, rules) {
  var normalized = [];
  var plan = getPlanById(planId);
  if (isLifetimePlan(plan)) {
    normalized.push({ tool: 'global', limit: 'unlimited' });
    return normalized;
  }

  var existingRules = Array.isArray(rules) ? rules : [];
  var sharedRule = existingRules.find(function (item) {
    return item && ['global', 'shared', 'all', 'quota'].indexOf(String(item.tool || '').toLowerCase()) !== -1;
  });
  var fallbackRule = existingRules.find(function (item) {
    return item && item.limit !== undefined && item.limit !== null && item.limit !== '';
  });
  var rawValue = sharedRule ? sharedRule.limit : (fallbackRule ? fallbackRule.limit : '');
  var normalizedValue = rawValue === undefined || rawValue === null || rawValue === '' ? 'unlimited' : String(rawValue);
  normalized.push({ tool: 'global', limit: normalizedValue });
  return normalized;
}

function getQuotaRule(planId) {
  var rules = quotaRules[planId] || [];
  return rules.find(function (item) {
    return item && item.tool === 'global';
  }) || null;
}

function getQuotaDisplayValue(planId, fallbackValue) {
  seedDefaultPlans();
  var normalizedPlanId = String(planId || '').trim();
  if (!normalizedPlanId) {
    return fallbackValue;
  }

  var existingRules = (quotaRules[normalizedPlanId] || []).filter(function (item) {
    return item && typeof item === 'object';
  });
  var rule = existingRules.find(function (item) {
    return item.tool === 'global';
  }) || existingRules[0] || null;

  if (rule && rule.limit) {
    var limitText = String(rule.limit).trim();
    if (limitText.toLowerCase() === 'unlimited') {
      return 'Unlimited';
    }
    return limitText;
  }

  var quotaState = getQuotaState(normalizedPlanId);
  if (quotaState && quotaState.limit !== null && quotaState.limit !== undefined) {
    return quotaState.limit === null || quotaState.limit === 'null' ? 'Unlimited' : String(quotaState.limit);
  }

  return fallbackValue;
}

function getPublicPlanQuotaComparison() {
  seedDefaultPlans();
  if (!quotaRules.free) {
    quotaRules.free = [{ tool: 'global', limit: '2' }];
  }
  if (!quotaRules.yearly) {
    quotaRules.yearly = [{ tool: 'global', limit: '1000' }];
  }

  return {
    rowLabel: 'User Quota',
    values: [
      { label: 'FREE', value: getQuotaDisplayValue('free', '2') },
      { label: '7 DAYS', value: getQuotaDisplayValue('weekly-pass', '50') },
      { label: 'MONTHLY', value: getQuotaDisplayValue('pro-monthly', '200') },
      { label: 'YEARLY', value: getQuotaDisplayValue('yearly', '1000') },
      { label: 'LIFETIME', value: getQuotaDisplayValue('lifetime-pro', 'Unlimited') }
    ]
  };
}

function getQuotaState(planId) {
  var plan = getPlanById(planId);
  if (!planId || !plan || isLifetimePlan(plan)) {
    return { limit: null, used: 0, remainingQuota: null, exhausted: false, unlimited: true };
  }

  var rule = getQuotaRule(planId);
  var used = quotaUsage[planId] && quotaUsage[planId].used !== undefined ? Number(quotaUsage[planId].used) : 0;
  var limit = rule && rule.limit !== 'unlimited' && rule.limit !== '' ? Number(rule.limit) : null;
  var remainingQuota = limit === null ? null : Math.max(limit - used, 0);
  var exhausted = limit !== null && remainingQuota <= 0;
  return { limit: limit, used: used, remainingQuota: remainingQuota, exhausted: exhausted, unlimited: limit === null };
}

function consumePlanQuota(planId, tool, success) {
  var plan = getPlanById(planId);
  if (!planId || !tool || !success || isLifetimePlan(plan)) {
    return { consumed: false, exhausted: false, rule: null, used: 0, remainingQuota: null, limit: null, planName: getPlanDisplayName(planId), planId: planId };
  }

  var state = getQuotaState(planId);
  if (!quotaUsage[planId]) {
    quotaUsage[planId] = { used: 0 };
  }
  if (state.unlimited || state.limit === null) {
    return { consumed: false, exhausted: false, rule: getQuotaRule(planId), used: state.used, remainingQuota: null, limit: null, planName: getPlanDisplayName(planId), planId: planId };
  }

  quotaUsage[planId].used = Number(quotaUsage[planId].used || 0) + 1;
  state = getQuotaState(planId);
  return { consumed: true, exhausted: state.exhausted, rule: getQuotaRule(planId), used: state.used, remainingQuota: state.remainingQuota, limit: state.limit, planName: getPlanDisplayName(planId), planId: planId };
}

function enforceQuotaMiddleware(req, res, next) {
  var planId = req.body && req.body.planId ? req.body.planId : (req.query && req.query.planId ? req.query.planId : '');
  var tool = req.body && req.body.tool ? req.body.tool : (req.query && req.query.tool ? req.query.tool : 'compression');
  var plan = getPlanById(planId);
  if (!planId || !tool || isLifetimePlan(plan)) {
    req.quotaContext = { planId: planId, tool: tool, remainingQuota: null, limit: null, used: 0, planName: getPlanDisplayName(planId) };
    return next();
  }

  var state = getQuotaState(planId);
  if (state.exhausted) {
    res.set('X-Quota-Remaining', String(state.remainingQuota));
    res.set('X-Quota-Used', String(state.used));
    res.set('X-Quota-Limit', String(state.limit));
    res.set('X-Quota-Exhausted', 'true');
    res.set('X-Quota-Plan-Id', String(planId));
    res.set('X-Quota-Plan-Name', String(getPlanDisplayName(planId)));
    return res.status(403).json({ success: false, error: 'Quota exhausted', quotaExhausted: true, planId: planId, tool: tool, used: state.used, limit: state.limit, remainingQuota: state.remainingQuota, planName: getPlanDisplayName(planId) });
  }

  req.quotaContext = { planId: planId, tool: tool, remainingQuota: state.remainingQuota, limit: state.limit, used: state.used, planName: getPlanDisplayName(planId) };
  next();
}

function resolveGhostscriptBinary() {
  var candidates = [];

  if (process.env.GHOSTSCRIPT_BIN) {
    candidates.push(process.env.GHOSTSCRIPT_BIN);
  }

  if (process.platform === 'win32') {
    candidates.push(
      'C:\\Program Files\\gs\\gs10.04.0\\bin\\gswin64c.exe',
      'C:\\Program Files\\gs\\gs10.03.1\\bin\\gswin64c.exe',
      'C:\\Program Files\\gs\\gs10.02.1\\bin\\gswin64c.exe',
      'C:\\Program Files\\gs\\gs9.56.1\\bin\\gswin64c.exe',
      'C:\\Program Files\\gs\\gs9.55.0\\bin\\gswin64c.exe',
      'gswin64c',
      'gswin32c'
    );
  }

  candidates.push('gs');

  for (var i = 0; i < candidates.length; i++) {
    var candidate = candidates[i];
    if (!candidate) continue;
    if (candidate.indexOf(path.sep) !== -1 || candidate.indexOf(':') !== -1) {
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    } else {
      return candidate;
    }
  }

  return 'gs';
}

function compressPdfWithGhostscript(inputPath, outputPath, callback) {
  var execFile = require('child_process').execFile;
  var gsBin = resolveGhostscriptBinary();
  var gsArgs = [
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-dQUIET',
    '-sDEVICE=pdfwrite',
    '-dCompatibilityLevel=1.4',
    '-dDetectDuplicateImages=true',
    '-dCompressFonts=true',
    '-dDownsampleColorImages=true',
    '-dDownsampleGrayImages=true',
    '-dDownsampleMonoImages=true',
    '-dColorImageDownsampleType=/Bicubic',
    '-dGrayImageDownsampleType=/Bicubic',
    '-dMonoImageDownsampleType=/Subsample',
    '-dColorImageResolution=144',
    '-dGrayImageResolution=144',
    '-dMonoImageResolution=200',
    '-dAutoRotatePages=/None',
    '-dAutoFilterColorImages=false',
    '-dAutoFilterGrayImages=false',
    '-dColorImageFilter=/DCTEncode',
    '-dGrayImageFilter=/DCTEncode',
    '-dJPEGQ=58',
    '-sOutputFile=' + outputPath,
    inputPath
  ];

  execFile(gsBin, gsArgs, { maxBuffer: 20 * 1024 * 1024 }, function (err) {
    if (err) {
      return callback(new Error('Ghostscript compression failed: ' + err.message));
    }
    if (fileSize(outputPath) === 0) {
      return callback(new Error('Ghostscript compression produced empty output'));
    }
    callback(null);
  });
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

    if (compSize >= origSize) {
      var gsOutputPath = outputPath + '.gs.pdf';
      return compressPdfWithGhostscript(inputPath, gsOutputPath, function (gsErr) {
        if (!gsErr && fileSize(gsOutputPath) > 0 && fileSize(gsOutputPath) < compSize) {
          try {
            fs.copyFileSync(gsOutputPath, outputPath);
          } catch (copyErr) {
            cleanupFile(gsOutputPath);
            return callback(new Error('Cannot persist Ghostscript output: ' + copyErr.message));
          }
          compSize = fileSize(outputPath);
        }
        cleanupFile(gsOutputPath);

        var reductionAfterGs = origSize - compSize;
        console.log('✓ compressPdf (standard+fallback) completed:');
        console.log('  Original size:', origSize, 'bytes');
        console.log('  Compressed size:', compSize, 'bytes');
        console.log('  Ratio:', reductionAfterGs > 0 ? ((reductionAfterGs / origSize) * 100).toFixed(1) : '0', '%');

        callback(null, {
          success: true,
          originalSize: origSize,
          compressedSize: compSize,
          ratio: reductionAfterGs > 0 ? ((reductionAfterGs / origSize) * 100).toFixed(1) : '0',
          mode: reductionAfterGs > 0 ? 'standard+downsample' : 'standard',
          note: reductionAfterGs > 0
            ? 'Applied Ghostscript downsampling fallback after structure optimization'
            : 'PDF structure optimized'
        });
      });
    }

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
  var gsCommand = resolveGhostscriptBinary();
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

app.get(['/admin', '/admin/'], function (req, res) {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

app.get(['/admin/login', '/admin/login/'], function (req, res) {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

function requireAdmin(req, res, next) {
  var authHeader = req.headers.authorization || '';
  var token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  var payload = adminAuth.verifyAdminToken(token, ADMIN_CONFIG.jwtSecret);

  if (!payload || payload.role !== 'admin') {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  var now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp <= now) {
    return res.status(401).json({ success: false, error: 'Token expired' });
  }

  req.admin = payload;
  next();
}

app.post(['/api/admin/login', '/admin/login', '/admin/login/'], async function (req, res) {
  var email = normalizeEmailValue(req.body.email);
  var password = req.body.password || '';

  if (!email || !password) {
    return res.status(400).json({ success: false, error: 'Email and password are required.' });
  }

  var rateLimitKey = 'admin-login:' + email;
  if (!adminRateLimiter.isAllowed(rateLimitKey, ADMIN_CONFIG.rateLimitMaxAttempts, ADMIN_CONFIG.rateLimitWindowMs)) {
    return res.status(429).json({ success: false, error: 'Too many login attempts. Please try again later.' });
  }

  if (ADMIN_CONFIG.allowedEmails.indexOf(email) === -1) {
    return res.status(401).json({ success: false, error: 'Invalid admin credentials.' });
  }

  if (!adminAuth.verifyPassword(password, ADMIN_CONFIG.passwordHash)) {
    return res.status(401).json({ success: false, error: 'Invalid admin credentials.' });
  }

  var isTwoFactorSetupPending = !ADMIN_CONFIG.twoFactorEnabled && Boolean(ADMIN_CONFIG.twoFactorSecret);

  if (isTwoFactorSetupPending) {
    var setupChallengeToken = createTwoFactorChallenge(email, true);

    if (!adminSetupQrIssued) {
      var qrCodeUrl = await QRCode.toDataURL(buildAdminOtpAuthUri(ADMIN_CONFIG.twoFactorSecret), {
        errorCorrectionLevel: 'M',
        margin: 2,
        width: 240
      });
      adminSetupQrIssued = true;
      return res.json({
        success: true,
        requires2fa: true,
        requireOTP: true,
        showQR: true,
        qrCodeUrl: qrCodeUrl,
        challengeToken: setupChallengeToken,
        challengeExpiresInSec: Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec)
      });
    }

    return res.json({
      success: true,
      requires2fa: true,
      requireOTP: true,
      showQR: false,
      challengeToken: setupChallengeToken,
      challengeExpiresInSec: Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec),
      message: 'Complete setup with a 6-digit code from your paired authenticator app.'
    });
  }

  if (ADMIN_CONFIG.twoFactorEnabled && ADMIN_CONFIG.twoFactorSecret) {
    var challengeToken = createTwoFactorChallenge(email, false);
    return res.json({
      success: true,
      requires2fa: true,
      requireOTP: true,
      showQR: false,
      challengeToken: challengeToken,
      challengeExpiresInSec: Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec),
      methods: {
        totp: true,
        recovery: ADMIN_TWO_FACTOR_RECOVERY_HASHES.length > 0
      }
    });
  }

  return res.status(503).json({
    success: false,
    error: '2FA is not configured. Set ADMIN_2FA_SECRET before admin login.'
  });
});

app.post('/api/admin/2fa/verify', function (req, res) {
  var challengeToken = req.body && req.body.challengeToken ? String(req.body.challengeToken).trim() : '';
  var code = req.body && req.body.code ? String(req.body.code).trim() : '';
  var recoveryCode = req.body && req.body.recoveryCode ? String(req.body.recoveryCode).trim() : '';

  var challenge = consumeValidTwoFactorChallenge(challengeToken);
  if (!challenge) {
    return res.status(401).json({ success: false, error: '2FA challenge is missing or expired. Please sign in again.' });
  }

  if (challenge.attempts >= Math.max(1, ADMIN_CONFIG.twoFactorMaxAttempts)) {
    delete adminTwoFactorChallenges[challengeToken];
    return res.status(429).json({ success: false, error: 'Too many invalid 2FA attempts. Please sign in again.' });
  }

  var isTotpValid = ADMIN_CONFIG.twoFactorSecret && verifyTotpCode(ADMIN_CONFIG.twoFactorSecret, code);
  var isRecoveryValid = !isTotpValid && recoveryCode ? verifyRecoveryCode(recoveryCode) : false;

  if (!isTotpValid && !isRecoveryValid) {
    challenge.attempts += 1;
    return res.status(401).json({ success: false, error: 'Invalid authenticator or recovery code.' });
  }

  delete adminTwoFactorChallenges[challengeToken];

  if (challenge.isSetup) {
    ADMIN_CONFIG.twoFactorEnabled = true;
    persistAdminTwoFactorState('setup-verified');
  }

  var expiry = Math.floor(Date.now() / 1000) + ADMIN_CONFIG.tokenExpiryMinutes * 60;
  var token = adminAuth.createAdminToken({ email: challenge.email, role: 'admin', exp: expiry }, ADMIN_CONFIG.jwtSecret);
  return res.json({ success: true, token: token, role: 'admin', expiresAt: expiry });
});

app.get('/admin/me', requireAdmin, function (req, res) {
  res.json({ success: true, admin: req.admin });
});

app.get('/admin/dashboard', requireAdmin, function (req, res) {
  res.json({ success: true, message: 'Admin dashboard ready', admin: req.admin });
});

app.get('/api/admin/plans', requireAdmin, function (req, res) {
  seedDefaultPlans();
  res.json({ success: true, plans: adminPlans });
});

app.post('/api/admin/plans', requireAdmin, function (req, res) {
  seedDefaultPlans();
  var plan = req.body || {};
  if (!plan.name || !plan.durationDays || !plan.basePriceUsd || !plan.basePriceInr) {
    return res.status(400).json({ success: false, error: 'Please provide plan name, duration, and pricing.' });
  }

  var lifetimeRequested = Boolean(plan.isLifetime === true || /lifetime/i.test(String(plan.name || '')));
  var maxLifetimeDays = 3650;
  if (lifetimeRequested && Number(plan.durationDays || 0) > maxLifetimeDays) {
    return res.status(400).json({ success: false, error: 'Lifetime plans are capped at 10 years (3650 days).' });
  }

  var newPlan = {
    id: String(adminPlansNextId++),
    name: String(plan.name).trim(),
    durationDays: Number(plan.durationDays),
    validFrom: plan.validFrom || '',
    validTo: plan.validTo || '',
    basePriceUsd: Number(plan.basePriceUsd),
    basePriceInr: Number(plan.basePriceInr),
    multiplier: Number(plan.multiplier || 1),
    access: plan.access || {},
    isLifetime: lifetimeRequested
  };

  adminPlans.push(newPlan);
  planMatrix[newPlan.id] = planMatrix[newPlan.id] || {
    planId: newPlan.id,
    tools: {}
  };
  quotaRules[newPlan.id] = quotaRules[newPlan.id] || [];
  quotaUsage[newPlan.id] = quotaUsage[newPlan.id] || {};
  if (newPlan.isLifetime) {
    quotaRules[newPlan.id] = [{ tool: 'global', limit: 'unlimited' }];
  }
  res.json({ success: true, plan: newPlan, plans: adminPlans });
});

app.delete('/api/admin/plans/:id', requireAdmin, function (req, res) {
  adminPlans = adminPlans.filter(function (plan) {
    return plan.id !== req.params.id;
  });
  delete planMatrix[req.params.id];
  delete quotaRules[req.params.id];
  delete quotaUsage[req.params.id];
  res.json({ success: true, plans: adminPlans });
});

app.get('/api/admin/plan-matrix', requireAdmin, function (req, res) {
  res.json({ success: true, matrix: planMatrix, plans: adminPlans });
});

app.post('/api/admin/plan-matrix', requireAdmin, function (req, res) {
  var matrix = req.body || {};
  planMatrix[matrix.planId] = {
    planId: matrix.planId,
    tools: matrix.tools || {}
  };
  res.json({ success: true, matrix: planMatrix });
});

app.get('/api/admin/quota-rules', requireAdmin, function (req, res) {
  seedDefaultPlans();
  var quotaStatus = {};
  Object.keys(quotaRules).forEach(function (planId) {
    quotaStatus[planId] = getQuotaState(planId);
  });
  res.json({ success: true, rules: quotaRules, usage: quotaUsage, quotaStatus: quotaStatus });
});

app.post('/api/admin/quota-rules', requireAdmin, function (req, res) {
  seedDefaultPlans();
  var payload = req.body || {};
  var normalizedRules = normalizeQuotaRules(payload.planId, payload.rules || []);
  quotaRules[payload.planId] = normalizedRules;
  quotaUsage[payload.planId] = quotaUsage[payload.planId] || { used: 0 };
  var quotaStatus = getQuotaState(payload.planId);
  res.json({ success: true, rules: quotaRules[payload.planId], usage: quotaUsage[payload.planId], quotaStatus: quotaStatus });
});

app.post('/api/public/plan-matrix', function (req, res) {
  seedDefaultPlans();
  res.json({ success: true, matrix: planMatrix, plans: adminPlans, comparison: getPublicPlanQuotaComparison() });
});

app.get('/api/public/plan-matrix', function (req, res) {
  seedDefaultPlans();
  res.json({ success: true, matrix: planMatrix, plans: adminPlans, comparison: getPublicPlanQuotaComparison() });
});

app.post('/api/admin/tax-config', requireAdmin, function (req, res) {
  var payload = req.body || {};
  invoiceTaxConfig.domesticGstRate = Number(payload.domesticGstRate || invoiceTaxConfig.domesticGstRate);
  invoiceTaxConfig.foreignGstRate = Number(payload.foreignGstRate || invoiceTaxConfig.foreignGstRate);
  res.json({ success: true, taxConfig: invoiceTaxConfig });
});

app.post('/api/admin/invoice-preview', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var baseAmount = Number(payload.baseAmount || 0);
  var country = String(payload.country || 'India').trim().toLowerCase();
  var isDomestic = country === 'india' || country === 'in';
  var gstRate = isDomestic ? invoiceTaxConfig.domesticGstRate : invoiceTaxConfig.foreignGstRate;
  var gstAmount = baseAmount * gstRate;
  var totalAmount = baseAmount + gstAmount;
  res.json({ success: true, baseAmount: baseAmount, gstRate: gstRate, gstAmount: gstAmount, totalAmount: totalAmount, country: payload.country || 'India', isDomestic: isDomestic });
});

app.post('/api/admin/quota/consume', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var planId = payload.planId;
  var tool = payload.tool;
  var success = payload.success === true;
  if (!planId || !tool) {
    return res.status(400).json({ success: false, error: 'planId and tool are required.' });
  }
  if (!success) {
    return res.json({ success: true, consumed: false, message: 'No quota change for unsuccessful request.', remainingQuota: getQuotaState(planId).remainingQuota, limit: getQuotaState(planId).limit, used: getQuotaState(planId).used });
  }
  var result = consumePlanQuota(planId, tool, success);
  res.set('X-Quota-Remaining', String(result.remainingQuota === null ? '' : result.remainingQuota));
  res.set('X-Quota-Used', String(result.used));
  res.set('X-Quota-Limit', String(result.limit === null ? '' : result.limit));
  res.set('X-Quota-Exhausted', String(result.exhausted));
  res.set('X-Quota-Plan-Id', String(result.planId || ''));
  res.set('X-Quota-Plan-Name', String(result.planName || ''));
  res.json({ success: true, consumed: result.consumed, used: result.used, exhausted: result.exhausted, remainingQuota: result.remainingQuota, limit: result.limit, rule: result.rule || null, planName: result.planName || '', planId: result.planId || '' });
});

app.get('/api/admin/promos', requireAdmin, function (req, res) {
  res.json({ success: true, promos: promoCodes });
});

app.post('/api/admin/promos', requireAdmin, function (req, res) {
  var payload = req.body || {};
  if (!payload.code) {
    return res.status(400).json({ success: false, error: 'Promo code is required.' });
  }
  var normalizedCode = String(payload.code).trim().toUpperCase();
  var existing = promoCodes.find(function (item) {
    return String(item.code || '').toUpperCase() === normalizedCode;
  });
  var entry = existing || {
    id: 'promo-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    code: normalizedCode,
    discountPercent: Number(payload.discountPercent || 0),
    discountFlat: Number(payload.discountFlat || 0),
    validUntil: payload.validUntil || '',
    usageLimit: Number(payload.usageLimit || 0),
    usedCount: Number(payload.usedCount || 0),
    createdAt: new Date().toISOString()
  };
  entry.code = normalizedCode;
  entry.discountPercent = Number(payload.discountPercent || entry.discountPercent || 0);
  entry.discountFlat = Number(payload.discountFlat || entry.discountFlat || 0);
  entry.validUntil = payload.validUntil || entry.validUntil || '';
  entry.usageLimit = Number(payload.usageLimit || entry.usageLimit || 0);
  entry.usedCount = Number(payload.usedCount || entry.usedCount || 0);
  if (!existing) {
    promoCodes.push(entry);
  }
  res.json({ success: true, promo: entry, promos: promoCodes });
});

app.delete('/api/admin/promos/:code', requireAdmin, function (req, res) {
  promoCodes = promoCodes.filter(function (item) {
    return String(item.code || '').toUpperCase() !== String(req.params.code || '').toUpperCase();
  });
  res.json({ success: true, promos: promoCodes });
});

app.post('/api/checkout/apply-promo', function (req, res) {
  var promoResult = applyPromoCode(req.body && req.body.code ? req.body.code : '', req.body && req.body.amount ? req.body.amount : 0, req.body && req.body.currency ? req.body.currency : 'INR');
  if (!promoResult.success) {
    return res.status(400).json(promoResult);
  }
  res.json(promoResult);
});

app.post('/api/validate-promo', function (req, res) {
  var payload = req.body || {};
  var promoResult = applyPromoCode(payload.code || '', payload.amount || 0, payload.currency || 'INR');
  if (!promoResult.success) {
    return res.status(400).json(promoResult);
  }
  res.json(promoResult);
});

app.get('/api/admin/analytics/sales', requireAdmin, function (req, res) {
  var range = String(req.query.range || 'this-month').toLowerCase();
  var fromDate = req.query.fromDate || '';
  var toDate = req.query.toDate || '';
  if (range === 'this-week' || range === 'this-month' || range === 'this-year' || range === 'custom') {
    // supported
  } else {
    range = 'this-month';
  }
  res.json({ success: true, analytics: getAnalyticsSales(range, fromDate, toDate) });
});

app.get('/api/admin/analytics/tools', requireAdmin, function (req, res) {
  var range = String(req.query.range || 'this-month').toLowerCase();
  var fromDate = req.query.fromDate || '';
  var toDate = req.query.toDate || '';
  if (range === 'this-week' || range === 'this-month' || range === 'this-year' || range === 'custom') {
    // supported
  } else {
    range = 'this-month';
  }
  res.json({ success: true, analytics: getAnalyticsTools(range, fromDate, toDate) });
});

app.get('/api/admin/support/logs', requireAdmin, function (req, res) {
  var actor = String(req.query.actor || '').trim();
  var filtered = auditLogs.slice();
  if (actor) {
    filtered = filtered.filter(function (entry) {
      return String(entry.actor || '').toLowerCase().indexOf(actor.toLowerCase()) !== -1;
    });
  }
  res.json({ success: true, logs: filtered.slice(-100) });
});

app.post('/api/admin/support/credits', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var user = userAccounts.find(function (item) {
    return String(item.id) === String(payload.userId || '');
  });
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found.' });
  }
  var days = Number(payload.days || 0);
  if (days > 0) {
    var nextExpiry = user.accessExpiresAt ? new Date(user.accessExpiresAt).getTime() : Date.now();
    user.accessExpiresAt = new Date(nextExpiry + days * 24 * 60 * 60 * 1000).toISOString();
  }
  if (payload.credits && Number(payload.credits) > 0) {
    user.manualCredits = Number(user.manualCredits || 0) + Number(payload.credits);
  }
  user.updatedAt = new Date().toISOString();
  user.planStatus = 'active';
  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'manual-support', { userId: user.id, days: days, credits: payload.credits || 0, note: payload.note || '' });
  res.json({ success: true, user: user, logs: auditLogs.slice(-20) });
});

app.get('/api/admin/settings', requireAdmin, function (req, res) {
  res.json({ success: true, settings: getPlatformSettingsSnapshot() });
});

app.post('/api/admin/settings', requireAdmin, function (req, res) {
  var payload = req.body || {};
  platformSettings = Object.assign({}, platformSettings, payload, {
    gatewayKeys: Object.assign({}, platformSettings.gatewayKeys, payload.gatewayKeys || {})
  });
  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'settings-update', { maintenanceMode: platformSettings.maintenanceMode, announcement: platformSettings.announcement });
  res.json({ success: true, settings: getPlatformSettingsSnapshot() });
});

app.post('/api/admin/backup/run', requireAdmin, function (req, res) {
  var backupPath = triggerBackup('admin-request');
  res.json({ success: true, backupPath: backupPath });
});

app.post('/api/admin/email/dispatch', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var message = {
    to: payload.to || 'hello@getreadyjob.com',
    subject: payload.subject || 'Get Ready Job Admin Test Email',
    text: payload.text || 'This is a test message from the admin console.'
  };
  dispatchEmail(message).then(function (result) {
    res.json({ success: true, dispatch: result });
  }).catch(function (err) {
    res.status(500).json({ success: false, error: err.message || 'Email dispatch failed.' });
  });
});

app.get('/api/admin/users', requireAdmin, function (req, res) {
  var q = String(req.query.q || '').trim().toLowerCase();
  var planStatus = String(req.query.planStatus || '').trim().toLowerCase();
  var filtered = userAccounts.slice();
  if (q) {
    filtered = filtered.filter(function (user) {
      return [user.email, user.id, user.mobile, user.planId, user.planName, user.planStatus].join(' ').toLowerCase().indexOf(q) !== -1;
    });
  }
  if (planStatus) {
    filtered = filtered.filter(function (user) {
      return String(user.planStatus || '').toLowerCase() === planStatus;
    });
  }
  filtered.forEach(function (user) {
    user.planStatus = getUserPlanStatus(user);
  });
  res.json({ success: true, users: filtered, emailEvents: transactionalEmailEvents.slice(-10) });
});

app.post('/api/admin/users', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var user = userAccounts.find(function (item) {
    return String(item.id) === String(payload.userId || '');
  });
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found.' });
  }
  if (payload.action === 'extend') {
    var extraDays = Number(payload.days || 30);
    var nextExpiry = user.accessExpiresAt ? new Date(user.accessExpiresAt).getTime() : Date.now();
    user.accessExpiresAt = new Date(nextExpiry + extraDays * 24 * 60 * 60 * 1000).toISOString();
    user.planStatus = 'active';
    user.updatedAt = new Date().toISOString();
    triggerTransactionalEmail('receipt', { email: user.email, action: 'extended', userId: user.id });
  } else if (payload.action === 'upgrade') {
    user.planId = payload.planId || user.planId;
    user.planName = payload.planName || user.planName;
    user.planStatus = 'active';
    user.accessExpiresAt = payload.accessExpiresAt || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    user.updatedAt = new Date().toISOString();
    triggerTransactionalEmail('receipt', { email: user.email, action: 'upgraded', userId: user.id });
  } else if (payload.action === 'revoke') {
    user.planStatus = 'revoked';
    user.accessExpiresAt = new Date().toISOString();
    user.updatedAt = new Date().toISOString();
  } else {
    return res.status(400).json({ success: false, error: 'Unsupported action.' });
  }
  user.planStatus = getUserPlanStatus(user);
  res.json({ success: true, user: user, users: userAccounts });
});

app.get('/api/user/account', function (req, res) {
  var email = String(req.query && req.query.email ? req.query.email : '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required.' });
  }
  var user = userAccounts.find(function (item) {
    return String(item.email || '').toLowerCase() === email;
  });
  if (!user) {
    return res.status(404).json({ success: false, error: 'User account not found.' });
  }
  res.json({ success: true, user: user });
});

app.post('/api/user/account', function (req, res) {
  var payload = req.body || {};
  var email = String(payload.email || '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required.' });
  }
  var user = upsertUserAccount({
    email: email,
    name: payload.name || '',
    company: payload.company || '',
    mobile: payload.mobile || '',
    country: payload.country || 'India',
    gstin: payload.gstin || '',
    planId: payload.planId || '',
    planName: payload.planName || '',
    planStatus: payload.planStatus || 'active',
    accessExpiresAt: payload.accessExpiresAt || null
  });
  res.json({ success: true, user: user });
});

app.post('/api/user/password-reset', function (req, res) {
  var email = String(req.body && req.body.email ? req.body.email : '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required.' });
  }
  var user = upsertUserAccount({ email: email });
  triggerTransactionalEmail('password-reset', { email: email, userId: user.id });
  res.json({ success: true, message: 'Password reset email queued.', email: email });
});

app.post('/api/user/google-signin', function (req, res) {
  var payload = req.body || {};
  var profile = payload.profile || {};
  var email = String(profile.email || payload.email || '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ success: false, error: 'Google email is required.' });
  }

  var user = upsertUserAccount({
    email: email,
    name: profile.name || payload.name || '',
    company: profile.company || '',
    mobile: profile.mobile || '',
    country: profile.country || 'India',
    planId: payload.planId || '',
    planName: payload.planName || '',
    planStatus: payload.planStatus || 'active',
    accessExpiresAt: payload.accessExpiresAt || null
  });

  user.provider = 'google';
  user.googleSub = profile.sub || payload.sub || '';
  user.googlePicture = profile.picture || payload.picture || '';
  user.updatedAt = new Date().toISOString();

  triggerTransactionalEmail('google-signin', { email: email, userId: user.id, provider: 'google' });
  res.json({ success: true, user: user, provider: 'google' });
});

app.get('/api/user/invoice/:transactionId', function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }
  var pdfBuffer = buildInvoicePdfBuffer(transaction);
  res.set('Content-Type', 'application/pdf');
  res.set('Content-Disposition', 'attachment; filename="invoice-' + transaction.transactionId + '.pdf"');
  res.send(pdfBuffer);
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

app.get('/sitemap.xml', function (req, res) {
  var sitemapPath = path.join(__dirname, 'public', 'sitemap.xml');
  if (fs.existsSync(sitemapPath)) {
    return res.sendFile(sitemapPath);
  }
  res.type('application/xml');
  res.send(`<?xml version="1.0" encoding="UTF-8"?>
<urlset
  xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>https://getreadyjob.com/</loc>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://getreadyjob.com/" />
    <xhtml:link rel="alternate" hreflang="en-us" href="https://getreadyjob.com/en-us/" />
    <xhtml:link rel="alternate" hreflang="en-gb" href="https://getreadyjob.com/en-gb/" />
    <xhtml:link rel="alternate" hreflang="en-in" href="https://getreadyjob.com/en-in/" />
  </url>
  <url>
    <loc>https://getreadyjob.com/convert</loc>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://getreadyjob.com/convert" />
    <xhtml:link rel="alternate" hreflang="en-us" href="https://getreadyjob.com/convert" />
    <xhtml:link rel="alternate" hreflang="en-gb" href="https://getreadyjob.com/convert" />
    <xhtml:link rel="alternate" hreflang="en-in" href="https://getreadyjob.com/en-in/convert" />
  </url>
  <url>
    <loc>https://getreadyjob.com/blog</loc>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://getreadyjob.com/blog" />
    <xhtml:link rel="alternate" hreflang="en-in" href="https://getreadyjob.com/blog" />
  </url>
  <url><loc>https://getreadyjob.com/about</loc></url>
  <url><loc>https://getreadyjob.com/contact</loc></url>
  <url><loc>https://getreadyjob.com/pricing</loc></url>
  <url><loc>https://getreadyjob.com/faq</loc></url>
  <url><loc>https://getreadyjob.com/privacy-policy</loc></url>
  <url><loc>https://getreadyjob.com/terms</loc></url>
</urlset>`);
});

app.get('/robots.txt', function (req, res) {
  var robotsPath = path.join(__dirname, 'public', 'robots.txt');
  if (fs.existsSync(robotsPath)) {
    return res.sendFile(robotsPath);
  }
  res.type('text/plain');
  res.send('User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /private\nSitemap: https://getreadyjob.com/sitemap.xml\n');
});

app.get('/api/config', function (req, res) {
  var keyId = process.env.RAZORPAY_KEY_ID || (platformSettings.gatewayKeys && platformSettings.gatewayKeys.razorpayKeyId ? platformSettings.gatewayKeys.razorpayKeyId : '') || '';
  res.json({
    key_id: keyId,
    gateway: 'razorpay',
    payment_link_enabled: Boolean(razorpay && razorpay.paymentLink)
  });
});

app.post('/api/create-payment-link', function (req, res) {
  if (!razorpay || !razorpay.paymentLink) {
    return res.status(503).json({
      success: false,
      error: 'Razorpay payment link is not configured on server. Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.'
    });
  }

  var amount = parseInt(req.body.amount, 10);
  var currency = (req.body.currency || 'INR').toUpperCase();
  var planId = req.body.planId || 'lifetime-pro';
  var receipt = req.body.receipt || ('payment-link-' + Date.now());
  var billing = req.body.billing || {};
  var customerName = String(billing.name || req.body.name || 'User').trim();
  var customerEmail = String(billing.email || req.body.email || '').trim();
  var customerPhone = String(billing.mobile || req.body.mobile || '').replace(/\D/g, '');

  if (!Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ success: false, error: 'Amount must be greater than zero.' });
  }

  var plan = getPlanById(planId);
  var planName = plan ? plan.name : 'Lifetime Pro';
  var referenceId = 'plink-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6);
  var description = 'GetReadyJob ' + planName + ' payment';

  var paymentLinkPayload = {
    amount: amount,
    currency: currency,
    reference_id: referenceId,
    description: description,
    customer: {
      name: customerName || 'User',
      email: customerEmail || undefined,
      contact: customerPhone || undefined
    },
    notify: {
      sms: Boolean(customerPhone),
      email: Boolean(customerEmail)
    },
    reminder_enable: true,
    notes: {
      plan_id: String(planId),
      receipt: String(receipt)
    }
  };

  razorpay.paymentLink.create(paymentLinkPayload, function (err, link) {
    if (err) {
      console.error('Razorpay create-payment-link error:', err);
      var status = err.statusCode || 500;
      var backendError = err.error && err.error.description ? err.error.description : 'Unable to create Razorpay payment link.';
      return res.status(status).json({ success: false, error: backendError });
    }

    logAuditEvent(customerEmail || 'guest', 'payment-link-created', {
      referenceId: referenceId,
      planId: planId,
      amount: amount,
      currency: currency,
      provider: 'razorpay'
    });

    res.json({
      success: true,
      provider: 'razorpay',
      reference_id: referenceId,
      link_id: link && link.id ? link.id : '',
      payment_link: link && link.short_url ? link.short_url : '',
      status: link && link.status ? link.status : 'created',
      amount: amount,
      currency: currency,
      plan_id: planId,
      plan_name: planName,
      expires_at: link && link.expire_by ? link.expire_by : null
    });
  });
});

app.post('/api/create-order', function (req, res) {
  var amount = parseInt(req.body.amount, 10);
  var receipt = req.body.receipt || 'lifetime-pass';
  var currency = (req.body.currency || 'INR').toUpperCase();
  var planId = req.body.planId || 'lifetime-pro';
  var billing = req.body.billing || {};
  var promoCode = req.body.promoCode || req.body.code || '';
  var plan = getPlanById(planId);
  var planName = plan ? plan.name : 'Lifetime Pro';
  var orderId = 'local-order-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6);
  var promoResult = applyPromoCode(promoCode, amount, currency);
  var discountedAmount = promoResult.success && promoResult.applied ? promoResult.finalAmount : amount;
  var gatewayContext = buildGatewayContext(billing, currency);
  var taxBreakdown = resolveTaxBreakdown(discountedAmount, billing, currency);
  var finalAmountMinor = taxBreakdown.totalAmount;
  var user = upsertUserAccount({
    email: billing.email || '',
    name: billing.name || '',
    company: billing.company || '',
    mobile: billing.mobile || '',
    country: billing.country || 'India',
    gstin: billing.gstin || '',
    planId: planId,
    planName: planName,
    planStatus: 'active',
    accessExpiresAt: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString()
  });
  triggerTransactionalEmail('welcome', { email: user.email || billing.email, userId: user.id, planName: planName });

  pendingOrders[orderId] = {
    orderId: orderId,
    planId: planId,
    planName: planName,
    amount: finalAmountMinor,
    currency: currency,
    receipt: receipt,
    billing: billing,
    taxBreakdown: taxBreakdown,
    userId: user.id,
    promoCode: promoCode,
    promoResult: promoResult,
    gatewayContext: gatewayContext,
    createdAt: new Date().toISOString()
  };

  logAuditEvent(user.email || billing.email || 'guest', 'checkout-created', { orderId: orderId, planId: planId, amount: finalAmountMinor, currency: currency, promoCode: promoCode, gateway: gatewayContext.provider });

  if (!razorpay) {
    return res.json({ success: true, order_id: orderId, amount: finalAmountMinor, currency: currency, localOnly: true, taxBreakdown: taxBreakdown, gateway: gatewayContext.provider, promo: promoResult });
  }

  var validation = razorpayUtils.validateOrderPayload({ amount: amount, currency: currency, receipt: receipt });

  if (!validation.valid) {
    return res.status(400).json({ success: false, error: validation.error });
  }

  razorpay.orders.create({
    amount: amount,
    currency: currency,
    receipt: receipt
  }, function (err, order) {
    if (err) {
      console.error('Razorpay create-order error:', err);
      var status = 500;
      if (err.statusCode === 401) status = 401;
      return res.status(status).json({ success: false, error: err.error || 'Unable to create Razorpay order.' });
    }

    res.json({ success: true, order_id: order.id, amount: order.amount, currency: order.currency, taxBreakdown: taxBreakdown, gateway: gatewayContext.provider, promo: promoResult });
  });
});

app.post('/api/verify-payment', function (req, res) {
  var orderId = req.body.order_id;
  var paymentId = req.body.payment_id;
  var signature = req.body.signature;

  if (!orderId) {
    return res.status(400).json({ success: false, error: 'Missing payment verification fields.' });
  }

  if (razorpay) {
    if (!paymentId || !signature) {
      return res.status(400).json({ success: false, error: 'Missing payment verification fields.' });
    }
    var generatedSignature = razorpayUtils.createPaymentSignature(orderId, paymentId, process.env.RAZORPAY_KEY_SECRET);
    if (generatedSignature !== signature) {
      return res.status(400).json({ success: false, error: 'Signature mismatch. Payment was not verified.' });
    }
  }

  var pendingOrder = pendingOrders[orderId];
  if (!pendingOrder) {
    return res.status(404).json({ success: false, error: 'Order not found.' });
  }

  var transactionId = 'txn-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  var transaction = {
    transactionId: transactionId,
    orderId: orderId,
    paymentId: paymentId || 'local-' + Date.now(),
    planId: pendingOrder.planId,
    planName: pendingOrder.planName,
    amount: pendingOrder.amount / 100,
    currency: pendingOrder.currency,
    totalAmount: pendingOrder.amount / 100 + (pendingOrder.taxBreakdown ? pendingOrder.taxBreakdown.gstAmount : 0),
    taxBreakdown: pendingOrder.taxBreakdown,
    billing: pendingOrder.billing,
    country: pendingOrder.billing && pendingOrder.billing.country ? pendingOrder.billing.country : 'India',
    status: 'paid',
    createdAt: new Date().toISOString(),
    paidAt: new Date().toISOString()
  };
  salesTransactions.push(transaction);
  delete pendingOrders[orderId];

  var user = userAccounts.find(function (item) {
    return String(item.id) === String(pendingOrder.userId || '');
  }) || upsertUserAccount({
    email: pendingOrder.billing && pendingOrder.billing.email ? pendingOrder.billing.email : '',
    name: pendingOrder.billing && pendingOrder.billing.name ? pendingOrder.billing.name : '',
    company: pendingOrder.billing && pendingOrder.billing.company ? pendingOrder.billing.company : '',
    mobile: pendingOrder.billing && pendingOrder.billing.mobile ? pendingOrder.billing.mobile : '',
    country: pendingOrder.billing && pendingOrder.billing.country ? pendingOrder.billing.country : 'India',
    gstin: pendingOrder.billing && pendingOrder.billing.gstin ? pendingOrder.billing.gstin : '',
    planId: pendingOrder.planId,
    planName: pendingOrder.planName,
    planStatus: 'active',
    accessExpiresAt: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString()
  });
  user.planId = pendingOrder.planId;
  user.planName = pendingOrder.planName;
  user.billingCountry = pendingOrder.billing && pendingOrder.billing.country ? pendingOrder.billing.country : 'India';
  user.gstin = pendingOrder.billing && pendingOrder.billing.gstin ? pendingOrder.billing.gstin : user.gstin;
  user.planStatus = 'active';
  user.accessExpiresAt = new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString();
  user.updatedAt = new Date().toISOString();
  logAuditEvent(user.email || pendingOrder.billing && pendingOrder.billing.email ? pendingOrder.billing.email : 'guest', 'payment-verified', { transactionId: transaction.transactionId, planId: pendingOrder.planId, amount: pendingOrder.amount });
  triggerTransactionalEmail('receipt', { email: user.email, userId: user.id, transactionId: transaction.transactionId });
  dispatchEmail({
    to: user.email || pendingOrder.billing && pendingOrder.billing.email ? (pendingOrder.billing && pendingOrder.billing.email ? pendingOrder.billing.email : emailConfig.from) : emailConfig.from,
    subject: 'Welcome to Get Ready Job – Your ' + pendingOrder.planName + ' is Active! 🚀',
    text: 'Your subscription is active. Plan: ' + pendingOrder.planName + '. Quota: Lifetime / Unlimited. Visit the dashboard to manage your account.'
  });
  dispatchEmail({
    to: user.email || pendingOrder.billing && pendingOrder.billing.email ? (pendingOrder.billing && pendingOrder.billing.email ? pendingOrder.billing.email : emailConfig.from) : emailConfig.from,
    subject: 'Tax Invoice for Your Order - Get Ready Job (Invoice #' + transaction.transactionId + ')',
    text: 'Thank you for your purchase. Payment receipt summary: ' + transaction.transactionId + ' / ' + transaction.totalAmount + ' ' + transaction.currency + '.',
    attachments: [{ filename: 'invoice-' + transaction.transactionId + '.pdf', content: buildInvoicePdfBuffer(transaction) }]
  });

  res.json({ success: true, message: 'Payment verified successfully.', transactionId: transaction.transactionId, invoiceUrl: '/api/user/invoice/' + transaction.transactionId });
});

// Main compression endpoint
app.post('/api/compress', upload.single('file'), enforceQuotaMiddleware, function (req, res) {
  var tempInputPath = null;
  var tempOutputPath = null;
  recordToolUsageEvent(req.body && req.body.planId ? req.body.planId : '', (req.body && req.body.tool) ? req.body.tool : 'compression', { source: 'compress-endpoint' });

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

    tempInputPath = persistUploadedFile(req.file, req) || req.file.path;
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
      var consumption = consumePlanQuota(req.quotaContext && req.quotaContext.planId ? req.quotaContext.planId : '', req.quotaContext && req.quotaContext.tool ? req.quotaContext.tool : 'compression', true);
      logAuditEvent(req.body && req.body.planId ? req.body.planId : 'guest', 'tool-compression', { tool: req.body && req.body.tool ? req.body.tool : 'compression', planId: req.quotaContext && req.quotaContext.planId ? req.quotaContext.planId : '' });
      var downloadName = baseName + '_compressed' + outputExt;
      res.set('X-Quota-Remaining', String(consumption.remainingQuota === null ? '' : consumption.remainingQuota));
      res.set('X-Quota-Used', String(consumption.used));
      res.set('X-Quota-Limit', String(consumption.limit === null ? '' : consumption.limit));
      res.set('X-Quota-Exhausted', String(consumption.exhausted));
      res.set('X-Quota-Plan-Id', String(consumption.planId || ''));
      res.set('X-Quota-Plan-Name', String(consumption.planName || ''));
      res.download(tempOutputPath, downloadName, function (dlErr) {
        cleanupFile(tempInputPath);
        cleanupFile(tempOutputPath);
        if (dlErr) console.error('Download error:', dlErr.message);
      });
      if (consumption && consumption.consumed && consumption.exhausted) {
        console.log('Quota exhausted after successful run:', req.quotaContext && req.quotaContext.planId, req.quotaContext && req.quotaContext.tool, consumption.used);
      }
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
if (require.main === module) {
  triggerBackup('startup');
  setInterval(function () {
    try {
      triggerBackup('scheduled');
    } catch (err) {
      console.error('Backup failed:', err.message || err);
    }
  }, 15 * 60 * 1000);

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
}

module.exports = { app: app };
