'use strict';

var express = require('express');
var multer = require('multer');
var path = require('path');
var fs = require('fs');
var crypto = require('crypto');
var https = require('https');
var Razorpay = require('razorpay');
var QRCode = require('qrcode');
var razorpayUtils = require('./Utils/razorpay');
var adminAuth = require('./Utils/adminAuth');
var adminRateLimiter = require('./Utils/adminRateLimiter');

var app = express();
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

loadEnvFile();

var allowedCorsOrigins = [
  'https://getreadyjob.com',
  'https://www.getreadyjob.com',
  'https://jobready-india.onrender.com',
  'https://getreadyjob-india-1cb34.web.app',
  'https://getreadyjob-india-1cb34.firebaseapp.com',
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

function registerPendingOrder(orderId, pendingOrder) {
  if (!orderId || !pendingOrder) {
    return;
  }

  pendingOrders[orderId] = pendingOrder;
  if (pendingOrder.localOrderId && pendingOrder.localOrderId !== orderId) {
    pendingOrders[pendingOrder.localOrderId] = pendingOrder;
  }
  if (pendingOrder.razorpayOrderId && pendingOrder.razorpayOrderId !== orderId) {
    pendingOrders[pendingOrder.razorpayOrderId] = pendingOrder;
  }
}

function resolvePendingOrder(orderId) {
  if (!orderId) {
    return null;
  }

  var lookupKey = String(orderId);
  if (pendingOrders[lookupKey]) {
    return pendingOrders[lookupKey];
  }

  var candidates = Object.keys(pendingOrders);
  for (var i = 0; i < candidates.length; i += 1) {
    var candidateKey = candidates[i];
    var candidate = pendingOrders[candidateKey];
    if (!candidate) {
      continue;
    }
    if ((candidate.localOrderId && String(candidate.localOrderId) === lookupKey) ||
        (candidate.razorpayOrderId && String(candidate.razorpayOrderId) === lookupKey)) {
      return candidate;
    }
  }

  return null;
}

function clearPendingOrder(orderId) {
  var pendingOrder = resolvePendingOrder(orderId);
  if (!pendingOrder) {
    if (orderId && pendingOrders[orderId]) {
      delete pendingOrders[orderId];
    }
    return;
  }

  if (pendingOrder.localOrderId) {
    delete pendingOrders[pendingOrder.localOrderId];
  }
  if (pendingOrder.razorpayOrderId) {
    delete pendingOrders[pendingOrder.razorpayOrderId];
  }
  if (orderId) {
    delete pendingOrders[orderId];
  }
}
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
// PERSISTENT_DATA_DIR should point at a mounted Render Persistent Disk (or other durable
// volume) so GST sales records, invoice counters, and 2FA state survive container redeploys.
// Falls back to the ephemeral local 'backups' folder when unset (dev/test only).
var backupDir = process.env.PERSISTENT_DATA_DIR
  ? path.resolve(process.env.PERSISTENT_DATA_DIR)
  : path.join(__dirname, 'backups');
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

// Place of supply is decided against this registered state; override per deployment.
var sellerGstProfile = {
  stateName: String(process.env.SELLER_STATE_NAME || 'Delhi').trim() || 'Delhi',
  stateCode: String(process.env.SELLER_STATE_CODE || '07').trim() || '07',
  gstin: String(process.env.SELLER_GSTIN || '').trim().toUpperCase()
};

// Universal dynamic plan name resolver: never hardcode plan titles at the call site.
function resolvePlanTitle(planId, rawPlanName, totalPaid) {
  var amount = Number(totalPaid) || 0;
  var key = String(planId || '').trim().toLowerCase();

  // Strict amount-based override: the actual charged amount always wins over a mismatched/fallback planId.
  if (amount === 99 || key === '7-day' || key === 'short-access' || key === 'weekly-pass') {
    return '7 Days Access';
  }
  if (amount === 499 || key === 'monthly' || key === 'pro-monthly') {
    return '1 Month Pro';
  }
  if (amount === 999 || key === 'yearly') {
    return '1 Year Unlimited Access';
  }
  if (key === 'lifetime-pro') {
    return 'Lifetime Pro';
  }
  return rawPlanName || 'Get Ready Job Subscription';
}

function getPlanAccessExpiry(planId, planName, amountInRupees) {
  var plan = getPlanById(planId);
  if (plan && Number(plan.durationDays) > 0) {
    return new Date(Date.now() + Number(plan.durationDays) * 24 * 60 * 60 * 1000).toISOString();
  }

  var amount = Number(amountInRupees || 0);
  var normalizedPlanId = String(planId || '').trim().toLowerCase();
  if (amount === 99 || normalizedPlanId === 'weekly-pass' || normalizedPlanId === '7-day' || normalizedPlanId === 'short-access') {
    return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  }
  if (amount === 499 || normalizedPlanId === 'pro-monthly' || normalizedPlanId === 'monthly') {
    return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  }
  if (amount === 999 || normalizedPlanId === 'yearly') {
    return new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
  }
  if (normalizedPlanId === 'lifetime-pro') {
    return new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString();
  }
  return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
}

// Mirrors the same amount/planId thresholds as resolvePlanTitle/getPlanAccessExpiry so the
// entitlement always matches whichever tier the customer actually paid for. Lifetime is a
// true unlimited entitlement (no cap, never decremented); other tiers keep the numbers the
// dashboard has always shown users (10/60/180), so no familiar figure suddenly changes.
function getQuotaEntitlementForPlan(planId, planName, amountInRupees) {
  var amount = Number(amountInRupees || 0);
  var normalizedPlanId = String(planId || '').trim().toLowerCase();
  if (normalizedPlanId === 'lifetime-pro') {
    return { total: 'unlimited', isUnlimited: true };
  }
  if (amount === 999 || normalizedPlanId === 'yearly') {
    return { total: 180, isUnlimited: false };
  }
  if (amount === 499 || normalizedPlanId === 'pro-monthly' || normalizedPlanId === 'monthly') {
    return { total: 60, isUnlimited: false };
  }
  if (amount === 99 || normalizedPlanId === 'weekly-pass' || normalizedPlanId === '7-day' || normalizedPlanId === 'short-access') {
    return { total: 10, isUnlimited: false };
  }
  return { total: 3, isUnlimited: false };
}

function normalizeBillingFromPaymentContext(paymentEntity, orderEntity, pendingOrder) {
  var notes = paymentEntity && paymentEntity.notes ? paymentEntity.notes : {};
  var billing = pendingOrder && pendingOrder.billing ? Object.assign({}, pendingOrder.billing) : {};
  var email = String((paymentEntity && paymentEntity.email) || notes.email || billing.email || '').trim();
  var name = String(notes.name || (paymentEntity && paymentEntity.name) || billing.name || '').trim();
  var company = String(notes.company || billing.company || '').trim();
  var country = String(notes.country || (billing.country || (paymentEntity && paymentEntity.country) || (orderEntity && orderEntity.country) || 'India')).trim();
  var state = String(notes.state || billing.state || '').trim();
  var gstin = String(notes.gstin || billing.gstin || '').trim();
  var sez = String(notes.sez || notes.sezStatus || billing.sez || billing.sezStatus || '').trim();
  var mobile = String(notes.mobile || billing.mobile || (paymentEntity && paymentEntity.contact) || '').replace(/\D/g, '');

  if (email) billing.email = email;
  if (name) billing.name = name;
  if (company) billing.company = company;
  if (country) billing.country = country;
  if (state) billing.state = state;
  if (gstin) billing.gstin = gstin;
  if (sez) billing.sez = sez.toUpperCase();
  if (mobile) billing.mobile = mobile;

  if (!billing.country) billing.country = 'India';
  if (!billing.state && billing.country === 'India') billing.state = 'Delhi';
  return billing;
}

function normalizeCountry(country) {
  var normalized = String(country || '').trim().toLowerCase();
  if (!normalized || normalized === 'india' || normalized === 'in') {
    return 'India';
  }
  return String(country || '').trim() || 'International';
}

var indianStateCodeMap = {
  'andhra pradesh': '28',
  'arunachal pradesh': '12',
  'assam': '18',
  'bihar': '10',
  'chandigarh': '04',
  'chhattisgarh': '22',
  'dadra and nagar haveli and daman and diu': '26',
  'daman and diu': '26',
  'delhi': '07',
  'goa': '30',
  'gujarat': '24',
  'haryana': '06',
  'himachal pradesh': '02',
  'jammu and kashmir': '01',
  'jharkhand': '20',
  'karnataka': '29',
  'kerala': '32',
  'ladakh': '38',
  'lakshadweep': '31',
  'madhya pradesh': '23',
  'maharashtra': '27',
  'manipur': '14',
  'meghalaya': '17',
  'mizoram': '15',
  'nagaland': '13',
  'new delhi': '07',
  'odisha': '21',
  'puducherry': '34',
  'punjab': '03',
  'rajasthan': '08',
  'sikkim': '11',
  'tamil nadu': '33',
  'telangana': '36',
  'tripura': '16',
  'uttar pradesh': '09',
  'uttarakhand': '05',
  'west bengal': '19'
};

function normalizeStateName(stateName) {
  return String(stateName || '').trim().replace(/\s+/g, ' ');
}

function resolveStateCode(stateName) {
  var normalized = normalizeStateName(stateName).toLowerCase();
  if (!normalized) {
    return '';
  }
  return indianStateCodeMap[normalized] || '';
}

// Exports use POS code 96 (Other Countries) per GST rules, never a domestic state code.
var EXPORT_POS_STATE = 'Other Countries';
var EXPORT_POS_CODE = '96';

function getInvoicePosContext(billing) {
  var countryName = normalizeCountry(billing && billing.country ? billing.country : 'India');
  var sellerStateName = sellerGstProfile.stateName;
  var sellerStateCode = sellerGstProfile.stateCode;
  var isDomestic = countryName === 'India';

  if (!isDomestic) {
    return {
      country: countryName,
      state: EXPORT_POS_STATE,
      stateCode: EXPORT_POS_CODE,
      sellerState: sellerStateName,
      sellerStateCode: sellerStateCode,
      isIntrastate: false,
      isIntrastateDelhi: false,
      isExport: true,
      gstType: 'Export of Services (0% GST)'
    };
  }

  var stateName = normalizeStateName((billing && billing.state) || sellerStateName);
  var stateCode = resolveStateCode(stateName) || sellerStateCode;
  var isIntrastate = stateCode === sellerStateCode;
  return {
    country: countryName,
    state: stateName || sellerStateName,
    stateCode: stateCode || sellerStateCode,
    sellerState: sellerStateName,
    sellerStateCode: sellerStateCode,
    isIntrastate: isIntrastate,
    isIntrastateDelhi: isIntrastate,
    isExport: false,
    gstType: isIntrastate ? 'CGST + SGST' : 'IGST'
  };
}

function isValidGstin(value) {
  return /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(String(value || '').trim().toUpperCase());
}

function isSezBilling(billing) {
  var raw = String((billing && (billing.sez || billing.sezStatus)) || '').trim().toUpperCase();
  return raw === 'YES' || raw === 'TRUE' || raw === 'Y';
}

var SEZ_TRANSACTION_TYPE = 'SEZ with Payment of IGST';
var EXPORT_TRANSACTION_TYPE = 'Export (Zero-Rated / WOPAY)';

// Single source of truth for B2B/B2C/SEZ/Export tagging and the CGST+SGST vs IGST split.
function resolveGstClassification(billing) {
  var pos = getInvoicePosContext(billing);
  var isDomestic = isDomesticCountry(pos.country);
  var gstin = String((billing && billing.gstin) || '').trim().toUpperCase();
  var hasValidGstin = isValidGstin(gstin);
  var isSez = isSezBilling(billing);

  var transactionType;
  if (!isDomestic) {
    transactionType = EXPORT_TRANSACTION_TYPE;
  } else if (isSez) {
    transactionType = SEZ_TRANSACTION_TYPE;
  } else {
    transactionType = hasValidGstin ? 'B2B' : 'B2C';
  }

  // SEZ supplies are inter-state by law, so they always carry IGST even from the seller's own state.
  var useIgst = isDomestic && (isSez || !pos.isIntrastate);

  return {
    pos: pos,
    isDomestic: isDomestic,
    isExport: !isDomestic,
    isSez: isSez,
    transactionType: transactionType,
    // An export invoice carries no Indian GSTIN for the customer.
    customerGstin: isDomestic && hasValidGstin ? gstin : '',
    useIgst: useIgst,
    gstType: !isDomestic ? 'Export of Services (0% GST)' : (useIgst ? 'IGST' : 'CGST + SGST')
  };
}

function isDomesticCountry(country) {
  var normalized = String(country || '').trim().toLowerCase();
  return normalized === 'india' || normalized === 'in';
}

function calculateTaxBreakdown(baseAmount, country, billing) {
  var normalizedCountry = normalizeCountry(country);
  var classification = resolveGstClassification(Object.assign({}, billing || {}, { country: normalizedCountry }));
  var isDomestic = classification.isDomestic;
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
    cgstAmount: isDomestic && !classification.useIgst ? gstAmount / 2 : 0,
    sgstAmount: isDomestic && !classification.useIgst ? gstAmount / 2 : 0,
    igstAmount: isDomestic && classification.useIgst ? gstAmount : 0,
    isSez: classification.isSez,
    transactionType: classification.transactionType,
    gstType: classification.gstType
  };
}

function formatInvoiceMoney(value) {
  var num = Number(value || 0);
  var fixed = num.toFixed(2);
  var parts = fixed.split('.');
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return parts.join('.');
}

function formatIstReceiptTimestamp(isoString) {
  var date = isoString ? new Date(isoString) : new Date();
  if (isNaN(date.getTime())) {
    date = new Date();
  }
  var ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  var pad = function (n) { return String(n).padStart(2, '0'); };
  return pad(ist.getUTCDate()) + '-' + pad(ist.getUTCMonth() + 1) + '-' + ist.getUTCFullYear() +
    ' ' + pad(ist.getUTCHours()) + ':' + pad(ist.getUTCMinutes()) + ' IST';
}

// Renders a modern, Stripe/Razorpay-style A4 tax invoice using pdf-lib so every
// column is measured against real font metrics - no clipped or overflowing text.
async function buildInvoicePdfBuffer(transaction) {
  var billing = transaction && transaction.billing ? transaction.billing : {};
  var taxBreakdown = transaction && transaction.taxBreakdown ? transaction.taxBreakdown : {};
  var seller = transaction && transaction.seller ? transaction.seller : invoiceSellerProfile;
  var totalPaid = Number(transaction.totalAmount || transaction.amount || 0);
  var fallbackTaxBreakdown = resolveTaxBreakdown(totalPaid, billing, transaction && transaction.currency ? transaction.currency : 'INR');
  var normalizedTaxBreakdown = Object.assign({}, fallbackTaxBreakdown, taxBreakdown || {});
  var posContext = getInvoicePosContext(billing);
  var isExportInvoice = Boolean(posContext && posContext.isExport);
  var isDomesticInvoice = normalizedTaxBreakdown.isDomestic !== undefined
    ? Boolean(normalizedTaxBreakdown.isDomestic)
    : String(transaction.currency || 'INR').toUpperCase() === 'INR';
  var finalPlanTitle = resolvePlanTitle(transaction.planId, transaction.planName, totalPaid);
  var baseAmount = normalizedTaxBreakdown.baseAmount !== undefined ? Number(normalizedTaxBreakdown.baseAmount) : (isDomesticInvoice ? Number((totalPaid / 1.18).toFixed(2)) : totalPaid);
  var cgstAmount = Number(normalizedTaxBreakdown.cgstAmount || 0);
  var sgstAmount = Number(normalizedTaxBreakdown.sgstAmount || 0);
  var igstAmount = Number(normalizedTaxBreakdown.igstAmount || 0);
  var currencyLabel = (!transaction.currency || String(transaction.currency).toUpperCase() === 'INR')
    ? 'INR '
    : (String(transaction.currency).toUpperCase() + ' ');
  var gstRatePercent = Number(normalizedTaxBreakdown.gstRate !== undefined ? normalizedTaxBreakdown.gstRate : 0.18) * 100;
  var halfRatePercent = gstRatePercent / 2;
  var classification = resolveGstClassification(billing);
  var transactionTypeLabel = normalizedTaxBreakdown.transactionType || classification.transactionType || 'B2C';
  var placeOfSupplyLabel = isExportInvoice
    ? (EXPORT_POS_CODE + '-' + EXPORT_POS_STATE + ' (Export Out of India)')
    : ((posContext.state || sellerGstProfile.stateName) + ' (' + (posContext.stateCode || sellerGstProfile.stateCode) + ')');
  var isAmendedInvoice = Boolean(transaction && (transaction.status === 'amended' || transaction.amended === true));

  var pdfLib = require('pdf-lib');
  var PDFDocument = pdfLib.PDFDocument;
  var StandardFonts = pdfLib.StandardFonts;
  var rgb = pdfLib.rgb;
  var PageSizes = pdfLib.PageSizes;

  var pdfDoc = await PDFDocument.create();
  var page = pdfDoc.addPage(PageSizes.A4);
  var pageSize = page.getSize();
  var pageWidth = pageSize.width;
  var pageHeight = pageSize.height;
  var font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  var fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

  var margin = 40;
  var contentLeft = margin;
  var contentRight = pageWidth - margin;
  var contentWidth = contentRight - contentLeft;
  var contentTop = pageHeight - margin;

  var navy = rgb(15 / 255, 23 / 255, 42 / 255);
  var grayBorder = rgb(226 / 255, 232 / 255, 240 / 255);
  var darkText = navy;
  var mutedText = rgb(100 / 255, 116 / 255, 139 / 255);
  var white = rgb(1, 1, 1);
  var lightBg = rgb(248 / 255, 250 / 255, 252 / 255);
  var headerMuted = rgb(0.75, 0.8, 0.88);

  // Shrinks to fit maxWidth using real font metrics, then truncates with an
  // ellipsis as a last resort - guarantees no cell can ever overflow its column.
  function fitText(useFont, text, maxWidth, preferredSize, minSize) {
    minSize = minSize || 7;
    var str = String(text === null || text === undefined ? '' : text);
    var size = preferredSize;
    while (size > minSize && useFont.widthOfTextAtSize(str, size) > maxWidth) {
      size -= 0.5;
    }
    if (useFont.widthOfTextAtSize(str, size) > maxWidth) {
      while (str.length > 1 && useFont.widthOfTextAtSize(str + '...', size) > maxWidth) {
        str = str.slice(0, -1);
      }
      str = str.length > 0 ? str + '...' : '';
    }
    return { text: str, size: size };
  }
  function drawLeft(text, x, y, size, useFont, color) {
    page.drawText(String(text || ''), { x: x, y: y, size: size, font: useFont, color: color });
  }
  function drawRight(text, rightX, y, size, useFont, color) {
    var str = String(text || '');
    var w = useFont.widthOfTextAtSize(str, size);
    page.drawText(str, { x: rightX - w, y: y, size: size, font: useFont, color: color });
  }
  function drawCenter(text, centerX, y, size, useFont, color) {
    var str = String(text || '');
    var w = useFont.widthOfTextAtSize(str, size);
    page.drawText(str, { x: centerX - w / 2, y: y, size: size, font: useFont, color: color });
  }
  function drawFitLeft(text, x, y, maxWidth, preferredSize, useFont, color, minSize) {
    var fit = fitText(useFont, text, maxWidth, preferredSize, minSize);
    page.drawText(fit.text, { x: x, y: y, size: fit.size, font: useFont, color: color });
    return fit.size;
  }
  function drawFitRight(text, rightX, y, maxWidth, preferredSize, useFont, color, minSize) {
    var fit = fitText(useFont, text, maxWidth, preferredSize, minSize);
    var w = useFont.widthOfTextAtSize(fit.text, fit.size);
    page.drawText(fit.text, { x: rightX - w, y: y, size: fit.size, font: useFont, color: color });
    return fit.size;
  }

  // ---------- Header band (2-column: seller identity | invoice metadata) ----------
  var headerHeight = 92;
  var headerBottom = contentTop - headerHeight;
  page.drawRectangle({ x: contentLeft, y: headerBottom, width: contentWidth, height: headerHeight, color: navy });

  var headerPad = 16;
  var headerLeftX = contentLeft + headerPad;
  var headerRightX = contentRight - headerPad;
  var headerColWidth = contentWidth / 2 - headerPad * 1.5;

  var hy = contentTop - headerPad - 14;
  drawFitLeft(seller.companyName.toUpperCase(), headerLeftX, hy, headerColWidth, 17, fontBold, white);
  hy -= 16;
  drawFitLeft(seller.address, headerLeftX, hy, headerColWidth, 8.5, font, headerMuted);
  hy -= 12;
  drawFitLeft('PAN: ' + seller.pan + '  |  SAC: ' + seller.sacCode, headerLeftX, hy, headerColWidth, 8.5, font, headerMuted);

  var hyR = contentTop - headerPad - 14;
  drawFitRight(isAmendedInvoice ? 'AMENDED TAX INVOICE' : 'TAX INVOICE', headerRightX, hyR, headerColWidth, 17, fontBold, white);
  hyR -= 16;
  drawFitRight('Invoice No: ' + (transaction.invoiceNumber || 'N/A'), headerRightX, hyR, headerColWidth, 9, font, headerMuted);
  hyR -= 12;
  drawFitRight('Date: ' + formatIstReceiptTimestamp(transaction.paidAt || transaction.createdAt), headerRightX, hyR, headerColWidth, 9, font, headerMuted);
  hyR -= 12;
  drawFitRight('Payment Txn ID: ' + (transaction.paymentId || transaction.transactionId || 'N/A'), headerRightX, hyR, headerColWidth, 9, font, headerMuted);

  var cursorY = headerBottom - 26;

  // ---------- Billed To / Supply Details box ----------
  var boxHeight = 96;
  var boxBottom = cursorY - boxHeight;
  page.drawRectangle({ x: contentLeft, y: boxBottom, width: contentWidth, height: boxHeight, color: lightBg, borderColor: grayBorder, borderWidth: 1 });

  var boxPad = 14;
  var colGap = 16;
  var colWidth = (contentWidth - boxPad * 2 - colGap) / 2;
  var colLeftX = contentLeft + boxPad;
  var colRightX = contentLeft + boxPad + colWidth + colGap;

  var by = cursorY - boxPad - 9;
  drawLeft('BILLED TO', colLeftX, by, 8.5, fontBold, mutedText);
  by -= 15;
  drawFitLeft(billing.name || 'Guest User', colLeftX, by, colWidth, 11, fontBold, darkText);
  by -= 14;
  drawFitLeft(billing.email || 'no-email-provided', colLeftX, by, colWidth, 9.5, font, darkText);
  by -= 14;
  drawFitLeft((billing.state ? billing.state + ', ' : '') + (billing.country || 'India'), colLeftX, by, colWidth, 9.5, font, darkText);

  var byR = cursorY - boxPad - 9;
  drawLeft('SUPPLY DETAILS', colRightX, byR, 8.5, fontBold, mutedText);
  byR -= 15;
  drawFitLeft('Place of Supply: ' + placeOfSupplyLabel, colRightX, byR, colWidth, 9.5, font, darkText);
  byR -= 14;
  drawFitLeft('Customer GSTIN: ' + (isExportInvoice ? 'Not Applicable (Export)' : (billing.gstin || 'Not Provided / B2C')), colRightX, byR, colWidth, 9.5, font, darkText);
  byR -= 14;
  drawFitLeft('Supply Type: ' + transactionTypeLabel, colRightX, byR, colWidth, 9.5, font, darkText);

  cursorY = boxBottom - 24;

  // ---------- Items table: Description | SAC | Taxable Value | Tax Rate & Head | Tax Amount | Total ----------
  var colDesc = contentWidth * 0.27;
  var colSac = contentWidth * 0.10;
  var colTaxable = contentWidth * 0.16;
  var colRateHead = contentWidth * 0.19;
  var colTaxAmt = contentWidth * 0.14;
  var colTotal = contentWidth - colDesc - colSac - colTaxable - colRateHead - colTaxAmt;

  var c0 = contentLeft;
  var c1 = c0 + colDesc;
  var c2 = c1 + colSac;
  var c3 = c2 + colTaxable;
  var c4 = c3 + colRateHead;
  var c5 = c4 + colTaxAmt;
  var c6 = c5 + colTotal;

  var tableHeaderHeight = 24;
  var tableHeaderBottom = cursorY - tableHeaderHeight;
  page.drawRectangle({ x: contentLeft, y: tableHeaderBottom, width: contentWidth, height: tableHeaderHeight, color: navy });

  var thY = tableHeaderBottom + 8;
  drawFitLeft('Description', c0 + 6, thY, colDesc - 10, 8.5, fontBold, white);
  drawFitLeft('SAC', c1 + 4, thY, colSac - 8, 8.5, fontBold, white);
  drawFitRight('Taxable Value', c3 - 6, thY, colTaxable - 10, 8.5, fontBold, white);
  drawCenter('Tax Rate & Head', (c3 + c4) / 2, thY, 8.5, fontBold, white);
  drawFitRight('Tax Amount', c5 - 6, thY, colTaxAmt - 10, 8.5, fontBold, white);
  drawFitRight('Total', c6 - 6, thY, colTotal - 10, 8.5, fontBold, white);

  var dataRowHeight = 40;
  var dataRowTop = tableHeaderBottom;
  var dataRowBottom = dataRowTop - dataRowHeight;
  page.drawRectangle({ x: contentLeft, y: dataRowBottom, width: contentWidth, height: dataRowHeight, borderColor: grayBorder, borderWidth: 1, color: white });
  [c1, c2, c3, c4, c5].forEach(function (x) {
    page.drawLine({ start: { x: x, y: dataRowTop }, end: { x: x, y: dataRowBottom }, thickness: 0.75, color: grayBorder });
  });

  // Derived from the actual charged amounts (never re-derived money), so the label
  // shown always matches what cgst/sgst/igst actually add up to on this invoice.
  var rateHeadLines = isExportInvoice
    ? ['Export of Services', '(0% GST - WOPAY)']
    : igstAmount > 0
      ? ['IGST @ ' + gstRatePercent.toFixed(gstRatePercent % 1 === 0 ? 0 : 1) + '%']
      : (cgstAmount > 0 || sgstAmount > 0)
        ? ['CGST @ ' + halfRatePercent.toFixed(halfRatePercent % 1 === 0 ? 0 : 1) + '%', 'SGST @ ' + halfRatePercent.toFixed(halfRatePercent % 1 === 0 ? 0 : 1) + '%']
        : ['No GST'];

  var dRowMidY = dataRowTop - dataRowHeight / 2;
  drawFitLeft(finalPlanTitle, c0 + 6, dRowMidY + 3, colDesc - 10, 10, fontBold, darkText);
  drawFitLeft(seller.sacCode, c1 + 4, dRowMidY, colSac - 8, 9, font, darkText);
  drawFitRight(currencyLabel + formatInvoiceMoney(baseAmount), c3 - 6, dRowMidY, colTaxable - 10, 9.5, font, darkText);
  if (rateHeadLines.length === 2) {
    drawCenter(rateHeadLines[0], (c3 + c4) / 2, dRowMidY + 6, 9, font, darkText);
    drawCenter(rateHeadLines[1], (c3 + c4) / 2, dRowMidY - 6, 9, font, darkText);
  } else {
    drawCenter(rateHeadLines[0], (c3 + c4) / 2, dRowMidY, 9, font, darkText);
  }
  drawFitRight(currencyLabel + formatInvoiceMoney(cgstAmount + sgstAmount + igstAmount), c5 - 6, dRowMidY, colTaxAmt - 10, 9.5, font, darkText);
  drawFitRight(currencyLabel + formatInvoiceMoney(totalPaid), c6 - 6, dRowMidY, colTotal - 10, 9.5, fontBold, darkText);

  cursorY = dataRowBottom - 24;

  // ---------- Summary total block (bottom right) ----------
  var summaryWidth = 220;
  var summaryX = contentRight - summaryWidth;
  var sy = cursorY;
  var summaryLineHeight = 16;

  function summaryLine(label, value, bold, size) {
    drawLeft(label, summaryX, sy, size || 9.5, bold ? fontBold : font, bold ? darkText : mutedText);
    drawRight(value, contentRight, sy, size || 9.5, bold ? fontBold : font, darkText);
    sy -= summaryLineHeight;
  }

  summaryLine('Taxable Value', currencyLabel + formatInvoiceMoney(baseAmount));
  if (cgstAmount > 0) summaryLine('CGST @ ' + halfRatePercent.toFixed(halfRatePercent % 1 === 0 ? 0 : 1) + '%', currencyLabel + formatInvoiceMoney(cgstAmount));
  if (sgstAmount > 0) summaryLine('SGST @ ' + halfRatePercent.toFixed(halfRatePercent % 1 === 0 ? 0 : 1) + '%', currencyLabel + formatInvoiceMoney(sgstAmount));
  if (igstAmount > 0) summaryLine('IGST @ ' + gstRatePercent.toFixed(gstRatePercent % 1 === 0 ? 0 : 1) + '%', currencyLabel + formatInvoiceMoney(igstAmount));
  if (isExportInvoice) summaryLine('GST (Zero-Rated Export)', currencyLabel + '0.00');

  page.drawLine({ start: { x: summaryX, y: sy + 6 }, end: { x: contentRight, y: sy + 6 }, thickness: 1, color: grayBorder });
  sy -= 8;
  summaryLine('TOTAL AMOUNT', currencyLabel + formatInvoiceMoney(totalPaid), true, 12);

  cursorY = sy - 20;

  // ---------- Footer ----------
  page.drawLine({ start: { x: contentLeft, y: cursorY }, end: { x: contentRight, y: cursorY }, thickness: 1, color: grayBorder });
  cursorY -= 24;
  drawCenter('Authorized Signatory', pageWidth / 2, cursorY, 10, fontBold, darkText);
  cursorY -= 14;
  drawCenter(seller.proprietorName, pageWidth / 2, cursorY, 9, font, mutedText);
  cursorY -= 20;
  drawCenter(seller.companyName + ', ' + seller.address, pageWidth / 2, cursorY, 8, font, mutedText);
  cursorY -= 12;
  drawCenter('hello@getreadyjob.com | www.getreadyjob.com', pageWidth / 2, cursorY, 8, font, mutedText);
  cursorY -= 14;
  drawCenter(isExportInvoice
    ? 'Export of services under LUT - zero-rated supply without payment of IGST (WOPAY).'
    : 'All prices are inclusive of GST where applicable.', pageWidth / 2, cursorY, 7.5, font, mutedText);
  cursorY -= 12;
  drawCenter('This is a computer-generated invoice and does not require a physical signature.', pageWidth / 2, cursorY, 7.5, font, mutedText);

  var pdfBytes = await pdfDoc.save();
  return Buffer.from(pdfBytes);
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

// Canonical plan keys the checkout UI actually sends as planId (home_page_v1_1.dart
// widget.selectedPlan): '7Days' | 'Monthly' | 'Yearly' | 'Lifetime' ('Free' is never
// paid/promo-eligible, so it is intentionally excluded from this list).
var PROMO_PLAN_OPTIONS = ['7Days', 'Monthly', 'Yearly', 'Lifetime'];

// Collapses every planId spelling used anywhere in this file (frontend keys, legacy
// admin-catalog ids like "weekly-pass"/"pro-monthly"/"lifetime-pro") onto one token per
// plan tier, so eligibility checks work regardless of which caller's naming is used.
function normalizePlanKey(planId) {
  var key = String(planId || '').trim().toLowerCase().replace(/[\s_]/g, '-');
  if (key === '7days' || key === '7-day' || key === 'weekly-pass' || key === 'short-access') {
    return '7days';
  }
  if (key === 'monthly' || key === 'pro-monthly') {
    return 'monthly';
  }
  if (key === 'yearly' || key === 'annual') {
    return 'yearly';
  }
  if (key === 'lifetime' || key === 'lifetime-pro') {
    return 'lifetime';
  }
  return key;
}

// Keeps only recognized plan tokens so a bad/legacy payload can never silently produce
// an empty array (which means "no restriction / all plans" - the opposite intent).
function normalizeApplicablePlans(rawPlans) {
  if (!Array.isArray(rawPlans)) {
    return [];
  }
  var normalized = [];
  rawPlans.forEach(function (value) {
    var match = PROMO_PLAN_OPTIONS.find(function (option) {
      return normalizePlanKey(option) === normalizePlanKey(value);
    });
    if (match && normalized.indexOf(match) === -1) {
      normalized.push(match);
    }
  });
  return normalized;
}

// Empty/absent applicablePlans = every plan is eligible - the default for promo codes
// created before this feature existed, and for an explicit "All Plans" selection.
function isPlanEligibleForPromo(promo, planId) {
  var applicablePlans = Array.isArray(promo && promo.applicablePlans) ? promo.applicablePlans : [];
  if (applicablePlans.length === 0 || !planId) {
    return true;
  }
  var normalizedPlanId = normalizePlanKey(planId);
  return applicablePlans.some(function (item) {
    return normalizePlanKey(item) === normalizedPlanId;
  });
}

// Pure preview/validation - never mutates usedCount. Safe to call repeatedly while a
// customer types/edits a code at checkout without burning down its redemption limit.
function applyPromoCode(code, amount, currency, planId) {
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
  if (promo.active === false) {
    return { success: false, error: 'This promo code is no longer active.' };
  }
  if (promo.validUntil && new Date(promo.validUntil).getTime() < Date.now()) {
    return { success: false, error: 'Promo code expired.' };
  }
  if (promo.usageLimit && Number(promo.usedCount || 0) >= Number(promo.usageLimit)) {
    return { success: false, error: 'Promo code usage limit reached.' };
  }
  if (!isPlanEligibleForPromo(promo, planId)) {
    return { success: false, error: 'This promo code is not valid for the selected plan.' };
  }
  var baseAmount = Number(amount || 0);
  var discountAmount = 0;
  if (Number(promo.discountPercent || 0) > 0) {
    discountAmount = Math.round(baseAmount * Number(promo.discountPercent || 0) / 100);
  } else if (Number(promo.discountFlat || 0) > 0) {
    // discountFlat is entered by the admin in major currency units (e.g. rupees), but
    // baseAmount here is always minor units (paise/cents), so convert before comparing.
    discountAmount = Math.round(Number(promo.discountFlat || 0) * 100);
  }
  var finalAmount = Math.max(0, baseAmount - discountAmount);
  return { success: true, applied: true, promo: promo, discountAmount: discountAmount, finalAmount: finalAmount, currency: currency || 'INR' };
}

// Redeems (increments usedCount for) a promo code - call this exactly once, only at the
// moment a payment is actually confirmed, never at order-creation/preview time.
function redeemPromoCode(code) {
  var normalizedCode = String(code || '').trim().toUpperCase();
  if (!normalizedCode) {
    return;
  }
  var promo = promoCodes.find(function (item) {
    return String(item.code || '').toUpperCase() === normalizedCode;
  });
  if (!promo) {
    return;
  }
  promo.usedCount = Number(promo.usedCount || 0) + 1;
  persistPromoCodeState();
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

function resolveTaxBreakdown(totalPaidAmount, billing, currency) {
  var gatewayContext = buildGatewayContext(billing, currency);
  var classification = resolveGstClassification(billing);
  var posContext = classification.pos;
  // SEZ supplies stay taxable at 18% IGST even when the gateway context looks non-domestic.
  var isDomestic = gatewayContext.isDomestic || classification.isSez;
  var totalPaid = Number(totalPaidAmount || 0);
  var gstRate = isDomestic ? Number(invoiceTaxConfig.domesticGstRate || 0.18) : Number(invoiceTaxConfig.foreignGstRate || 0);
  var baseAmount = isDomestic ? Number((totalPaid / (1 + gstRate)).toFixed(2)) : totalPaid;
  var gstAmount = isDomestic ? Number((totalPaid - baseAmount).toFixed(2)) : 0;
  var useIgst = isDomestic && (classification.isSez || !posContext.isIntrastate);
  var cgstAmount = isDomestic && !useIgst ? Number((gstAmount / 2).toFixed(2)) : 0;
  var sgstAmount = isDomestic && !useIgst ? Number((gstAmount / 2).toFixed(2)) : 0;
  var igstAmount = isDomestic && useIgst ? Number(gstAmount.toFixed(2)) : 0;
  return {
    country: gatewayContext.country,
    isDomestic: isDomestic,
    currency: gatewayContext.currency,
    provider: gatewayContext.provider,
    baseAmount: baseAmount,
    gstRate: gstRate,
    gstAmount: gstAmount,
    totalAmount: totalPaid,
    cgstAmount: cgstAmount,
    sgstAmount: sgstAmount,
    igstAmount: igstAmount,
    isSez: classification.isSez,
    isExport: classification.isExport,
    transactionType: classification.transactionType,
    gstType: isDomestic ? (useIgst ? 'IGST' : 'CGST + SGST') : 'Export of Services (0% GST)',
    posState: posContext.state || sellerGstProfile.stateName,
    posStateCode: posContext.stateCode || sellerGstProfile.stateCode,
    sellerState: posContext.sellerState || sellerGstProfile.stateName,
    sellerStateCode: posContext.sellerStateCode || sellerGstProfile.stateCode
  };
}

function ensureBackupDir() {
  try {
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }
  } catch (err) {
    console.error('Failed to create backup/persistence directory "' + backupDir + '":', err.message || err);
  }
}

var salesTransactionStatePath = process.env.SALES_TRANSACTIONS_STATE_FILE || path.join(backupDir, 'sales-transactions-state.json');

function readSalesTransactionState() {
  try {
    if (!fs.existsSync(salesTransactionStatePath)) {
      return [];
    }
    var parsed = JSON.parse(fs.readFileSync(salesTransactionStatePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.error('Failed to read sales transaction state:', err.message || err);
    return [];
  }
}

function persistSalesTransactionState() {
  try {
    ensureBackupDir();
    var tempPath = salesTransactionStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(salesTransactions, null, 2), 'utf8');
    fs.renameSync(tempPath, salesTransactionStatePath);
  } catch (err) {
    console.error('Failed to persist sales transaction state:', err.message || err);
  }
}

salesTransactions = readSalesTransactionState();

// Mirrors the frontend's PlanCatalogConfig shape exactly (inr_prices/usd_prices keyed by
// 'Free'/'7Days'/'Monthly'/'Yearly'/'Lifetime') so the admin-configured, GST-inclusive gross
// price is the single source of truth for both the pricing cards and the checkout amount.
var planCatalogStatePath = process.env.PLAN_CATALOG_STATE_FILE || path.join(backupDir, 'plan-catalog-state.json');

var defaultPlanCatalogConfig = {
  inr_prices: { Free: 0, '7Days': 99, Monthly: 149, Yearly: 999, Lifetime: 9999 },
  usd_prices: { Free: 0, '7Days': 2.99, Monthly: 4.99, Yearly: 29.99, Lifetime: 99.99 },
  enabled_tools_by_plan: {},
  user_quotas_by_plan: {}
};

function roundToWholeUnit(value) {
  // Admin price is the final all-in-one gross amount; whole units only, per the
  // "avoid awkward decimal values like .25/.75" requirement.
  return Math.round(Number(value) || 0);
}

function sanitizePlanCatalogPrices(rawPrices, fallback) {
  var out = Object.assign({}, fallback);
  if (rawPrices && typeof rawPrices === 'object') {
    Object.keys(rawPrices).forEach(function (planKey) {
      var numeric = Number(rawPrices[planKey]);
      if (Number.isFinite(numeric) && numeric >= 0) {
        out[planKey] = planKey === 'Free' ? 0 : roundToWholeUnit(numeric);
      }
    });
  }
  return out;
}

function readPlanCatalogState() {
  try {
    if (!fs.existsSync(planCatalogStatePath)) {
      return Object.assign({}, defaultPlanCatalogConfig);
    }
    var parsed = JSON.parse(fs.readFileSync(planCatalogStatePath, 'utf8'));
    return {
      inr_prices: sanitizePlanCatalogPrices(parsed.inr_prices, defaultPlanCatalogConfig.inr_prices),
      usd_prices: sanitizePlanCatalogPrices(parsed.usd_prices, defaultPlanCatalogConfig.usd_prices),
      enabled_tools_by_plan: (parsed.enabled_tools_by_plan && typeof parsed.enabled_tools_by_plan === 'object') ? parsed.enabled_tools_by_plan : {},
      user_quotas_by_plan: (parsed.user_quotas_by_plan && typeof parsed.user_quotas_by_plan === 'object') ? parsed.user_quotas_by_plan : {}
    };
  } catch (err) {
    console.error('Failed to read plan catalog state:', err.message || err);
    return Object.assign({}, defaultPlanCatalogConfig);
  }
}

function persistPlanCatalogState(config) {
  try {
    ensureBackupDir();
    var tempPath = planCatalogStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(config, null, 2), 'utf8');
    fs.renameSync(tempPath, planCatalogStatePath);
  } catch (err) {
    console.error('Failed to persist plan catalog state:', err.message || err);
  }
}

var planCatalogConfig = readPlanCatalogState();

// userAccounts previously had no disk persistence, so it silently reset to empty
// on every cold start/redeploy even though salesTransactions survived - accounts
// looked "missing" for real paying customers. Mirror the same persistence pattern here.
var userAccountStatePath = process.env.USER_ACCOUNTS_STATE_FILE || path.join(backupDir, 'user-accounts-state.json');

function readUserAccountState() {
  try {
    if (!fs.existsSync(userAccountStatePath)) {
      return [];
    }
    var parsed = JSON.parse(fs.readFileSync(userAccountStatePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.error('Failed to read user account state:', err.message || err);
    return [];
  }
}

function persistUserAccountState() {
  try {
    ensureBackupDir();
    var tempPath = userAccountStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(userAccounts, null, 2), 'utf8');
    fs.renameSync(tempPath, userAccountStatePath);
  } catch (err) {
    console.error('Failed to persist user account state:', err.message || err);
  }
}

userAccounts = readUserAccountState();

// promoCodes previously lived in memory only and was wiped on every cold start/redeploy,
// silently disabling every admin-created discount code. Mirror the same persistence pattern.
var promoCodeStatePath = process.env.PROMO_CODES_STATE_FILE || path.join(backupDir, 'promo-codes-state.json');

function readPromoCodeState() {
  try {
    if (!fs.existsSync(promoCodeStatePath)) {
      return [];
    }
    var parsed = JSON.parse(fs.readFileSync(promoCodeStatePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.error('Failed to read promo code state:', err.message || err);
    return [];
  }
}

function persistPromoCodeState() {
  try {
    ensureBackupDir();
    var tempPath = promoCodeStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(promoCodes, null, 2), 'utf8');
    fs.renameSync(tempPath, promoCodeStatePath);
  } catch (err) {
    console.error('Failed to persist promo code state:', err.message || err);
  }
}

promoCodes = readPromoCodeState();

var creditDebitNoteStatePath = process.env.CREDIT_DEBIT_NOTES_STATE_FILE || path.join(backupDir, 'credit-debit-notes-state.json');

function readCreditDebitNoteState() {
  try {
    if (!fs.existsSync(creditDebitNoteStatePath)) {
      return [];
    }
    var parsed = JSON.parse(fs.readFileSync(creditDebitNoteStatePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.error('Failed to read credit/debit note state:', err.message || err);
    return [];
  }
}

function persistCreditDebitNoteState() {
  try {
    ensureBackupDir();
    var tempPath = creditDebitNoteStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(salesCreditDebitNotes, null, 2), 'utf8');
    fs.renameSync(tempPath, creditDebitNoteStatePath);
  } catch (err) {
    console.error('Failed to persist credit/debit note state:', err.message || err);
  }
}

var salesCreditDebitNotes = readCreditDebitNoteState();

var invoiceCounterStatePath = path.join(backupDir, 'invoice-counter-state.json');

function readInvoiceCounterState() {
  try {
    if (!fs.existsSync(invoiceCounterStatePath)) {
      // Manual recovery lever if the ephemeral disk was wiped by a redeploy: set
      // INVOICE_COUNTER_SEED_JSON='{"26-27":150}' in Render env vars to resume instead of restarting at 1.
      var seedRaw = process.env.INVOICE_COUNTER_SEED_JSON || '';
      if (seedRaw) {
        try {
          var seedState = JSON.parse(seedRaw);
          if (seedState && typeof seedState === 'object') {
            return seedState;
          }
        } catch (seedErr) {
          console.error('Invalid INVOICE_COUNTER_SEED_JSON, ignoring:', seedErr.message || seedErr);
        }
      }
      return {};
    }
    var parsed = JSON.parse(fs.readFileSync(invoiceCounterStatePath, 'utf8'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (err) {
    console.error('Failed to read invoice counter state:', err.message || err);
    return {};
  }
}

function persistInvoiceCounterState(state) {
  try {
    ensureBackupDir();
    var tempPath = invoiceCounterStatePath + '.tmp';
    fs.writeFileSync(tempPath, JSON.stringify(state, null, 2), 'utf8');
    fs.renameSync(tempPath, invoiceCounterStatePath);
  } catch (err) {
    console.error('Failed to persist invoice counter state:', err.message || err);
  }
}

function getIndianFinancialYearLabel(istDate) {
  // Indian FY runs April 1 - March 31. Jan-Mar belongs to the FY that started the previous April.
  var calendarYear = istDate.getUTCFullYear();
  var month = istDate.getUTCMonth() + 1;
  var fyStartYear = month >= 4 ? calendarYear : calendarYear - 1;
  var fyEndYear = fyStartYear + 1;
  var two = function (y) { return String(y).slice(-2); };
  return two(fyStartYear) + '-' + two(fyEndYear);
}

// Branded GST document numbering (Rule 46 / Section 34 CGST Act): GRJ/{INV|CN|DN}/FY/0001,
// continuous across the whole Indian Financial Year (Apr 1 - Mar 31) per document series,
// only resetting to 0001 when a new financial year begins. Never resets monthly.
function migrateLegacyInvoiceCounterState(state) {
  if (state && state.__seriesMigrated) {
    return state;
  }
  var migrated = { INV: {}, CN: {}, DN: {}, __seriesMigrated: true };
  Object.keys(state || {}).forEach(function (key) {
    if (typeof state[key] === 'number') {
      // Legacy flat { fyLabel: count } state from the pre-branded-series counter:
      // carry the count forward into the INV series so numbering stays sequential.
      migrated.INV[key] = state[key];
    }
  });
  return migrated;
}

function generateNextDocumentNumber(docType, referenceDate) {
  var date = referenceDate ? new Date(referenceDate) : new Date();
  if (isNaN(date.getTime())) {
    date = new Date();
  }
  var ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  var fyLabel = getIndianFinancialYearLabel(ist);
  var normalizedType = ['INV', 'CN', 'DN'].indexOf(String(docType || '').toUpperCase()) !== -1
    ? String(docType).toUpperCase()
    : 'INV';
  var state = migrateLegacyInvoiceCounterState(readInvoiceCounterState());
  if (!state[normalizedType]) {
    state[normalizedType] = {};
  }
  var nextIndex = Number(state[normalizedType][fyLabel] || 0) + 1;
  state[normalizedType][fyLabel] = nextIndex;
  persistInvoiceCounterState(state);
  return 'GRJ/' + normalizedType + '/' + fyLabel + '/' + String(nextIndex).padStart(4, '0');
}

// Backward-compatible helper: existing call sites requesting a tax invoice number.
function generateNextInvoiceNumber(referenceDate) {
  return generateNextDocumentNumber('INV', referenceDate);
}

// Section 34 CGST Act: tax/amount changes must never modify the original invoice directly;
// they are recorded as a separate Credit Note or Debit Note referencing the original invoice.
function issueCreditOrDebitNote(transaction, docType, payload, adminEmail) {
  var normalizedType = docType === 'CREDIT_NOTE' ? 'CREDIT_NOTE' : 'DEBIT_NOTE';
  var taxBreakdown = (transaction && transaction.taxBreakdown) || {};
  var defaultTaxable = Number(taxBreakdown.baseAmount !== undefined ? taxBreakdown.baseAmount : (transaction.totalAmount || transaction.amount || 0));
  var defaultCgst = Number(taxBreakdown.cgstAmount || 0);
  var defaultSgst = Number(taxBreakdown.sgstAmount || 0);
  var defaultIgst = Number(taxBreakdown.igstAmount || 0);

  var options = payload || {};
  var taxableValue = options.taxableValue !== undefined && options.taxableValue !== null && options.taxableValue !== ''
    ? Number(options.taxableValue) : defaultTaxable;
  var cgstAmount = options.cgstAmount !== undefined && options.cgstAmount !== null && options.cgstAmount !== ''
    ? Number(options.cgstAmount) : defaultCgst;
  var sgstAmount = options.sgstAmount !== undefined && options.sgstAmount !== null && options.sgstAmount !== ''
    ? Number(options.sgstAmount) : defaultSgst;
  var igstAmount = options.igstAmount !== undefined && options.igstAmount !== null && options.igstAmount !== ''
    ? Number(options.igstAmount) : defaultIgst;
  var computedNet = Number((taxableValue + cgstAmount + sgstAmount + igstAmount).toFixed(2));
  var netAmount = options.netAmount !== undefined && options.netAmount !== null && options.netAmount !== ''
    ? Number(options.netAmount) : computedNet;
  var reason = String(options.reason || '').trim() || (normalizedType === 'CREDIT_NOTE' ? 'Refund/adjustment' : 'Additional charge/adjustment');
  var documentNumber = generateNextDocumentNumber(normalizedType === 'CREDIT_NOTE' ? 'CN' : 'DN');

  var note = {
    documentId: 'cdn-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8),
    documentType: normalizedType,
    documentNumber: documentNumber,
    originalTransactionId: transaction.transactionId,
    originalInvoiceNumber: transaction.invoiceNumber,
    originalInvoiceDate: transaction.paidAt || transaction.createdAt,
    reason: reason,
    taxableValue: Number(taxableValue.toFixed(2)),
    cgstAmount: Number(cgstAmount.toFixed(2)),
    sgstAmount: Number(sgstAmount.toFixed(2)),
    igstAmount: Number(igstAmount.toFixed(2)),
    netAmount: Number(netAmount.toFixed(2)),
    billing: transaction.billing || {},
    planName: transaction.planName || '',
    status: 'issued',
    createdAt: new Date().toISOString(),
    createdBy: adminEmail || 'admin'
  };

  salesCreditDebitNotes.push(note);
  persistCreditDebitNoteState();
  return note;
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
    if (IS_TEST_ENV) {
      console.warn('[email-test-fallback] SMTP transporter unavailable for', payload.subject, payload.to);
      return Promise.resolve({ success: true, fallback: true, testFallback: true });
    }
    console.error('[email-error] SMTP transporter unavailable for', payload.subject, payload.to);
    return Promise.resolve({ success: false, fallback: true, error: 'SMTP transporter unavailable' });
  }
  return transport.sendMail(payload)
    .then(function () {
      return { success: true };
    })
    .catch(function (err) {
      console.error('Email dispatch failed:', err && err.message ? err.message : err);
      return { success: false, error: err && err.message ? err.message : 'send failed' };
    });
}

// Dedupe key: paymentId (falls back to transactionId) so webhook + verify-payment never double-send.
var dispatchedPurchaseEmails = {};

async function buildPurchaseWelcomeEmail(transaction) {
  var customerName = (transaction.billing && transaction.billing.name) ? transaction.billing.name : 'Valued Customer';
  var planTitle = resolvePlanTitle(transaction.planId, transaction.planName, Number(transaction.totalAmount || transaction.amount || 0));
  var welcomeBody = 'Dear ' + customerName + ',\n\n' +
    'Welcome to the Get Ready Job family!\n\n' +
    'Thank you so much for choosing us to be a part of your career journey. Your subscription to ' + planTitle + ' is now active, and your official tax invoice is attached to this email.\n\n' +
    'We are constantly working to improve our platform to serve you better. As you start using our tools, we would love to hear your thoughts:\n' +
    '- How is your experience so far?\n' +
    '- Is there any feature or area we can improve for you?\n\n' +
    'Please feel free to reply directly to this email or write to us at hello@getreadyjob.com with your feedback, suggestions, or questions. Your input helps us deliver the best experience possible!\n\n' +
    'Wishing you great success in your career journey!\n\n' +
    'Warm regards,\n' +
    'The Get Ready Job Team\n' +
    'www.getreadyjob.com';

  var invoicePdf = await buildInvoicePdfBuffer(transaction);
  return {
    subject: 'Welcome to Get Ready Job! We\'re thrilled to have you on board.',
    text: welcomeBody,
    attachments: [{ filename: 'invoice-' + transaction.transactionId + '.pdf', content: invoicePdf }]
  };
}

function sendPurchaseEmails(transaction, recipientEmail) {
  var email = String(recipientEmail || (transaction.billing && transaction.billing.email) || '').trim();
  if (!email) {
    console.error('[email-error] no recipient email for transaction', transaction.transactionId);
    return;
  }
  var dedupeKey = transaction.paymentId || transaction.transactionId;
  if (dispatchedPurchaseEmails[dedupeKey]) {
    return;
  }
  dispatchedPurchaseEmails[dedupeKey] = true;

  buildPurchaseWelcomeEmail(transaction).then(function (mail) {
    return dispatchEmail({
      to: email,
      subject: mail.subject,
      text: mail.text,
      attachments: mail.attachments
    });
  }).catch(function (err) {
    console.error('[email-error] failed to build/send purchase email:', err && err.message ? err.message : err);
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
    quotaTotal: 0,
    quotaUsed: 0,
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
    // Only a genuine purchase event (explicit allocateQuota) grants/renews a balance -
    // routine profile touches (login, Google link, etc.) must never reset it.
    if (payload.allocateQuota) {
      user.quotaTotal = payload.allocateQuota.isUnlimited ? 'unlimited' : Number(payload.allocateQuota.total || 0);
      user.quotaUsed = 0;
    } else if (user.quotaTotal === undefined) {
      user.quotaTotal = 0;
      user.quotaUsed = 0;
    }
    if (payload.provider) {
      user.provider = payload.provider;
    }
    if (payload.googleSub) {
      user.googleSub = payload.googleSub;
    }
    if (payload.googlePicture) {
      user.googlePicture = payload.googlePicture;
    }
    if (payload.emailVerified === true) {
      user.emailVerified = true;
    }
    user.updatedAt = new Date().toISOString();
  }
  persistUserAccountState();
  return user;
}

function getUserQuotaSnapshot(user) {
  var total = user && user.quotaTotal !== undefined ? user.quotaTotal : 0;
  var isUnlimited = total === 'unlimited';
  var used = Number((user && user.quotaUsed) || 0);
  var totalNumeric = isUnlimited ? null : Number(total || 0);
  var remaining = isUnlimited ? null : Math.max(0, totalNumeric - used);
  return {
    quotaTotal: isUnlimited ? 'unlimited' : totalNumeric,
    quotaUsed: used,
    quotaRemaining: isUnlimited ? 'unlimited' : remaining,
    quotaIsUnlimited: isUnlimited
  };
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

function getFinancialYearWindowForDate(dateValue) {
  var referenceDate = dateValue ? new Date(dateValue) : new Date();
  if (isNaN(referenceDate.getTime())) {
    referenceDate = new Date();
  }
  var year = referenceDate.getUTCFullYear();
  var month = referenceDate.getUTCMonth() + 1;
  var fyStartYear = month >= 4 ? year : year - 1;
  var start = new Date(Date.UTC(fyStartYear, 3, 1, 0, 0, 0, 0));
  var end = new Date(Date.UTC(fyStartYear + 1, 2, 31, 23, 59, 59, 999));
  return { start: start, end: end };
}

function getDateRangeBounds(range, fromDate, toDate) {
  var now = new Date();
  var normalizedRange = String(range || 'this-month').toLowerCase();
  var start = null;
  var end = null;

  if (normalizedRange === 'custom') {
    if (fromDate) {
      start = new Date(fromDate);
      start.setHours(0, 0, 0, 0);
    }
    if (toDate) {
      end = new Date(toDate);
      end.setHours(23, 59, 59, 999);
    }
  } else if (normalizedRange === 'this-week') {
    var day = now.getDay();
    var diff = day === 0 ? -6 : 1 - day;
    start = new Date(now);
    start.setDate(now.getDate() + diff);
    start.setHours(0, 0, 0, 0);
    end = new Date(now);
    end.setHours(23, 59, 59, 999);
  } else if (normalizedRange === 'this-month') {
    start = new Date(now.getFullYear(), now.getMonth(), 1);
    end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  } else if (normalizedRange === 'this-year') {
    start = new Date(now.getFullYear(), 0, 1);
    end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
  } else if (normalizedRange === 'monthly') {
    start = new Date(now.getFullYear(), now.getMonth(), 1);
    end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  } else if (normalizedRange === 'quarterly') {
    var quarterIndex = Math.floor(now.getMonth() / 3);
    start = new Date(now.getFullYear(), quarterIndex * 3, 1);
    end = new Date(now.getFullYear(), quarterIndex * 3 + 3, 0, 23, 59, 59, 999);
  } else if (normalizedRange === 'financial-year' || normalizedRange === 'fy') {
    start = getFinancialYearWindowForDate(now).start;
    end = getFinancialYearWindowForDate(now).end;
  } else if (normalizedRange === 'previous-year') {
    var previousYearDate = new Date(now.getFullYear() - 1, 3, 1);
    start = new Date(previousYearDate.getFullYear(), 3, 1);
    end = new Date(previousYearDate.getFullYear() + 1, 2, 31, 23, 59, 59, 999);
  } else if (normalizedRange === 'date-range') {
    if (fromDate) {
      start = new Date(fromDate);
      start.setHours(0, 0, 0, 0);
    }
    if (toDate) {
      end = new Date(toDate);
      end.setHours(23, 59, 59, 999);
    }
  }

  if (!start && !end) {
    start = new Date(now.getFullYear(), now.getMonth(), 1);
    end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  }

  return { start: start, end: end };
}

function filterTransactionsByRange(transactions, range, fromDate, toDate) {
  var bounds = getDateRangeBounds(range, fromDate, toDate);
  return (transactions || []).filter(function (item) {
    if (!item) {
      return false;
    }
    var ts = new Date(item.createdAt || item.paidAt || item.updatedAt || Date.now());
    if (isNaN(ts.getTime())) {
      return false;
    }
    if (bounds.start && ts < bounds.start) {
      return false;
    }
    if (bounds.end && ts > bounds.end) {
      return false;
    }
    return true;
  });
}

function filterCreditDebitNotesByRange(notes, range, fromDate, toDate) {
  var bounds = getDateRangeBounds(range, fromDate, toDate);
  return (notes || []).filter(function (item) {
    if (!item) {
      return false;
    }
    var ts = new Date(item.createdAt || Date.now());
    if (isNaN(ts.getTime())) {
      return false;
    }
    if (bounds.start && ts < bounds.start) {
      return false;
    }
    if (bounds.end && ts > bounds.end) {
      return false;
    }
    return true;
  });
}

function getReportRowFromTransaction(transaction) {
  var billing = transaction && transaction.billing ? transaction.billing : {};
  var taxBreakdown = transaction && transaction.taxBreakdown ? transaction.taxBreakdown : {};
  var totalAmount = Number(transaction && (transaction.totalAmount !== undefined ? transaction.totalAmount : transaction.amount) || 0);
  var taxableValue = Number(taxBreakdown.baseAmount !== undefined ? taxBreakdown.baseAmount : totalAmount);
  var cgstAmount = Number(taxBreakdown.cgstAmount || 0);
  var sgstAmount = Number(taxBreakdown.sgstAmount || 0);
  var igstAmount = Number(taxBreakdown.igstAmount || 0);
  var classificationSource = Object.assign({}, billing, {
    gstin: billing.gstin || transaction.gstin || '',
    state: billing.state || transaction.state || '',
    country: billing.country || transaction.country || 'India',
    sez: billing.sez || billing.sezStatus || transaction.sezStatus || transaction.sez || 'NO'
  });
  var classification = resolveGstClassification(classificationSource);
  var gstRatePercent = Number(taxBreakdown.gstRate !== undefined ? taxBreakdown.gstRate : 0.18) * 100;
  var usesIgst = igstAmount > 0 || (cgstAmount === 0 && sgstAmount === 0 && classification.useIgst);
  var planName = String(transaction && transaction.planName ? transaction.planName : (transaction && transaction.planId ? transaction.planId : 'Get Ready Job Subscription')).trim() || 'Get Ready Job Subscription';
  var grossAmount = Number(transaction && transaction.grossAmount !== undefined ? transaction.grossAmount : (transaction && transaction.amount !== undefined ? transaction.amount : totalAmount));
  var discountAmount = Number((transaction && (transaction.discountAmount !== undefined ? transaction.discountAmount : transaction.discount)) || 0);

  return {
    transactionId: transaction && transaction.transactionId ? transaction.transactionId : '',
    invoiceNumber: transaction && transaction.invoiceNumber ? transaction.invoiceNumber : '',
    documentType: 'TAX_INVOICE',
    documentNumber: transaction && transaction.invoiceNumber ? transaction.invoiceNumber : '',
    originalInvoiceReference: '',
    invoiceDate: transaction && (transaction.paidAt || transaction.createdAt) ? new Date(transaction.paidAt || transaction.createdAt).toISOString().slice(0, 10) : '',
    customerName: billing.name || transaction.name || transaction.email || 'Customer',
    planName: planName,
    transactionType: classification.transactionType,
    // GSTR-1 requires a strictly blank GSTIN for B2C rows; never emit a placeholder.
    customerGstin: classification.customerGstin,
    sezStatus: classification.isSez ? 'YES' : 'NO',
    placeOfSupply: classification.pos.state + ' (' + classification.pos.stateCode + ')',
    placeOfSupplyCode: classification.pos.stateCode,
    taxableValue: Number(taxableValue.toFixed(2)),
    cgstRate: usesIgst ? 0 : Number((gstRatePercent / 2).toFixed(2)),
    sgstRate: usesIgst ? 0 : Number((gstRatePercent / 2).toFixed(2)),
    igstRate: usesIgst ? Number(gstRatePercent.toFixed(2)) : 0,
    cgstAmount: Number(cgstAmount.toFixed(2)),
    sgstAmount: Number(sgstAmount.toFixed(2)),
    igstAmount: Number(igstAmount.toFixed(2)),
    totalInvoiceAmount: Number(totalAmount.toFixed(2)),
    orderReference: String((transaction && (transaction.orderId || transaction.receipt || transaction.paymentId)) || ''),
    paymentId: String((transaction && transaction.paymentId) || ''),
    customerEmail: String(billing.email || transaction.email || ''),
    customerPhone: String(billing.mobile || billing.phone || transaction.mobile || ''),
    grossAmount: Number(grossAmount.toFixed(2)),
    discountAmount: Number(discountAmount.toFixed(2)),
    couponCode: String((transaction && (transaction.promoCode || transaction.couponCode)) || ''),
    netPaidAmount: Number(totalAmount.toFixed(2)),
    paymentStatus: transaction && transaction.status ? transaction.status : 'paid',
    accessExpiresAt: String((transaction && transaction.accessExpiresAt) || ''),
    status: transaction && transaction.status ? transaction.status : 'paid',
    billing: billing,
    rawTransaction: transaction
  };
}

function getCreditDebitNoteReportRow(note) {
  var billing = (note && note.billing) || {};
  var classification = resolveGstClassification(billing);
  // Credit notes reduce net GST liability, debit notes add to it - signed so a plain
  // sum of all rows yields the correct net taxable value and net tax per Section 34.
  var sign = note.documentType === 'CREDIT_NOTE' ? -1 : 1;
  var taxableValue = Number(note.taxableValue || 0) * sign;
  var cgstAmount = Number(note.cgstAmount || 0) * sign;
  var sgstAmount = Number(note.sgstAmount || 0) * sign;
  var igstAmount = Number(note.igstAmount || 0) * sign;
  var totalAmount = Number(note.netAmount || 0) * sign;
  var usesIgst = Number(note.igstAmount || 0) > 0 || (Number(note.cgstAmount || 0) === 0 && classification.useIgst);
  var gstRatePercent = 18;

  return {
    transactionId: note.originalTransactionId || '',
    invoiceNumber: note.documentNumber || '',
    documentType: note.documentType,
    documentNumber: note.documentNumber || '',
    originalInvoiceReference: note.originalInvoiceNumber || '',
    invoiceDate: note.createdAt ? new Date(note.createdAt).toISOString().slice(0, 10) : '',
    customerName: billing.name || 'Customer',
    planName: note.planName || '',
    transactionType: classification.transactionType,
    customerGstin: classification.customerGstin,
    sezStatus: classification.isSez ? 'YES' : 'NO',
    placeOfSupply: classification.pos.state + ' (' + classification.pos.stateCode + ')',
    placeOfSupplyCode: classification.pos.stateCode,
    taxableValue: Number(taxableValue.toFixed(2)),
    cgstRate: usesIgst ? 0 : gstRatePercent / 2,
    sgstRate: usesIgst ? 0 : gstRatePercent / 2,
    igstRate: usesIgst ? gstRatePercent : 0,
    cgstAmount: Number(cgstAmount.toFixed(2)),
    sgstAmount: Number(sgstAmount.toFixed(2)),
    igstAmount: Number(igstAmount.toFixed(2)),
    totalInvoiceAmount: Number(totalAmount.toFixed(2)),
    orderReference: note.originalTransactionId || '',
    paymentId: '',
    customerEmail: String(billing.email || ''),
    customerPhone: String(billing.mobile || billing.phone || ''),
    grossAmount: Number(taxableValue.toFixed(2)),
    discountAmount: 0,
    couponCode: '',
    netPaidAmount: Number(totalAmount.toFixed(2)),
    paymentStatus: note.status || 'issued',
    accessExpiresAt: '',
    status: note.status || 'issued',
    billing: billing,
    rawTransaction: note
  };
}

function normalizeSalesReportFilterValue(value) {
  return String(value === null || value === undefined ? '' : value).trim();
}

function matchesSalesReportFilters(transaction, row, filters) {
  var filterValues = filters || {};
  var transactionTypeFilter = normalizeSalesReportFilterValue(filterValues.transactionType).toUpperCase();
  if (transactionTypeFilter && transactionTypeFilter !== 'ALL' && String(row.transactionType || '').toUpperCase() !== transactionTypeFilter) {
    return false;
  }

  var stateFilter = normalizeSalesReportFilterValue(filterValues.state).toLowerCase();
  if (stateFilter) {
    var stateMatchText = [
      String(row.placeOfSupply || ''),
      String((transaction && transaction.billing && transaction.billing.state) || (transaction && transaction.state) || ''),
      String((transaction && transaction.billing && transaction.billing.stateCode) || ''),
      String((transaction && transaction.gstin) || (transaction && transaction.billing && transaction.billing.gstin) || '')
    ].join(' ').toLowerCase();
    if (stateMatchText.indexOf(stateFilter) === -1) {
      return false;
    }
  }

  var gstinFilter = normalizeSalesReportFilterValue(filterValues.gstin).toUpperCase();
  if (gstinFilter) {
    var gstinCandidates = [
      String(row.customerGstin || ''),
      String((transaction && transaction.gstin) || (transaction && transaction.billing && transaction.billing.gstin) || '')
    ].map(function (value) {
      return value.toUpperCase();
    });
    if (!gstinCandidates.some(function (value) { return value === gstinFilter; })) {
      return false;
    }
  }

  var sezFilter = normalizeSalesReportFilterValue(filterValues.sezStatus).toUpperCase();
  if (sezFilter && String(row.sezStatus || '').toUpperCase() !== sezFilter) {
    return false;
  }

  return true;
}

// Rule 4: every paid/captured sale must appear in exports; a missing GSTIN or sync
// flag must never drop a record.
function isCompletedSaleTransaction(transaction) {
  var status = String((transaction && transaction.status) || 'paid').trim().toLowerCase();
  return status === '' || status === 'paid' || status === 'captured' || status === 'completed' ||
    status === 'success' || status === 'settled' || status === 'authorized';
}

function buildSalesReportData(range, fromDate, toDate, filters) {
  var filteredTransactions = filterTransactionsByRange(salesTransactions, range, fromDate, toDate)
    .filter(isCompletedSaleTransaction);
  var filteredNotes = filterCreditDebitNotesByRange(salesCreditDebitNotes, range, fromDate, toDate);
  var rows = [];

  filteredTransactions.forEach(function (transaction) {
    var row = getReportRowFromTransaction(transaction);
    if (matchesSalesReportFilters(transaction, row, filters)) {
      rows.push(row);
    }
  });

  filteredNotes.forEach(function (note) {
    var row = getCreditDebitNoteReportRow(note);
    if (matchesSalesReportFilters(note, row, filters)) {
      rows.push(row);
    }
  });

  var invoiceRows = rows.filter(function (row) { return row.documentType === 'TAX_INVOICE'; });

  var summary = {
    totalTransactions: invoiceRows.length,
    totalRevenue: Number(invoiceRows.reduce(function (sum, row) {
      return sum + Number(row.totalInvoiceAmount || 0);
    }, 0).toFixed(2)),
    totalTaxableValue: Number(invoiceRows.reduce(function (sum, row) {
      return sum + Number(row.taxableValue || 0);
    }, 0).toFixed(2)),
    totalCgstAmount: Number(invoiceRows.reduce(function (sum, row) {
      return sum + Number(row.cgstAmount || 0);
    }, 0).toFixed(2)),
    totalSgstAmount: Number(invoiceRows.reduce(function (sum, row) {
      return sum + Number(row.sgstAmount || 0);
    }, 0).toFixed(2)),
    totalIgstAmount: Number(invoiceRows.reduce(function (sum, row) {
      return sum + Number(row.igstAmount || 0);
    }, 0).toFixed(2)),
    b2bTransactions: invoiceRows.filter(function (row) { return row.transactionType === 'B2B'; }).length,
    b2cTransactions: invoiceRows.filter(function (row) { return row.transactionType === 'B2C'; }).length,
    creditNotesCount: rows.filter(function (row) { return row.documentType === 'CREDIT_NOTE'; }).length,
    debitNotesCount: rows.filter(function (row) { return row.documentType === 'DEBIT_NOTE'; }).length,
    // Net figures fold in Credit/Debit Notes per Section 34 CGST Act (CN reduces, DN adds).
    netTaxableValue: Number(rows.reduce(function (sum, row) {
      return sum + Number(row.taxableValue || 0);
    }, 0).toFixed(2)),
    netCgstAmount: Number(rows.reduce(function (sum, row) {
      return sum + Number(row.cgstAmount || 0);
    }, 0).toFixed(2)),
    netSgstAmount: Number(rows.reduce(function (sum, row) {
      return sum + Number(row.sgstAmount || 0);
    }, 0).toFixed(2)),
    netIgstAmount: Number(rows.reduce(function (sum, row) {
      return sum + Number(row.igstAmount || 0);
    }, 0).toFixed(2)),
    netTotalAmount: Number(rows.reduce(function (sum, row) {
      return sum + Number(row.totalInvoiceAmount || 0);
    }, 0).toFixed(2))
  };

  return {
    range: String(range || 'this-month'),
    fromDate: fromDate || '',
    toDate: toDate || '',
    rows: rows,
    summary: summary
  };
}

// Legacy rows were written before invoice/GSTIN validation existed. These helpers
// identify placeholder data that is structurally valid but not a real invoice/GSTIN.
var DUMMY_GSTIN_FRAGMENTS = ['ABCDE1234F', 'AAAAA0000A', 'ZZZZZ9999Z', 'XXXXX0000X'];

function isDummyGstin(value) {
  var normalized = String(value || '').trim().toUpperCase();
  if (!normalized) {
    return false;
  }
  return DUMMY_GSTIN_FRAGMENTS.some(function (fragment) {
    return normalized.indexOf(fragment) !== -1;
  });
}

function isPlaceholderInvoiceNumber(value) {
  var normalized = String(value || '').trim();
  if (!normalized) {
    return true;
  }
  return /^(plink|pay|order|txn|rcpt)[-_]/i.test(normalized);
}

// Dry-run by default; only writes (after a timestamped backup) when apply is true.
function sanitizeLegacyTransactions(apply) {
  var changes = [];

  var ordered = salesTransactions.slice().sort(function (a, b) {
    return new Date(a.paidAt || a.createdAt || 0) - new Date(b.paidAt || b.createdAt || 0);
  });

  ordered.forEach(function (transaction) {
    var billing = transaction.billing || (transaction.billing = {});
    var change = { transactionId: transaction.transactionId || '', fixes: [] };

    if (isPlaceholderInvoiceNumber(transaction.invoiceNumber)) {
      var replacement = apply
        ? generateNextInvoiceNumber(transaction.paidAt || transaction.createdAt)
        : '<next sequential invoice number>';
      change.fixes.push({
        field: 'invoiceNumber',
        from: transaction.invoiceNumber || '',
        to: replacement
      });
      if (apply) {
        if (!transaction.receipt && transaction.invoiceNumber) {
          transaction.receipt = transaction.invoiceNumber;
        }
        transaction.invoiceNumber = replacement;
      }
    }

    var gstinCandidates = [billing.gstin, transaction.gstin];
    if (gstinCandidates.some(isDummyGstin)) {
      change.fixes.push({
        field: 'customerGstin',
        from: String(billing.gstin || transaction.gstin || ''),
        to: ''
      });
      if (apply) {
        billing.gstin = '';
        transaction.gstin = '';
      }
    }

    if (change.fixes.length > 0) {
      changes.push(change);
    }
  });

  var backupPath = '';
  if (apply && changes.length > 0) {
    try {
      ensureBackupDir();
      backupPath = salesTransactionStatePath + '.pre-sanitize-' + Date.now() + '.bak';
      fs.writeFileSync(backupPath, JSON.stringify(salesTransactions, null, 2));
    } catch (err) {
      console.error('[sanitize] backup failed:', err && err.message ? err.message : err);
    }
    persistSalesTransactionState();
  }

  return {
    applied: Boolean(apply),
    totalTransactions: salesTransactions.length,
    affectedTransactions: changes.length,
    backupPath: backupPath,
    changes: changes
  };
}

function buildTransactionDiagnostics() {
  var timestamps = salesTransactions
    .map(function (t) { return new Date(t.paidAt || t.createdAt || 0).getTime(); })
    .filter(function (n) { return Number.isFinite(n) && n > 0; })
    .sort(function (a, b) { return a - b; });

  var statusCounts = {};
  salesTransactions.forEach(function (t) {
    var key = String(t.status || 'unknown').toLowerCase();
    statusCounts[key] = (statusCounts[key] || 0) + 1;
  });

  return {
    totalTransactions: salesTransactions.length,
    completedTransactions: salesTransactions.filter(isCompletedSaleTransaction).length,
    placeholderInvoiceNumbers: salesTransactions.filter(function (t) {
      return isPlaceholderInvoiceNumber(t.invoiceNumber);
    }).length,
    dummyGstins: salesTransactions.filter(function (t) {
      return isDummyGstin((t.billing && t.billing.gstin) || t.gstin);
    }).length,
    statusCounts: statusCounts,
    earliestTransaction: timestamps.length ? new Date(timestamps[0]).toISOString() : '',
    latestTransaction: timestamps.length ? new Date(timestamps[timestamps.length - 1]).toISOString() : '',
    creditDebitNotes: salesCreditDebitNotes.length,
    storagePath: salesTransactionStatePath,
    // False here means the container filesystem is ephemeral and every redeploy wipes sales data.
    persistentDiskConfigured: Boolean(process.env.PERSISTENT_DATA_DIR),
    storageFileExists: fs.existsSync(salesTransactionStatePath)
  };
}

function escapeCsvValue(rawValue) {
  var value = String(rawValue === null || rawValue === undefined ? '' : rawValue);
  if (/[",\n]/.test(value)) {
    return '"' + value.replace(/"/g, '""') + '"';
  }
  return value;
}

function formatCsvCurrency(value) {
  var numericValue = Number(value || 0);
  return Number.isFinite(numericValue) ? numericValue.toFixed(2) : '0.00';
}

function buildSalesReportCsv(reportPayload) {
  var header = [
    'Document Type',
    'Invoice Number',
    'Original Invoice Reference',
    'Invoice Date',
    'Customer Name',
    'Plan Name',
    'Transaction Type',
    'Customer GSTIN',
    'SEZ Status',
    'Place of Supply',
    'Taxable Value',
    'CGST Amount',
    'SGST Amount',
    'IGST Amount',
    'Total Invoice Amount'
  ];

  var rows = (reportPayload && reportPayload.rows ? reportPayload.rows : []).map(function (row) {
    return [
      row.documentType || 'TAX_INVOICE',
      row.documentNumber || row.invoiceNumber,
      row.originalInvoiceReference || '',
      row.invoiceDate,
      row.customerName,
      row.planName,
      row.transactionType,
      row.customerGstin,
      row.sezStatus,
      row.placeOfSupply,
      formatCsvCurrency(row.taxableValue),
      formatCsvCurrency(row.cgstAmount),
      formatCsvCurrency(row.sgstAmount),
      formatCsvCurrency(row.igstAmount),
      formatCsvCurrency(row.totalInvoiceAmount)
    ].map(escapeCsvValue).join(',');
  });

  return [header.map(escapeCsvValue).join(','), rows.join('\n')].filter(function (line) {
    return line !== '';
  }).join('\n');
}

// Card A export: GSTR-1 filing layout for the CA / GST portal.
function buildGstReportCsv(reportPayload) {
  var header = [
    'Invoice Number',
    'Invoice Date',
    'Customer Name',
    'Customer GSTIN',
    'Place of Supply',
    'Place of Supply Code',
    'Taxable Value',
    'IGST Rate',
    'IGST Amount',
    'CGST Rate',
    'CGST Amount',
    'SGST Rate',
    'SGST Amount',
    'Total Invoice Value',
    'Transaction Type',
    'Document Type',
    'Original Invoice Reference'
  ];

  var rows = (reportPayload && reportPayload.rows ? reportPayload.rows : []).map(function (row) {
    return [
      row.documentNumber || row.invoiceNumber || '',
      row.invoiceDate || '',
      row.customerName || '',
      row.customerGstin || '',
      row.placeOfSupply || '',
      row.placeOfSupplyCode || '',
      formatCsvCurrency(row.taxableValue),
      formatCsvCurrency(row.igstRate),
      formatCsvCurrency(row.igstAmount),
      formatCsvCurrency(row.cgstRate),
      formatCsvCurrency(row.cgstAmount),
      formatCsvCurrency(row.sgstRate),
      formatCsvCurrency(row.sgstAmount),
      formatCsvCurrency(row.totalInvoiceAmount),
      row.transactionType || '',
      row.documentType || 'TAX_INVOICE',
      row.originalInvoiceReference || ''
    ].map(escapeCsvValue).join(',');
  });

  return [header.map(escapeCsvValue).join(','), rows.join('\n')].filter(function (line) {
    return line !== '';
  }).join('\n');
}

// Card B export: internal operations, accounting and order reconciliation.
function buildSalesOrdersCsv(reportPayload) {
  var header = [
    'Order/Payment Ref',
    'Invoice Number',
    'Order Date',
    'Customer Name',
    'Customer Email',
    'Customer Phone',
    'Plan/Item Name',
    'Gross Amount',
    'Discount/Coupon',
    'Net Paid Amount',
    'Payment Gateway Status',
    'Access Duration'
  ];

  var rows = (reportPayload && reportPayload.rows ? reportPayload.rows : [])
    .filter(function (row) { return row.documentType === 'TAX_INVOICE'; })
    .map(function (row) {
      var couponLabel = row.couponCode
        ? row.couponCode + ' (' + formatCsvCurrency(row.discountAmount) + ')'
        : formatCsvCurrency(row.discountAmount);
      return [
        row.orderReference || row.paymentId || '',
        row.invoiceNumber || '',
        row.invoiceDate || '',
        row.customerName || '',
        row.customerEmail || '',
        row.customerPhone || '',
        row.planName || '',
        formatCsvCurrency(row.grossAmount),
        couponLabel,
        formatCsvCurrency(row.netPaidAmount),
        row.paymentStatus || 'paid',
        row.accessExpiresAt || ''
      ].map(escapeCsvValue).join(',');
    });

  return [header.map(escapeCsvValue).join(','), rows.join('\n')].filter(function (line) {
    return line !== '';
  }).join('\n');
}

// Promo code usage & sales report: groups completed transactions by the promo code
// actually redeemed, so admin can see redemptions/plans-sold/revenue/discount per code
// without cross-referencing the raw sales-orders export by hand.
function buildPromoUsageReport(options) {
  var opts = options || {};
  var range = String(opts.range || '').trim().toLowerCase();
  var fromDate = opts.fromDate || '';
  var toDate = opts.toDate || '';

  var redeemedTransactions = salesTransactions.filter(isCompletedSaleTransaction).filter(function (transaction) {
    return String((transaction && (transaction.promoCode || transaction.couponCode)) || '').trim() !== '';
  });

  // No explicit range = full history, so a campaign's revenue is never hidden behind
  // getDateRangeBounds' silent "this month" fallback for unrecognized/empty ranges.
  if (range === 'custom' || fromDate || toDate) {
    redeemedTransactions = filterTransactionsByRange(redeemedTransactions, 'custom', fromDate, toDate);
  } else if (range && range !== 'all' && range !== 'all-time' && range !== 'lifetime') {
    redeemedTransactions = filterTransactionsByRange(redeemedTransactions, range, fromDate, toDate);
  }

  var buckets = {};

  function bucketForCode(code) {
    var key = String(code || '').trim().toUpperCase();
    if (!key) {
      return null;
    }
    if (!buckets[key]) {
      var promo = promoCodes.find(function (item) {
        return String(item.code || '').toUpperCase() === key;
      });
      buckets[key] = {
        code: key,
        description: promo ? (promo.description || '') : '',
        active: promo ? promo.active !== false : false,
        deleted: !promo,
        discountPercent: promo ? Number(promo.discountPercent || 0) : 0,
        discountFlat: promo ? Number(promo.discountFlat || 0) : 0,
        applicablePlans: promo && Array.isArray(promo.applicablePlans) ? promo.applicablePlans.slice() : [],
        usageLimit: promo ? Number(promo.usageLimit || 0) : 0,
        usedCount: promo ? Number(promo.usedCount || 0) : 0,
        createdAt: promo ? (promo.createdAt || '') : '',
        validUntil: promo ? (promo.validUntil || '') : '',
        redemptions: 0,
        plansSold: {},
        grossRevenue: 0,
        discountGiven: 0,
        dateBreakdownMap: {}
      };
    }
    return buckets[key];
  }

  redeemedTransactions.forEach(function (transaction) {
    var bucket = bucketForCode((transaction && (transaction.promoCode || transaction.couponCode)) || '');
    if (!bucket) {
      return;
    }
    var grossValue = Number((transaction.totalAmount !== undefined ? transaction.totalAmount : transaction.amount) || 0);
    var discountValue = Number(transaction.discountAmount || 0);
    var planLabel = String(transaction.planName || transaction.planId || 'Unknown Plan');
    var dayKey = new Date(transaction.paidAt || transaction.createdAt || Date.now()).toISOString().slice(0, 10);

    bucket.redemptions += 1;
    bucket.grossRevenue += grossValue;
    bucket.discountGiven += discountValue;
    bucket.plansSold[planLabel] = (bucket.plansSold[planLabel] || 0) + 1;
    if (!bucket.dateBreakdownMap[dayKey]) {
      bucket.dateBreakdownMap[dayKey] = { date: dayKey, redemptions: 0, grossRevenue: 0, discountGiven: 0 };
    }
    bucket.dateBreakdownMap[dayKey].redemptions += 1;
    bucket.dateBreakdownMap[dayKey].grossRevenue += grossValue;
    bucket.dateBreakdownMap[dayKey].discountGiven += discountValue;
  });

  // List every currently-configured code even with zero redemptions so the admin sees
  // the full campaign roster, not just codes that have already been used.
  promoCodes.forEach(function (promo) {
    bucketForCode(promo.code);
  });

  var report = Object.keys(buckets).map(function (key) {
    var bucket = buckets[key];
    var dateBreakdown = Object.keys(bucket.dateBreakdownMap).sort().map(function (day) {
      var entry = bucket.dateBreakdownMap[day];
      return {
        date: entry.date,
        redemptions: entry.redemptions,
        grossRevenue: Number(entry.grossRevenue.toFixed(2)),
        discountGiven: Number(entry.discountGiven.toFixed(2))
      };
    });
    return {
      code: bucket.code,
      description: bucket.description,
      active: bucket.active,
      deleted: bucket.deleted,
      discountPercent: bucket.discountPercent,
      discountFlat: bucket.discountFlat,
      applicablePlans: bucket.applicablePlans,
      usageLimit: bucket.usageLimit,
      usedCount: bucket.usedCount,
      createdAt: bucket.createdAt,
      validUntil: bucket.validUntil,
      redemptions: bucket.redemptions,
      plansSold: bucket.plansSold,
      grossRevenue: Number(bucket.grossRevenue.toFixed(2)),
      discountGiven: Number(bucket.discountGiven.toFixed(2)),
      dateBreakdown: dateBreakdown
    };
  }).sort(function (a, b) {
    return b.redemptions - a.redemptions || a.code.localeCompare(b.code);
  });

  var totals = report.reduce(function (acc, row) {
    acc.totalRedemptions += row.redemptions;
    acc.totalGrossRevenue += row.grossRevenue;
    acc.totalDiscountGiven += row.discountGiven;
    return acc;
  }, { totalRedemptions: 0, totalGrossRevenue: 0, totalDiscountGiven: 0 });
  totals.totalGrossRevenue = Number(totals.totalGrossRevenue.toFixed(2));
  totals.totalDiscountGiven = Number(totals.totalDiscountGiven.toFixed(2));

  return {
    generatedAt: new Date().toISOString(),
    range: range || 'all',
    fromDate: fromDate,
    toDate: toDate,
    totals: totals,
    report: report
  };
}

function buildPromoUsageReportCsv(reportPayload) {
  var header = [
    'Promo Code',
    'Status',
    'Description',
    'Applicable Plans',
    'Discount',
    'Total Redemptions',
    'Usage Limit',
    'Plans Sold Breakdown',
    'Total Gross Revenue',
    'Total Discount Given',
    'Valid Until'
  ];

  var rows = (reportPayload && reportPayload.report ? reportPayload.report : []).map(function (row) {
    var discountLabel = row.discountPercent > 0
      ? row.discountPercent + '%'
      : (row.discountFlat > 0 ? formatCsvCurrency(row.discountFlat) : '0');
    var plansLabel = row.applicablePlans && row.applicablePlans.length ? row.applicablePlans.join('; ') : 'All Plans';
    var plansSoldLabel = Object.keys(row.plansSold || {}).map(function (plan) {
      return plan + ': ' + row.plansSold[plan];
    }).join('; ');
    return [
      row.code,
      row.deleted ? 'Deleted' : (row.active ? 'Active' : 'Inactive'),
      row.description || '',
      plansLabel,
      discountLabel,
      row.redemptions,
      row.usageLimit > 0 ? row.usageLimit : 'Unlimited',
      plansSoldLabel,
      formatCsvCurrency(row.grossRevenue),
      formatCsvCurrency(row.discountGiven),
      row.validUntil || ''
    ].map(escapeCsvValue).join(',');
  });

  return [header.map(escapeCsvValue).join(','), rows.join('\n')].filter(function (line) {
    return line !== '';
  }).join('\n');
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

function getAdminTokenLifetimeSeconds() {
  var configuredMinutes = parseInt(process.env.ADMIN_TOKEN_EXPIRY_MINUTES || '10080', 10);
  var safeMinutes = configuredMinutes && configuredMinutes > 0 ? configuredMinutes : 10080;
  return Math.max(7 * 24 * 60 * 60, safeMinutes * 60);
}

var IS_TEST_ENV = String(process.env.NODE_ENV || '').toLowerCase() === 'test' ||
  (Array.isArray(process.argv) && process.argv.some(function (arg) {
    var value = String(arg || '').trim();
    return value.indexOf('--test') !== -1 || value.indexOf('node:test') !== -1;
  })) ||
  (Array.isArray(process.execArgv) && process.execArgv.some(function (arg) {
    var value = String(arg || '').trim();
    return value.indexOf('--test') !== -1 || value.indexOf('node:test') !== -1;
  }));

// Render (and most PaaS hosts) set these automatically; NODE_ENV=production is the generic signal.
var IS_PRODUCTION_RUNTIME = !IS_TEST_ENV && (
  String(process.env.NODE_ENV || '').toLowerCase() === 'production' ||
  Boolean(process.env.RENDER) ||
  Boolean(process.env.RENDER_SERVICE_ID)
);

var WEAK_ADMIN_JWT_SECRETS = ['dev-secret', 'secret', 'changeme', 'change-me', 'password', 'admin', ''];

function resolveAdminJwtSecret() {
  var configured = String(process.env.ADMIN_JWT_SECRET || '').trim();
  if (IS_PRODUCTION_RUNTIME && WEAK_ADMIN_JWT_SECRETS.indexOf(configured.toLowerCase()) !== -1) {
    console.error('[fatal] ADMIN_JWT_SECRET is missing or set to a well-known default in a production runtime. ' +
      'Set a strong, random ADMIN_JWT_SECRET environment variable before starting the server. Refusing to start.');
    process.exit(1);
  }
  return configured || 'dev-secret';
}

var ADMIN_CONFIG = {
  email: adminPrimaryEmail,
  allowedEmails: adminAllowedEmails,
  passwordHash: process.env.ADMIN_PASSWORD_HASH || adminAuth.hashPassword(process.env.ADMIN_PASSWORD || 'Admin@2026!'),
  jwtSecret: resolveAdminJwtSecret(),
  tokenExpiryMinutes: Math.max(10080, parseInt(process.env.ADMIN_TOKEN_EXPIRY_MINUTES || '10080', 10) || 10080),
  rateLimitMaxAttempts: parseInt(process.env.ADMIN_LOGIN_RATE_LIMIT_MAX || '5', 10),
  rateLimitWindowMs: parseInt(process.env.ADMIN_LOGIN_RATE_LIMIT_WINDOW_MS || '900000', 10),
  requireTwoFactor: parseBooleanEnv(process.env.ADMIN_2FA_REQUIRED || 'true'),
  twoFactorEnabled: parseBooleanEnv(process.env.ADMIN_2FA_ENABLED || (process.env.ADMIN_2FA_SECRET ? 'true' : 'false')),
  twoFactorSecret: String(process.env.ADMIN_2FA_SECRET || '').trim(),
  twoFactorChallengeTtlSec: parseInt(process.env.ADMIN_2FA_CHALLENGE_TTL_SEC || '300', 10),
  twoFactorMaxAttempts: parseInt(process.env.ADMIN_2FA_MAX_ATTEMPTS || '6', 10)
};

var ADMIN_EMAIL_OTP_TARGET = String(process.env.ADMIN_EMAIL_OTP_TARGET || 'RAJESH.KHOLA@GMAIL.COM').trim();
var ADMIN_EMAIL_OTP_TARGET_NORMALIZED = normalizeEmailValue(ADMIN_EMAIL_OTP_TARGET);

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

function createEmailOtpCode() {
  return String(Math.floor(Math.random() * 1000000)).padStart(6, '0');
}

function hashEmailOtp(challengeToken, otpCode) {
  return crypto
    .createHash('sha256')
    .update(String(challengeToken || '') + '|' + String(otpCode || '') + '|' + ADMIN_CONFIG.jwtSecret)
    .digest('hex');
}

function maskEmailAddress(email) {
  var raw = String(email || '').trim();
  var parts = raw.split('@');
  if (parts.length !== 2) {
    return raw;
  }
  var local = parts[0];
  var domain = parts[1];
  if (local.length <= 2) {
    return local.charAt(0) + '***@' + domain;
  }
  return local.charAt(0) + '***' + local.charAt(local.length - 1) + '@' + domain;
}

async function createAndSendAdminEmailOtpChallenge(authEmail) {
  cleanupExpiredTwoFactorChallenges();

  var token = crypto.randomBytes(24).toString('hex');
  var otpCode = createEmailOtpCode();
  var now = Date.now();
  var ttlSec = Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec);

  var emailDispatched = await dispatchEmail({
    to: ADMIN_EMAIL_OTP_TARGET,
    subject: 'GETREADYJOB Admin Login OTP',
    text:
      'Your GETREADYJOB admin login OTP is: ' + otpCode + '\n\n' +
      'This OTP is valid for 5 minutes. Do not share this code with anyone.'
  });

  if (!emailDispatched || emailDispatched.success !== true) {
    return { success: false, error: emailDispatched && emailDispatched.error ? emailDispatched.error : 'OTP delivery failed' };
  }

  adminTwoFactorChallenges[token] = {
    type: 'email-otp',
    email: String(authEmail || '').toLowerCase(),
    otpTargetEmail: ADMIN_EMAIL_OTP_TARGET_NORMALIZED,
    otpHash: hashEmailOtp(token, otpCode),
    createdAt: now,
    expiresAt: now + ttlSec * 1000,
    attempts: 0
  };

  var payload = {
    challengeToken: token,
    challengeExpiresInSec: ttlSec,
    deliveryEmail: maskEmailAddress(ADMIN_EMAIL_OTP_TARGET)
  };
  if (IS_TEST_ENV) {
    payload.otpPreview = otpCode;
  }
  return payload;
}

async function resendAdminEmailOtpChallenge(challenge) {
  var token = String(challenge && challenge.token ? challenge.token : '');
  if (!token) {
    return { success: false };
  }

  var otpCode = createEmailOtpCode();
  var ttlSec = Math.max(60, ADMIN_CONFIG.twoFactorChallengeTtlSec);
  var nextOtpHash = hashEmailOtp(token, otpCode);

  var emailDispatched = await dispatchEmail({
    to: ADMIN_EMAIL_OTP_TARGET,
    subject: 'GETREADYJOB Admin Login OTP (Resent)',
    text:
      'Your new GETREADYJOB admin login OTP is: ' + otpCode + '\n\n' +
      'This OTP is valid for 5 minutes. Use only the latest OTP.'
  });

  if (!emailDispatched || emailDispatched.success !== true) {
    return {
      success: false,
      error: emailDispatched && emailDispatched.error ? emailDispatched.error : 'OTP resend delivery failed'
    };
  }

  challenge.otpHash = nextOtpHash;
  challenge.createdAt = Date.now();
  challenge.expiresAt = challenge.createdAt + ttlSec * 1000;

  var payload = {
    success: true,
    challengeExpiresInSec: ttlSec,
    deliveryEmail: maskEmailAddress(ADMIN_EMAIL_OTP_TARGET)
  };
  if (IS_TEST_ENV) {
    payload.otpPreview = otpCode;
  }
  return payload;
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

// Guard against trailing newlines/whitespace pasted into Render env vars.
process.env.RAZORPAY_KEY_ID = (process.env.RAZORPAY_KEY_ID || '').trim();
process.env.RAZORPAY_KEY_SECRET = (process.env.RAZORPAY_KEY_SECRET || '').trim();

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
app.use(express.json({
  verify: function (req, res, buf) {
    req.rawBody = buf;
  }
}));

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
// Express matches only the pathname (query strings like ?grj_renderer=html are ignored),
// so any query parameters on '/' are already served the same clean index.html below.
app.get('/', function (req, res) {
  res.sendFile(path.join(__dirname, 'public', 'index.html'), function (err) {
    if (err && !res.headersSent) {
      console.error('[index-route] failed to serve index.html:', err.message || err);
      res.status(500).send('Unable to load the requested page. Please try again.');
    }
  });
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

  if (!ADMIN_CONFIG.requireTwoFactor) {
    var directExpiry = Math.floor(Date.now() / 1000) + getAdminTokenLifetimeSeconds();
    var directToken = adminAuth.createAdminToken({ email: email, role: 'admin', exp: directExpiry }, ADMIN_CONFIG.jwtSecret);
    return res.json({
      success: true,
      requires2fa: false,
      requireOTP: false,
      token: directToken,
      role: 'admin',
      expiresAt: directExpiry
    });
  }

  var challengePayload = await createAndSendAdminEmailOtpChallenge(email);
  if (!challengePayload || challengePayload.success === false) {
    return res.status(503).json({
      success: false,
      error: 'OTP delivery service is unavailable. Please contact support or retry shortly.'
    });
  }

  return res.json({
    success: true,
    requires2fa: true,
    requireOTP: true,
    showQR: false,
    challengeToken: challengePayload.challengeToken,
    challengeExpiresInSec: challengePayload.challengeExpiresInSec,
    deliveryEmail: challengePayload.deliveryEmail,
    otpPreview: challengePayload.otpPreview,
    message: 'A 6-digit OTP has been sent to the configured admin email.'
  });
});

app.post('/api/admin/2fa/verify', function (req, res) {
  var challengeToken = req.body && req.body.challengeToken ? String(req.body.challengeToken).trim() : '';
  var code = req.body && req.body.code ? String(req.body.code).trim() : '';

  var challenge = consumeValidTwoFactorChallenge(challengeToken);
  if (!challenge || challenge.type !== 'email-otp') {
    return res.status(401).json({ success: false, error: '2FA challenge is missing or expired. Please sign in again.' });
  }
  challenge.token = challengeToken;

  if (challenge.attempts >= Math.max(1, ADMIN_CONFIG.twoFactorMaxAttempts)) {
    delete adminTwoFactorChallenges[challengeToken];
    return res.status(429).json({ success: false, error: 'Too many invalid 2FA attempts. Please sign in again.' });
  }

  if (!/^\d{6}$/.test(code)) {
    challenge.attempts += 1;
    return res.status(401).json({ success: false, error: 'Enter a valid 6-digit OTP.' });
  }

  var receivedHash = hashEmailOtp(challengeToken, code);
  if (!timingSafeStringEqual(receivedHash, challenge.otpHash || '')) {
    challenge.attempts += 1;
    return res.status(401).json({ success: false, error: 'Invalid OTP. Please try again.' });
  }

  delete adminTwoFactorChallenges[challengeToken];

  var expiry = Math.floor(Date.now() / 1000) + getAdminTokenLifetimeSeconds();
  var token = adminAuth.createAdminToken({ email: challenge.email, role: 'admin', exp: expiry }, ADMIN_CONFIG.jwtSecret);
  return res.json({ success: true, token: token, role: 'admin', expiresAt: expiry });
});

app.post('/api/admin/2fa/resend', async function (req, res) {
  var challengeToken = req.body && req.body.challengeToken ? String(req.body.challengeToken).trim() : '';
  var challenge = consumeValidTwoFactorChallenge(challengeToken);
  if (!challenge || challenge.type !== 'email-otp') {
    return res.status(401).json({ success: false, error: '2FA challenge is missing or expired. Please sign in again.' });
  }
  challenge.token = challengeToken;

  var resendPayload = await resendAdminEmailOtpChallenge(challenge);
  if (!resendPayload || resendPayload.success === false) {
    return res.status(503).json({
      success: false,
      error: 'OTP delivery service is unavailable. Please contact support or retry shortly.'
    });
  }

  return res.json({
    success: true,
    challengeExpiresInSec: resendPayload.challengeExpiresInSec,
    deliveryEmail: resendPayload.deliveryEmail,
    otpPreview: resendPayload.otpPreview,
    message: 'A fresh OTP has been sent to the configured admin email.'
  });
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

// Public read of the admin-managed, GST-inclusive gross plan prices - the pricing cards
// and checkout both read this so every visitor always sees the admin's live rate.
app.get('/api/public/plan-catalog', function (req, res) {
  res.json({ success: true, catalog: planCatalogConfig });
});

app.post('/api/admin/plan-catalog', requireAdmin, function (req, res) {
  var payload = req.body || {};
  var next = {
    inr_prices: sanitizePlanCatalogPrices(payload.inr_prices, planCatalogConfig.inr_prices),
    usd_prices: sanitizePlanCatalogPrices(payload.usd_prices, planCatalogConfig.usd_prices),
    enabled_tools_by_plan: (payload.enabled_tools_by_plan && typeof payload.enabled_tools_by_plan === 'object')
      ? payload.enabled_tools_by_plan
      : planCatalogConfig.enabled_tools_by_plan,
    user_quotas_by_plan: (payload.user_quotas_by_plan && typeof payload.user_quotas_by_plan === 'object')
      ? payload.user_quotas_by_plan
      : planCatalogConfig.user_quotas_by_plan
  };
  planCatalogConfig = next;
  persistPlanCatalogState(planCatalogConfig);
  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'plan-catalog-updated', {
    inrPrices: next.inr_prices,
    usdPrices: next.usd_prices
  });
  res.json({ success: true, catalog: planCatalogConfig });
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

// Per-purchase quota ledger for a signed-in customer's own account (public, scoped by
// knowing the account email - same trust model as /api/user/account and /api/user/invoice).
app.post('/api/user/quota/consume', function (req, res) {
  var payload = req.body || {};
  var email = String(payload.email || '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required.' });
  }
  var user = userAccounts.find(function (item) {
    return String(item.email || '').toLowerCase() === email;
  });
  if (!user) {
    return res.status(404).json({ success: false, error: 'User account not found.' });
  }
  var snapshot = getUserQuotaSnapshot(user);
  if (!snapshot.quotaIsUnlimited) {
    user.quotaUsed = Number(user.quotaUsed || 0) + 1;
    user.updatedAt = new Date().toISOString();
    persistUserAccountState();
    snapshot = getUserQuotaSnapshot(user);
  }
  res.json({
    success: true,
    quotaTotal: snapshot.quotaTotal,
    quotaUsed: snapshot.quotaUsed,
    quotaRemaining: snapshot.quotaRemaining,
    quotaIsUnlimited: snapshot.quotaIsUnlimited
  });
});

// Preview-by-default reconciliation for accounts that predate quota tracking (like the
// 14-Aug-2026 rajesh.khola@gmail.com purchase) - finds active paid accounts with no quota
// allocation yet and assigns the entitlement their plan/amount already earned.
app.post('/api/admin/users/backfill-quota', requireAdmin, function (req, res) {
  var apply = String((req.query && req.query.apply) || (req.body && req.body.apply) || '').toLowerCase() === 'true';
  var changes = [];

  userAccounts.forEach(function (user) {
    var hasPlan = String(user.planId || '').trim() !== '' || String(user.planName || '').trim() !== '';
    var isActive = String(user.planStatus || '').toLowerCase() === 'active';
    var missingQuota = user.quotaTotal === undefined || user.quotaTotal === null || user.quotaTotal === 0;
    if (!hasPlan || !isActive || !missingQuota) {
      return;
    }

    var relatedTransaction = salesTransactions.filter(function (item) {
      var itemEmail = String((item && (item.email || (item.billing && item.billing.email))) || '').trim().toLowerCase();
      return itemEmail === String(user.email || '').trim().toLowerCase() && item.status === 'paid';
    }).sort(function (a, b) {
      return new Date(b.paidAt || b.createdAt || 0) - new Date(a.paidAt || a.createdAt || 0);
    })[0];

    var amount = Number((relatedTransaction && (relatedTransaction.totalAmount || relatedTransaction.amount)) || 0);
    var entitlement = getQuotaEntitlementForPlan(user.planId, user.planName, amount);

    changes.push({
      email: user.email,
      planId: user.planId,
      planName: user.planName,
      quotaTotalBefore: user.quotaTotal,
      quotaTotalAfter: entitlement.isUnlimited ? 'unlimited' : entitlement.total
    });

    if (apply) {
      user.quotaTotal = entitlement.isUnlimited ? 'unlimited' : entitlement.total;
      user.quotaUsed = 0;
      user.updatedAt = new Date().toISOString();
    }
  });

  if (apply && changes.length > 0) {
    persistUserAccountState();
    logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'user-quota-backfilled', { affected: changes.length });
  }

  res.json({ success: true, applied: apply, affectedAccounts: changes.length, changes: changes });
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
    description: payload.description || '',
    discountPercent: Number(payload.discountPercent || 0),
    discountFlat: Number(payload.discountFlat || 0),
    validUntil: payload.validUntil || '',
    usageLimit: Number(payload.usageLimit || 0),
    usedCount: Number(payload.usedCount || 0),
    active: payload.active !== false,
    applicablePlans: normalizeApplicablePlans(payload.applicablePlans),
    createdAt: new Date().toISOString()
  };
  entry.code = normalizedCode;
  entry.description = payload.description !== undefined ? payload.description : (entry.description || '');
  entry.discountPercent = Number(payload.discountPercent !== undefined ? payload.discountPercent : (entry.discountPercent || 0));
  entry.discountFlat = Number(payload.discountFlat !== undefined ? payload.discountFlat : (entry.discountFlat || 0));
  entry.validUntil = payload.validUntil !== undefined ? payload.validUntil : (entry.validUntil || '');
  entry.usageLimit = Number(payload.usageLimit !== undefined ? payload.usageLimit : (entry.usageLimit || 0));
  entry.usedCount = Number(payload.usedCount !== undefined ? payload.usedCount : (entry.usedCount || 0));
  entry.active = payload.active !== undefined ? Boolean(payload.active) : (entry.active !== false);
  entry.applicablePlans = payload.applicablePlans !== undefined ? normalizeApplicablePlans(payload.applicablePlans) : (entry.applicablePlans || []);
  entry.updatedAt = new Date().toISOString();
  if (!existing) {
    promoCodes.push(entry);
  }
  persistPromoCodeState();
  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', existing ? 'promo-code-updated' : 'promo-code-created', { code: normalizedCode });
  res.json({ success: true, promo: entry, promos: promoCodes });
});

app.delete('/api/admin/promos/:code', requireAdmin, function (req, res) {
  var normalizedCode = String(req.params.code || '').toUpperCase();
  promoCodes = promoCodes.filter(function (item) {
    return String(item.code || '').toUpperCase() !== normalizedCode;
  });
  persistPromoCodeState();
  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'promo-code-deleted', { code: normalizedCode });
  res.json({ success: true, promos: promoCodes });
});

// Redemptions/plans-sold/revenue/discount per promo code, for the admin "Promo Usage
// Report" dialog and its CSV download - supports the same ?format=csv|json convention
// as the other admin report exports below.
app.get('/api/admin/promos/usage-report', requireAdmin, function (req, res) {
  var reportPayload = buildPromoUsageReport({
    range: req.query.range || '',
    fromDate: req.query.fromDate || '',
    toDate: req.query.toDate || ''
  });

  if (String(req.query.format || 'json').toLowerCase() === 'csv') {
    res.set('Content-Type', 'text/csv; charset=utf-8');
    res.set('Content-Disposition', 'attachment; filename="promo_usage_report_' + Date.now() + '.csv"');
    res.send(buildPromoUsageReportCsv(reportPayload));
    return;
  }

  res.json(Object.assign({ success: true }, reportPayload));
});

// Public, safe-fields-only listing of currently redeemable codes for the checkout
// "Available Offers" selector - excludes internal bookkeeping fields like usedCount/id.
app.get('/api/public/promo-codes', function (req, res) {
  var now = Date.now();
  var planId = req.query.planId || '';
  var offers = promoCodes.filter(function (item) {
    if (item.active === false) {
      return false;
    }
    if (item.validUntil && new Date(item.validUntil).getTime() < now) {
      return false;
    }
    if (item.usageLimit && Number(item.usedCount || 0) >= Number(item.usageLimit)) {
      return false;
    }
    if (planId && !isPlanEligibleForPromo(item, planId)) {
      return false;
    }
    return true;
  }).map(function (item) {
    return {
      code: item.code,
      description: item.description || '',
      discountPercent: Number(item.discountPercent || 0),
      discountFlat: Number(item.discountFlat || 0),
      validUntil: item.validUntil || '',
      applicablePlans: Array.isArray(item.applicablePlans) ? item.applicablePlans : []
    };
  });
  res.json({ success: true, offers: offers });
});

// Pure preview - the canonical endpoint the checkout UI calls; never mutates usedCount.
app.post('/api/public/promo-codes/validate', function (req, res) {
  var payload = req.body || {};
  var promoResult = applyPromoCode(payload.code || '', payload.amount || 0, payload.currency || 'INR', payload.planId || '');
  if (!promoResult.success) {
    return res.status(400).json(promoResult);
  }
  res.json(promoResult);
});

app.post('/api/checkout/apply-promo', function (req, res) {
  var promoResult = applyPromoCode(req.body && req.body.code ? req.body.code : '', req.body && req.body.amount ? req.body.amount : 0, req.body && req.body.currency ? req.body.currency : 'INR', req.body && req.body.planId ? req.body.planId : '');
  if (!promoResult.success) {
    return res.status(400).json(promoResult);
  }
  res.json(promoResult);
});

app.post('/api/validate-promo', function (req, res) {
  var payload = req.body || {};
  var promoResult = applyPromoCode(payload.code || '', payload.amount || 0, payload.currency || 'INR', payload.planId || '');
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

app.get('/api/admin/sales-report', requireAdmin, function (req, res) {
  var range = String(req.query.range || 'financial-year');
  var fromDate = req.query.fromDate || '';
  var toDate = req.query.toDate || '';
  var filters = {
    transactionType: req.query.transactionType || '',
    state: req.query.state || '',
    gstin: req.query.gstin || '',
    sezStatus: req.query.sezStatus || ''
  };
  var report = buildSalesReportData(range, fromDate, toDate, filters);
  res.json({ success: true, range: report.range, fromDate: report.fromDate, toDate: report.toDate, summary: report.summary, rows: report.rows });
});

app.get('/api/admin/sales-report/export', requireAdmin, function (req, res) {
  var range = String(req.query.range || 'financial-year');
  var fromDate = req.query.fromDate || '';
  var toDate = req.query.toDate || '';
  var format = String(req.query.format || 'csv').toLowerCase();
  var filters = {
    transactionType: req.query.transactionType || '',
    state: req.query.state || '',
    gstin: req.query.gstin || '',
    sezStatus: req.query.sezStatus || ''
  };
  var report = buildSalesReportData(range, fromDate, toDate, filters);

  if (format === 'json') {
    res.json({ success: true, report: report });
    return;
  }

  var csvContent = buildSalesReportCsv(report);
  res.set('Content-Type', 'text/csv; charset=utf-8');
  res.set('Content-Disposition', 'attachment; filename="jobready_sales_report_' + encodeURIComponent(range) + '.csv"');
  res.send(csvContent);
});

function readSalesReportRequest(req) {
  return {
    range: String(req.query.range || 'financial-year'),
    fromDate: req.query.fromDate || '',
    toDate: req.query.toDate || '',
    filters: {
      transactionType: req.query.transactionType || '',
      state: req.query.state || '',
      gstin: req.query.gstin || '',
      sezStatus: req.query.sezStatus || ''
    }
  };
}

// Card A: GST Report (GSTR-1 ready) for tax filing.
app.get('/api/admin/transactions/diagnostics', requireAdmin, function (req, res) {
  var diagnostics = buildTransactionDiagnostics();
  var request = readSalesReportRequest(req);
  var report = buildSalesReportData(request.range, request.fromDate, request.toDate, request.filters);
  diagnostics.rowsInSelectedRange = report.rows.length;
  diagnostics.selectedRange = request.range;
  res.json({ success: true, diagnostics: diagnostics });
});

app.post('/api/admin/transactions/sanitize', requireAdmin, function (req, res) {
  var apply = String((req.query && req.query.apply) || (req.body && req.body.apply) || '').toLowerCase() === 'true';
  var result = sanitizeLegacyTransactions(apply);
  if (apply) {
    logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'transactions-sanitized', {
      affected: result.affectedTransactions,
      backupPath: result.backupPath
    });
  }
  res.json({ success: true, result: result });
});

app.get('/api/admin/gst-report/export', requireAdmin, function (req, res) {
  var request = readSalesReportRequest(req);
  var report = buildSalesReportData(request.range, request.fromDate, request.toDate, request.filters);

  if (String(req.query.format || 'csv').toLowerCase() === 'json') {
    res.json({ success: true, report: report });
    return;
  }

  res.set('Content-Type', 'text/csv; charset=utf-8');
  res.set('Content-Disposition', 'attachment; filename="GSTR1_Report_' + encodeURIComponent(request.range) + '.csv"');
  res.send(buildGstReportCsv(report));
});

// Card B: Sales & Orders report for internal reconciliation.
app.get('/api/admin/sales-orders-report/export', requireAdmin, function (req, res) {
  var request = readSalesReportRequest(req);
  var report = buildSalesReportData(request.range, request.fromDate, request.toDate, request.filters);

  if (String(req.query.format || 'csv').toLowerCase() === 'json') {
    res.json({ success: true, report: report });
    return;
  }

  res.set('Content-Type', 'text/csv; charset=utf-8');
  res.set('Content-Disposition', 'attachment; filename="Sales_Orders_Report_' + encodeURIComponent(request.range) + '.csv"');
  res.send(buildSalesOrdersCsv(report));
});

app.get('/api/admin/invoices/search', requireAdmin, function (req, res) {
  var queryValue = String(req.query.query || req.query.q || '').trim().toLowerCase();
  if (!queryValue) {
    return res.json({ success: true, invoices: [], query: queryValue });
  }

  var matches = salesTransactions.filter(function (item) {
    if (!item) {
      return false;
    }
    var searchText = [
      item.transactionId,
      item.invoiceNumber,
      item.paymentId,
      item.email,
      item.company,
      item.gstin,
      item.state,
      item.billing && item.billing.name,
      item.billing && item.billing.email,
      item.billing && item.billing.gstin,
      item.billing && item.billing.company,
      item.orderId
    ].join(' ').toLowerCase();
    return searchText.indexOf(queryValue) !== -1;
  }).slice(0, 50).map(function (item) {
    return {
      transactionId: item.transactionId,
      invoiceNumber: item.invoiceNumber,
      orderId: item.orderId,
      paymentId: item.paymentId,
      status: item.status || 'paid',
      amount: item.totalAmount || item.amount || 0,
      customerName: (item.billing && item.billing.name) || item.company || 'Customer',
      companyName: (item.billing && item.billing.company) || item.company || '',
      gstin: (item.billing && item.billing.gstin) || item.gstin || '',
      state: (item.billing && item.billing.state) || item.state || '',
      email: (item.billing && item.billing.email) || item.email || '',
      createdAt: item.createdAt || item.paidAt || '',
      invoiceUrl: '/api/user/invoice/' + item.transactionId
    };
  });

  res.json({ success: true, invoices: matches, query: queryValue });
});

app.patch('/api/admin/invoices/:transactionId/amend', requireAdmin, function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }

  var payload = req.body || {};
  var billing = Object.assign({}, transaction.billing || {});
  var previousValues = {
    name: billing.name || '',
    company: billing.company || '',
    gstin: billing.gstin || '',
    state: billing.state || '',
    email: billing.email || '',
    mobile: billing.mobile || '',
    sez: billing.sez || 'NO'
  };

  billing.name = payload.customerName || payload.name || billing.name || '';
  billing.company = payload.companyName || payload.company || billing.company || '';
  billing.address = payload.address || billing.address || '';
  billing.gstin = payload.gstin || billing.gstin || '';
  billing.state = payload.state || billing.state || '';
  billing.email = payload.email || billing.email || transaction.email || '';
  billing.mobile = payload.mobile || billing.mobile || '';
  if (payload.sez !== undefined && payload.sez !== null && payload.sez !== '') {
    billing.sez = (payload.sez === true || String(payload.sez).trim().toUpperCase() === 'YES') ? 'YES' : 'NO';
  }

  transaction.billing = billing;
  transaction.email = billing.email || transaction.email || '';
  transaction.company = billing.company || transaction.company || '';
  transaction.gstin = billing.gstin || transaction.gstin || '';
  transaction.state = billing.state || transaction.state || '';
  transaction.sez = billing.sez || transaction.sez || 'NO';
  transaction.status = 'amended';
  transaction.amended = true;
  transaction.amendedAt = new Date().toISOString();
  transaction.amendedBy = req.admin && req.admin.email ? req.admin.email : 'admin';
  transaction.amendmentNote = payload.note || 'Customer data updated by admin';
  transaction.amendmentHistory = Array.isArray(transaction.amendmentHistory) ? transaction.amendmentHistory : [];
  transaction.amendmentHistory.push({
    amendedAt: transaction.amendedAt,
    amendedBy: transaction.amendedBy,
    previousValues: previousValues,
    note: transaction.amendmentNote
  });

  persistSalesTransactionState();

  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'invoice-amended', {
    transactionId: transaction.transactionId,
    invoiceNumber: transaction.invoiceNumber,
    customerName: billing.name,
    gstin: billing.gstin,
    state: billing.state,
    previousValues: previousValues
  });

  res.json({ success: true, invoice: transaction, message: 'Invoice amended successfully.' });
});

app.post('/api/admin/invoices/:transactionId/credit-note', requireAdmin, function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }

  var payload = req.body || {};
  var adminEmail = req.admin && req.admin.email ? req.admin.email : 'admin';
  var creditNote = issueCreditOrDebitNote(transaction, 'CREDIT_NOTE', {
    reason: payload.reason,
    taxableValue: payload.creditedTaxableValue !== undefined ? payload.creditedTaxableValue : payload.taxableValue,
    cgstAmount: payload.cgstAmount,
    sgstAmount: payload.sgstAmount,
    igstAmount: payload.igstAmount,
    netAmount: payload.netRefundAmount !== undefined ? payload.netRefundAmount : payload.netAmount
  }, adminEmail);

  logAuditEvent(adminEmail, 'credit-note-issued', {
    transactionId: transaction.transactionId,
    originalInvoiceNumber: transaction.invoiceNumber,
    documentNumber: creditNote.documentNumber,
    netAmount: creditNote.netAmount
  });

  res.json({ success: true, creditNote: creditNote });
});

app.post('/api/admin/invoices/:transactionId/debit-note', requireAdmin, function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }

  var payload = req.body || {};
  var adminEmail = req.admin && req.admin.email ? req.admin.email : 'admin';
  var debitNote = issueCreditOrDebitNote(transaction, 'DEBIT_NOTE', {
    reason: payload.reason,
    taxableValue: payload.differentialTaxableValue !== undefined ? payload.differentialTaxableValue : payload.taxableValue,
    cgstAmount: payload.cgstAmount,
    sgstAmount: payload.sgstAmount,
    igstAmount: payload.igstAmount,
    netAmount: payload.netAdditionalAmount !== undefined ? payload.netAdditionalAmount : payload.netAmount
  }, adminEmail);

  logAuditEvent(adminEmail, 'debit-note-issued', {
    transactionId: transaction.transactionId,
    originalInvoiceNumber: transaction.invoiceNumber,
    documentNumber: debitNote.documentNumber,
    netAmount: debitNote.netAmount
  });

  res.json({ success: true, debitNote: debitNote });
});

app.get('/api/admin/credit-debit-notes', requireAdmin, function (req, res) {
  res.json({ success: true, notes: salesCreditDebitNotes });
});

app.post('/api/admin/invoices/:transactionId/cancel', requireAdmin, function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }

  var reason = String(req.body && req.body.reason ? req.body.reason : 'Cancelled by admin').trim();
  var adminEmail = req.admin && req.admin.email ? req.admin.email : 'admin';
  var creditNote = issueCreditOrDebitNote(transaction, 'CREDIT_NOTE', { reason: reason }, adminEmail);

  transaction.status = 'cancelled';
  transaction.cancelledAt = new Date().toISOString();
  transaction.cancelReason = reason;
  transaction.creditNoteDocumentNumber = creditNote.documentNumber;
  persistSalesTransactionState();

  logAuditEvent(adminEmail, 'invoice-cancelled', {
    transactionId: transaction.transactionId,
    invoiceNumber: transaction.invoiceNumber,
    reason: reason,
    creditNoteDocumentNumber: creditNote.documentNumber
  });

  res.json({ success: true, cancelled: true, invoice: transaction, creditNote: creditNote });
});

app.post('/api/admin/invoices/:transactionId/resend', requireAdmin, async function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }

  var recipientEmail = String(req.body && req.body.email ? req.body.email : ((transaction.billing && transaction.billing.email) || transaction.email || '')).trim();
  if (!recipientEmail) {
    return res.status(400).json({ success: false, error: 'Customer email is required to resend the invoice.' });
  }

  var emailResult = await dispatchEmail({
    to: recipientEmail,
    subject: 'Updated Invoice for ' + (transaction.invoiceNumber || transaction.transactionId),
    text: 'Your updated tax invoice is attached here. Please keep this copy for your records.',
    attachments: [{ filename: 'invoice-' + transaction.transactionId + '.pdf', content: await buildInvoicePdfBuffer(transaction) }]
  });

  if (!emailResult || emailResult.success !== true) {
    return res.status(500).json({ success: false, error: emailResult && emailResult.error ? emailResult.error : 'Invoice email resend failed.' });
  }

  logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'invoice-resend', {
    transactionId: transaction.transactionId,
    invoiceNumber: transaction.invoiceNumber,
    email: recipientEmail
  });

  res.json({ success: true, sent: true, email: recipientEmail, invoice: transaction });
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

// Preview-only: emails the real welcome template + invoice PDF without creating a
// transaction or consuming a number from the live GST invoice series.
app.post('/api/admin/email/send-sample-invoice', requireAdmin, async function (req, res) {
  var payload = req.body || {};
  var to = String(payload.to || '').trim();
  if (!to || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(to)) {
    return res.status(400).json({ success: false, error: 'A valid recipient email address is required.' });
  }

  var billing = {
    name: String(payload.name || 'Valued Customer').trim(),
    email: to,
    mobile: String(payload.mobile || '').trim(),
    country: String(payload.country || 'India').trim(),
    state: String(payload.state || sellerGstProfile.stateName).trim(),
    gstin: String(payload.gstin || '').trim().toUpperCase(),
    sez: String(payload.sez || 'NO').trim().toUpperCase() === 'YES' ? 'YES' : 'NO'
  };

  var amount = Number(payload.amount || 99);
  var taxBreakdown = resolveTaxBreakdown(amount, billing, 'INR');
  var sampleTransaction = {
    transactionId: 'txn-sample-preview',
    invoiceNumber: 'GRJ/INV/SAMPLE-PREVIEW',
    orderId: 'sample-preview',
    paymentId: 'sample-preview',
    planId: String(payload.planId || 'weekly-pass'),
    planName: String(payload.planName || '7 Days Access'),
    amount: amount,
    currency: 'INR',
    totalAmount: taxBreakdown.totalAmount,
    taxBreakdown: taxBreakdown,
    billing: billing,
    email: to,
    status: 'sample',
    createdAt: new Date().toISOString(),
    paidAt: new Date().toISOString()
  };

  try {
    var mail = await buildPurchaseWelcomeEmail(sampleTransaction);
    var result = await dispatchEmail({
      to: to,
      subject: mail.subject,
      text: mail.text,
      attachments: mail.attachments
    });
    logAuditEvent(req.admin && req.admin.email ? req.admin.email : 'admin', 'sample-invoice-email-sent', { to: to });
    res.json({
      success: result && result.success !== false,
      dispatch: result,
      preview: {
        invoiceNumber: sampleTransaction.invoiceNumber,
        transactionType: taxBreakdown.transactionType,
        taxableValue: taxBreakdown.baseAmount,
        cgstAmount: taxBreakdown.cgstAmount,
        sgstAmount: taxBreakdown.sgstAmount,
        igstAmount: taxBreakdown.igstAmount,
        totalAmount: taxBreakdown.totalAmount
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Sample invoice email failed.' });
  }
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
    // No explicit account record, but a paid transaction already proves the plan for
    // this email (e.g. account state was lost to a cold restart before this fix).
    // Rebuild and persist the account from transaction history instead of reporting
    // a false "no plan" state.
    var paidTransactions = salesTransactions.filter(function (item) {
      var itemEmail = String((item && (item.email || (item.billing && item.billing.email))) || '').trim().toLowerCase();
      return itemEmail === email && item.status === 'paid';
    }).sort(function (a, b) {
      return new Date(b.paidAt || b.createdAt || 0) - new Date(a.paidAt || a.createdAt || 0);
    });
    if (paidTransactions.length === 0) {
      return res.status(404).json({ success: false, error: 'User account not found.' });
    }
    var latest = paidTransactions[0];
    var latestBilling = latest.billing || {};
    var latestAmount = Number(latest.totalAmount || latest.amount || 0);
    user = upsertUserAccount({
      email: email,
      name: latestBilling.name || '',
      company: latest.company || latestBilling.company || '',
      mobile: latestBilling.mobile || '',
      country: latest.country || latestBilling.country || 'India',
      gstin: latest.gstin || latestBilling.gstin || '',
      planId: latest.planId,
      planName: latest.planName,
      planStatus: 'active',
      accessExpiresAt: getPlanAccessExpiry(latest.planId, latest.planName, latestAmount),
      allocateQuota: getQuotaEntitlementForPlan(latest.planId, latest.planName, latestAmount)
    });
  }
  res.json({ success: true, user: Object.assign({}, user, getUserQuotaSnapshot(user)) });
});

app.get('/api/user/transactions', function (req, res) {
  var email = String(req.query && req.query.email ? req.query.email : '').trim().toLowerCase();
  var userId = String(req.query && req.query.userId ? req.query.userId : '').trim();
  if (!email && !userId) {
    return res.status(400).json({ success: false, error: 'Email or userId is required.' });
  }

  var transactions = salesTransactions.filter(function (item) {
    if (!item) {
      return false;
    }
    if (userId && String(item.userId || item.user_id || '').trim() === userId) {
      return true;
    }
    var normalizedEmail = String(item.email || item.userEmail || (item.billing && item.billing.email) || '').trim().toLowerCase();
    if (email && normalizedEmail === email) {
      return true;
    }
    if (item.billing && item.billing.email) {
      return String(item.billing.email).trim().toLowerCase() === email;
    }
    return false;
  });

  var payload = transactions.map(function (item) {
    var billing = item.billing || {};
    return {
      transactionId: item.transactionId,
      invoiceNumber: item.invoiceNumber,
      orderId: item.orderId,
      paymentId: item.paymentId,
      planId: item.planId,
      planName: item.planName,
      amount: item.amount,
      totalAmount: item.totalAmount,
      currency: item.currency,
      status: item.status || 'paid',
      createdAt: item.createdAt,
      paidAt: item.paidAt,
      email: billing.email || item.email || '',
      gstin: billing.gstin || item.gstin || '',
      company: billing.company || item.company || '',
      state: billing.state || item.state || '',
      invoiceUrl: '/api/user/invoice/' + item.transactionId
    };
  });

  res.json({ success: true, transactions: payload });
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

function getGoogleOAuthClientId() {
  return String(process.env.GOOGLE_OAUTH_CLIENT_ID || '').trim();
}

// Verifies a Google Identity Services ID token server-side via Google's tokeninfo
// endpoint so a client can never simply assert an arbitrary email address.
function verifyGoogleIdToken(idToken) {
  var testTokenPrefix = 'test-mock-token:';
  if (process.env.NODE_ENV === 'test' && idToken.indexOf(testTokenPrefix) === 0) {
    try {
      var decodedClaims = JSON.parse(Buffer.from(idToken.slice(testTokenPrefix.length), 'base64').toString('utf8'));
      return Promise.resolve(decodedClaims);
    } catch (err) {
      return Promise.reject(err);
    }
  }

  return new Promise(function (resolve, reject) {
    var url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken);
    https.get(url, function (response) {
      var body = '';
      response.on('data', function (chunk) { body += chunk; });
      response.on('end', function () {
        if (response.statusCode !== 200) {
          reject(new Error('Google token verification failed with status ' + response.statusCode));
          return;
        }
        try {
          resolve(JSON.parse(body));
        } catch (err) {
          reject(new Error('Invalid response from Google token verification.'));
        }
      });
    }).on('error', reject);
  });
}

app.post('/api/user/google-signin', function (req, res) {
  var payload = req.body || {};
  var idToken = String(payload.id_token || payload.idToken || '').trim();

  if (!idToken) {
    return res.status(400).json({ success: false, error: 'A verified Google id_token is required.' });
  }

  var expectedClientId = getGoogleOAuthClientId();
  if (!expectedClientId) {
    return res.status(503).json({ success: false, error: 'Google Sign-In is not configured on the server yet.' });
  }

  verifyGoogleIdToken(idToken).then(function (claims) {
    if (!claims || claims.aud !== expectedClientId) {
      return res.status(401).json({ success: false, error: 'Google token audience mismatch.' });
    }
    if (String(claims.email_verified) !== 'true') {
      return res.status(401).json({ success: false, error: 'Google account email is not verified.' });
    }

    var email = String(claims.email || '').trim().toLowerCase();
    if (!email) {
      return res.status(400).json({ success: false, error: 'Google token did not include an email.' });
    }

    var user = upsertUserAccount({
      email: email,
      name: claims.name || '',
      company: payload.company || '',
      mobile: payload.mobile || '',
      country: payload.country || 'India',
      planId: payload.planId || '',
      planName: payload.planName || '',
      planStatus: payload.planStatus || 'active',
      accessExpiresAt: payload.accessExpiresAt || null,
      provider: 'google',
      googleSub: claims.sub || '',
      googlePicture: claims.picture || '',
      emailVerified: true
    });

    triggerTransactionalEmail('google-signin', { email: email, userId: user.id, provider: 'google' });
    res.json({ success: true, user: user, provider: 'google', emailVerified: true });
  }).catch(function () {
    res.status(401).json({ success: false, error: 'Google token verification failed.' });
  });
});

app.get('/api/user/invoice/:transactionId', async function (req, res) {
  var transaction = salesTransactions.find(function (item) {
    return String(item.transactionId) === String(req.params.transactionId);
  });
  if (!transaction) {
    return res.status(404).json({ success: false, error: 'Invoice not found.' });
  }
  var pdfBuffer = await buildInvoicePdfBuffer(transaction);
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
  var planName = resolvePlanTitle(planId, plan ? plan.name : (req.body.planName || req.body.planTitle), amount / 100);
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
      receipt: String(receipt),
      name: customerName || '',
      email: customerEmail || '',
      mobile: customerPhone || '',
      company: String(billing.company || '').trim(),
      gstin: String(billing.gstin || '').trim(),
      state: String(billing.state || '').trim(),
      country: String(billing.country || 'India').trim(),
      sez: String(billing.sez || 'NO').trim().toUpperCase()
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
  var planName = resolvePlanTitle(planId, plan ? plan.name : (req.body.planName || req.body.planTitle), amount / 100);
  var localOrderId = 'local-order-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6);
  var promoResult = applyPromoCode(promoCode, amount, currency, planId);
  if (promoCode && promoResult.success !== true) {
    return res.status(400).json({ success: false, error: promoResult.error || 'This promo code could not be applied.' });
  }
  var discountedAmount = promoResult.success && promoResult.applied ? promoResult.finalAmount : amount;
  var gatewayContext = buildGatewayContext(billing, currency);
  var taxBreakdown = resolveTaxBreakdown(discountedAmount, billing, currency);
  var finalAmountMinor = taxBreakdown.totalAmount;
  var normalizedBilling = Object.assign({
    name: '',
    company: '',
    address: '',
    country: 'India',
    state: '',
    gstin: '',
    email: '',
    mobile: ''
  }, billing || {});
  if (!normalizedBilling.state && normalizedBilling.country) {
    normalizedBilling.state = normalizedBilling.country;
  }
  var user = upsertUserAccount({
    email: normalizedBilling.email || '',
    name: normalizedBilling.name || '',
    company: normalizedBilling.company || '',
    mobile: normalizedBilling.mobile || '',
    country: normalizedBilling.country || 'India',
    gstin: normalizedBilling.gstin || '',
    planId: planId,
    planName: planName,
    planStatus: 'active',
    accessExpiresAt: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString(),
    allocateQuota: getQuotaEntitlementForPlan(planId, planName, amount / 100)
  });
  triggerTransactionalEmail('welcome', { email: user.email || normalizedBilling.email, userId: user.id, planName: planName });

  var pendingOrderRecord = {
    localOrderId: localOrderId,
    razorpayOrderId: null,
    orderId: localOrderId,
    planId: planId,
    planName: planName,
    amount: finalAmountMinor,
    currency: currency,
    receipt: receipt,
    billing: normalizedBilling,
    taxBreakdown: taxBreakdown,
    userId: user.id,
    promoCode: promoCode,
    promoResult: promoResult,
    gatewayContext: gatewayContext,
    createdAt: new Date().toISOString()
  };
  registerPendingOrder(localOrderId, pendingOrderRecord);

  logAuditEvent(user.email || normalizedBilling.email || 'guest', 'checkout-created', {
    orderId: localOrderId,
    planId: planId,
    amount: finalAmountMinor,
    currency: currency,
    promoCode: promoCode,
    gateway: gatewayContext.provider
  });

  if (!razorpay) {
    if (promoResult.applied) {
      redeemPromoCode(promoCode);
    }
    return res.json({ success: true, order_id: localOrderId, amount: finalAmountMinor, currency: currency, localOnly: true, taxBreakdown: taxBreakdown, gateway: gatewayContext.provider, promo: promoResult });
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

    pendingOrderRecord.razorpayOrderId = order.id;
    pendingOrderRecord.orderId = order.id;
    registerPendingOrder(order.id, pendingOrderRecord);
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

  var pendingOrder = resolvePendingOrder(orderId);
  if (!pendingOrder) {
    return res.status(404).json({ success: false, error: 'Order not found.' });
  }

  var transactionId = 'txn-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  var transaction = {
    transactionId: transactionId,
    invoiceNumber: generateNextInvoiceNumber(),
    orderId: orderId,
    paymentId: paymentId || 'local-' + Date.now(),
    planId: pendingOrder.planId,
    planName: pendingOrder.planName,
    amount: pendingOrder.amount / 100,
    currency: pendingOrder.currency,
    totalAmount: pendingOrder.amount / 100,
    taxBreakdown: pendingOrder.taxBreakdown,
    billing: pendingOrder.billing,
    email: pendingOrder.billing && pendingOrder.billing.email ? pendingOrder.billing.email : '',
    company: pendingOrder.billing && pendingOrder.billing.company ? pendingOrder.billing.company : '',
    gstin: pendingOrder.billing && pendingOrder.billing.gstin ? pendingOrder.billing.gstin : '',
    state: pendingOrder.billing && pendingOrder.billing.state ? pendingOrder.billing.state : '',
    country: pendingOrder.billing && pendingOrder.billing.country ? pendingOrder.billing.country : 'India',
    status: 'paid',
    promoCode: pendingOrder.promoResult && pendingOrder.promoResult.applied ? pendingOrder.promoCode : '',
    discountAmount: pendingOrder.promoResult && pendingOrder.promoResult.applied ? Number(pendingOrder.promoResult.discountAmount || 0) : 0,
    createdAt: new Date().toISOString(),
    paidAt: new Date().toISOString()
  };
  salesTransactions.push(transaction);
  persistSalesTransactionState();
  clearPendingOrder(orderId);
  if (pendingOrder.promoResult && pendingOrder.promoResult.applied) {
    redeemPromoCode(pendingOrder.promoCode);
  }

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
  var verifiedQuotaEntitlement = getQuotaEntitlementForPlan(pendingOrder.planId, pendingOrder.planName, Number(pendingOrder.amount || 0) / 100);
  user.planId = pendingOrder.planId;
  user.planName = pendingOrder.planName;
  user.billingCountry = pendingOrder.billing && pendingOrder.billing.country ? pendingOrder.billing.country : 'India';
  user.gstin = pendingOrder.billing && pendingOrder.billing.gstin ? pendingOrder.billing.gstin : user.gstin;
  user.planStatus = 'active';
  user.accessExpiresAt = new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString();
  user.quotaTotal = verifiedQuotaEntitlement.isUnlimited ? 'unlimited' : verifiedQuotaEntitlement.total;
  user.quotaUsed = 0;
  user.updatedAt = new Date().toISOString();
  var recipientEmail = user.email || (pendingOrder.billing && pendingOrder.billing.email) || '';
  logAuditEvent(recipientEmail || 'guest', 'payment-verified', { transactionId: transaction.transactionId, planId: pendingOrder.planId, amount: pendingOrder.amount });
  triggerTransactionalEmail('receipt', { email: recipientEmail, userId: user.id, transactionId: transaction.transactionId });
  sendPurchaseEmails(transaction, recipientEmail);

  res.json({ success: true, message: 'Payment verified successfully.', transactionId: transaction.transactionId, invoiceUrl: '/api/user/invoice/' + transaction.transactionId });
});

app.post('/api/razorpay-webhook', function (req, res) {
  var webhookSecret = (process.env.RAZORPAY_WEBHOOK_SECRET || '').trim();
  var signature = req.headers['x-razorpay-signature'] || '';

  if (webhookSecret) {
    var expectedSignature = crypto.createHmac('sha256', webhookSecret).update(req.rawBody || Buffer.from(JSON.stringify(req.body || {}))).digest('hex');
    if (!signature || expectedSignature !== signature) {
      console.error('[webhook] rejected Razorpay event: invalid signature');
      return res.status(400).json({ success: false, error: 'Invalid webhook signature.' });
    }
  }

  var event = req.body || {};
  var eventType = String(event.event || '').trim();

  if (['payment.captured', 'order.paid', 'payment_link.paid', 'payment.link.paid'].indexOf(eventType) === -1) {
    return res.status(200).json({ success: true, ignored: true });
  }

  try {
    var paymentEntity = event.payload && event.payload.payment && event.payload.payment.entity ? event.payload.payment.entity : {};
    var orderEntity = event.payload && event.payload.order && event.payload.order.entity ? event.payload.order.entity : {};
    var notes = paymentEntity.notes || orderEntity.notes || {};
    var recipientEmail = String(paymentEntity.email || notes.email || '').trim();
    var orderId = String(paymentEntity.order_id || orderEntity.id || notes.order_id || '').trim();
    var paymentId = String(paymentEntity.id || '').trim();
    var receipt = String(notes.receipt || paymentEntity.receipt || orderEntity.receipt || '').trim();
    var amountPaise = Number(paymentEntity.amount || orderEntity.amount || 0);
    var currency = String(paymentEntity.currency || orderEntity.currency || 'INR').toUpperCase();
    var planId = String(notes.plan_id || notes.planId || (orderEntity.notes && orderEntity.notes.plan_id) || 'weekly-pass').trim() || 'weekly-pass';
    var pendingOrder = resolvePendingOrder(orderId || receipt);
    var fallbackPlanId = String((pendingOrder && pendingOrder.planId) || planId || 'weekly-pass').trim();
    var plan = getPlanById(fallbackPlanId);
    var normalizedAmount = Number((amountPaise || (pendingOrder ? pendingOrder.amount : 0) || 0)) / 100;
    var planName = resolvePlanTitle(fallbackPlanId, (pendingOrder && pendingOrder.planName) || (plan ? plan.name : notes.plan_name), normalizedAmount);
    var billing = normalizeBillingFromPaymentContext(paymentEntity, orderEntity, pendingOrder);
    var razorpayCreatedAt = Number(paymentEntity.created_at || orderEntity.created_at || event.created_at || 0);
    var paymentTimestamp = razorpayCreatedAt > 0 ? new Date(razorpayCreatedAt * 1000).toISOString() : new Date().toISOString();
    if (!billing.email && recipientEmail) billing.email = recipientEmail;
    if (!billing.name && notes.name) billing.name = notes.name;
    if (!billing.country) billing.country = notes.country || 'India';
    if (!billing.state && notes.state) billing.state = notes.state;
    if (!billing.gstin && notes.gstin) billing.gstin = notes.gstin;
    if (!billing.company && notes.company) billing.company = notes.company;
    var taxBreakdown = (pendingOrder && pendingOrder.taxBreakdown) || resolveTaxBreakdown(normalizedAmount, billing, currency);

    var transaction = salesTransactions.find(function (item) {
      if (paymentId && item.paymentId === paymentId) {
        return true;
      }
      if (orderId && item.orderId === orderId) {
        return true;
      }
      return false;
    });

    if (!transaction) {
      transaction = {
        transactionId: 'txn-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8),
        invoiceNumber: generateNextInvoiceNumber(),
        receipt: receipt || '',
        orderId: orderId,
        paymentId: paymentId,
        planId: fallbackPlanId,
        planName: planName,
        amount: normalizedAmount,
        currency: currency,
        totalAmount: Number((taxBreakdown && taxBreakdown.totalAmount !== undefined ? taxBreakdown.totalAmount : normalizedAmount).toFixed(2)),
        taxBreakdown: taxBreakdown,
        billing: billing,
        email: billing.email || recipientEmail || '',
        company: billing.company || '',
        gstin: billing.gstin || '',
        state: billing.state || '',
        country: billing.country || 'India',
        status: 'paid',
        promoCode: pendingOrder && pendingOrder.promoResult && pendingOrder.promoResult.applied ? pendingOrder.promoCode : '',
        discountAmount: pendingOrder && pendingOrder.promoResult && pendingOrder.promoResult.applied ? Number(pendingOrder.promoResult.discountAmount || 0) : 0,
        createdAt: paymentTimestamp,
        paidAt: paymentTimestamp,
        source: 'webhook'
      };

      salesTransactions.push(transaction);
      persistSalesTransactionState();
      if (pendingOrder && orderId) {
        clearPendingOrder(orderId);
      }
      if (pendingOrder && pendingOrder.promoResult && pendingOrder.promoResult.applied) {
        redeemPromoCode(pendingOrder.promoCode);
      }

      var userAccount = upsertUserAccount({
        email: billing.email || recipientEmail || '',
        name: billing.name || '',
        company: billing.company || '',
        mobile: billing.mobile || '',
        country: billing.country || 'India',
        gstin: billing.gstin || '',
        planId: fallbackPlanId,
        planName: planName,
        planStatus: 'active',
        accessExpiresAt: getPlanAccessExpiry(fallbackPlanId, planName, normalizedAmount),
        allocateQuota: getQuotaEntitlementForPlan(fallbackPlanId, planName, normalizedAmount)
      });
      userAccount.planStatus = 'active';
      userAccount.planId = fallbackPlanId;
      userAccount.planName = planName;
      userAccount.accessExpiresAt = getPlanAccessExpiry(fallbackPlanId, planName, normalizedAmount);
      userAccount.updatedAt = new Date().toISOString();

      logAuditEvent(recipientEmail || 'guest', 'payment-webhook-captured', {
        transactionId: transaction.transactionId,
        orderId: orderId,
        paymentId: paymentId,
        eventType: eventType,
        receipt: receipt,
        gstin: billing.gstin || '',
        state: billing.state || ''
      });
      console.log('[webhook] created transaction', transaction.transactionId, transaction.invoiceNumber, paymentId || receipt);
    } else {
      if (receipt && !transaction.receipt) {
        transaction.receipt = receipt;
      }
      // A payment/order reference must never become the tax invoice number.
      if (!transaction.invoiceNumber) {
        transaction.invoiceNumber = generateNextInvoiceNumber(paymentTimestamp);
      }
      transaction.planId = fallbackPlanId;
      transaction.planName = planName;
      transaction.billing = billing;
      transaction.email = billing.email || transaction.email || recipientEmail || '';
      transaction.company = billing.company || transaction.company || '';
      transaction.gstin = billing.gstin || transaction.gstin || '';
      transaction.state = billing.state || transaction.state || '';
      transaction.country = billing.country || transaction.country || 'India';
      transaction.totalAmount = Number((taxBreakdown && taxBreakdown.totalAmount !== undefined ? taxBreakdown.totalAmount : normalizedAmount).toFixed(2));
      transaction.taxBreakdown = taxBreakdown;
      transaction.amount = normalizedAmount;
      transaction.createdAt = paymentTimestamp;
      transaction.paidAt = paymentTimestamp;
      persistSalesTransactionState();
    }

    sendPurchaseEmails(transaction, recipientEmail || (transaction && transaction.email) || '');
  } catch (err) {
    console.error('[webhook] failed to process Razorpay event:', err && err.message ? err.message : err);
  }

  res.status(200).json({ success: true });
});

// ---------------------------------------------------------------------------
// Gemini Flash Voice Command (homepage drop-zone mic button)
// ---------------------------------------------------------------------------
var GEMINI_API_KEY = (process.env.GEMINI_API_KEY || '').trim();
var GEMINI_MODEL = (process.env.GEMINI_MODEL || 'gemini-flash-latest').trim();
var VOICE_COMMAND_MIN_CONFIDENCE = 0.5;

var VOICE_COMMAND_TOOLS = [
  'compress_pdf',
  'pdf_to_word',
  'word_to_pdf',
  'jpg_to_pdf',
  'pdf_to_jpg',
  'merge_pdf',
  'split_pdf',
  'protect_pdf',
  'edit_pdf',
  'csv_to_excel',
  'photo_resizer'
];

var VOICE_COMMAND_SYSTEM_PROMPT =
  'You are a voice command classifier for a document-tools website called GetReadyJob. ' +
  'Listen to the attached short audio clip of a user speaking a command in English or Hindi/Hinglish, ' +
  'and identify which single tool they want to use. Respond with ONLY a strict JSON object (no markdown, ' +
  'no code fences, no extra commentary) matching exactly this shape:\n' +
  '{"tool": "<one of: ' + VOICE_COMMAND_TOOLS.join(', ') + '>", ' +
  '"action": "<short verb phrase, e.g. compress, convert, merge, split, protect, edit, resize>", ' +
  '"parameters": {"target_size_kb": <integer or null>, "preset": "<string or null>"}, ' +
  '"recognized_text": "<the transcribed words you heard>", ' +
  '"confidence": <number between 0 and 1>}\n' +
  'Rules:\n' +
  '- "tool" MUST be exactly one of the allowed values above - pick the closest match, never invent a new value.\n' +
  '- "target_size_kb" is a plain integer number of kilobytes if a size is mentioned (e.g. "50 kb" => 50, ' +
  '"2 mb" => 2048), otherwise null.\n' +
  '- "preset" is a short lowercase id (e.g. "ssc", "upsc", "ibps", "rrb", "jee", "aadhaar") if an exam or ' +
  'portal name is mentioned, otherwise null.\n' +
  '- "confidence" reflects how sure you are of the recognized tool, based on audio clarity and specificity.\n' +
  '- Output raw JSON only, nothing else.';

function callGeminiVoiceCommand(audioBuffer, mimeType) {
  return new Promise(function (resolve, reject) {
    if (!GEMINI_API_KEY) {
      var configErr = new Error('Voice command is not configured on the server yet.');
      configErr.statusCode = 503;
      reject(configErr);
      return;
    }

    var requestBody = JSON.stringify({
      contents: [{
        parts: [
          { text: VOICE_COMMAND_SYSTEM_PROMPT },
          { inlineData: { mimeType: mimeType, data: audioBuffer.toString('base64') } }
        ]
      }],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2
      }
    });

    var options = {
      hostname: 'generativelanguage.googleapis.com',
      path: '/v1beta/models/' + encodeURIComponent(GEMINI_MODEL) + ':generateContent?key=' + encodeURIComponent(GEMINI_API_KEY),
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestBody)
      }
    };

    var request = https.request(options, function (response) {
      var body = '';
      response.on('data', function (chunk) { body += chunk; });
      response.on('end', function () {
        var parsedOuter;
        try {
          parsedOuter = JSON.parse(body);
        } catch (err) {
          var parseErr = new Error('Gemini returned an unreadable response.');
          parseErr.statusCode = 502;
          reject(parseErr);
          return;
        }

        if (response.statusCode === 429) {
          var quotaErr = new Error('Voice command quota exceeded. Please try again in a moment.');
          quotaErr.statusCode = 429;
          reject(quotaErr);
          return;
        }

        if (response.statusCode !== 200) {
          var apiErr = new Error((parsedOuter && parsedOuter.error && parsedOuter.error.message) || ('Gemini request failed with status ' + response.statusCode));
          apiErr.statusCode = 502;
          reject(apiErr);
          return;
        }

        try {
          var candidates = parsedOuter.candidates || [];
          var textPart = candidates[0] && candidates[0].content && candidates[0].content.parts && candidates[0].content.parts[0];
          var rawText = textPart && textPart.text ? textPart.text.trim() : '';
          if (!rawText) {
            throw new Error('empty');
          }
          // Defensive: strip any accidental markdown code fences.
          rawText = rawText.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '');
          var classification = JSON.parse(rawText);
          resolve(classification);
        } catch (err) {
          var understandErr = new Error('Could not understand the voice command. Please try again.');
          understandErr.statusCode = 422;
          reject(understandErr);
        }
      });
    });

    request.on('error', function () {
      var netErr = new Error('Could not reach the voice command service. Please check your connection.');
      netErr.statusCode = 502;
      reject(netErr);
    });

    request.write(requestBody);
    request.end();
  });
}

var voiceCommandUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: function (req, file, cb) {
    var allowed = ['audio/webm', 'audio/ogg', 'audio/wav', 'audio/mp4', 'audio/mpeg', 'audio/x-m4a', 'audio/aac'];
    if (allowed.indexOf(file.mimetype) !== -1) {
      cb(null, true);
    } else {
      cb(new Error('Invalid audio type: ' + file.mimetype));
    }
  }
});

app.post('/api/voice-command', voiceCommandUpload.single('audio'), function (req, res) {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No audio recorded.' });
  }

  callGeminiVoiceCommand(req.file.buffer, req.file.mimetype).then(function (classification) {
    var tool = String((classification && classification.tool) || '').trim();
    var confidence = Number(classification && classification.confidence);
    if (isNaN(confidence)) confidence = 0;

    if (!tool || VOICE_COMMAND_TOOLS.indexOf(tool) === -1) {
      return res.status(422).json({ success: false, error: 'Could not recognize a supported tool from that command.' });
    }
    if (confidence < VOICE_COMMAND_MIN_CONFIDENCE) {
      return res.status(422).json({
        success: false,
        error: 'Not confident enough in that command. Please try again more clearly.',
        recognized_text: (classification && classification.recognized_text) || ''
      });
    }

    logAuditEvent('guest', 'voice-command', { tool: tool, confidence: confidence });

    res.json({
      success: true,
      tool: tool,
      action: String((classification && classification.action) || '').trim(),
      parameters: (classification && classification.parameters && typeof classification.parameters === 'object') ? classification.parameters : {},
      recognized_text: String((classification && classification.recognized_text) || '').trim(),
      confidence: confidence
    });
  }).catch(function (err) {
    var status = (err && err.statusCode) || 500;
    res.status(status).json({ success: false, error: (err && err.message) || 'Voice command failed.' });
  });
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
  try {
    triggerBackup('startup');
  } catch (err) {
    console.error('Startup backup failed:', err.message || err);
  }
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

module.exports = {
  app: app,
  registerPendingOrder: registerPendingOrder,
  resolvePendingOrder: resolvePendingOrder,
  clearPendingOrder: clearPendingOrder,
  resolveTaxBreakdown: resolveTaxBreakdown,
  resolveGstClassification: resolveGstClassification,
  buildGstReportCsv: buildGstReportCsv,
  buildSalesOrdersCsv: buildSalesOrdersCsv,
  getReportRowFromTransaction: getReportRowFromTransaction,
  sanitizeLegacyTransactions: sanitizeLegacyTransactions,
  buildTransactionDiagnostics: buildTransactionDiagnostics,
  getQuotaEntitlementForPlan: getQuotaEntitlementForPlan,
  getUserQuotaSnapshot: getUserQuotaSnapshot,
  upsertUserAccount: upsertUserAccount,
  applyPromoCode: applyPromoCode,
  redeemPromoCode: redeemPromoCode,
  isPlanEligibleForPromo: isPlanEligibleForPromo,
  normalizeApplicablePlans: normalizeApplicablePlans,
  buildPromoUsageReport: buildPromoUsageReport,
  buildPromoUsageReportCsv: buildPromoUsageReportCsv,
  buildPurchaseWelcomeEmail: buildPurchaseWelcomeEmail,
  buildInvoicePdfBuffer: buildInvoicePdfBuffer
};
