'use strict';

var assert = require('node:assert/strict');
var http = require('node:http');
var os = require('node:os');
var path = require('node:path');
var test = require('node:test');

function loadAppWithEmailOtp(options) {
  var opts = options || {};
  var defaultStateFile = path.join(
    os.tmpdir(),
    'jobready-admin-email-otp-state-' + process.pid + '-' + Date.now() + '-' + Math.random().toString(16).slice(2) + '.json'
  );
  var serverPath = require.resolve('../compression_server');
  delete require.cache[serverPath];
  process.env.NODE_ENV = 'test';
  process.env.ADMIN_EMAIL = 'admin@getreadyjob.com';
  process.env.ADMIN_ALLOWED_EMAILS = 'admin@getreadyjob.com,hello@getreadyjob.com,rajesh.khola@gmail.com';
  process.env.ADMIN_2FA_REQUIRED = opts.requireTwoFactor === false ? 'false' : 'true';
  process.env.ADMIN_2FA_ENABLED = 'false';
  process.env.ADMIN_EMAIL_OTP_TARGET = 'RAJESH.KHOLA@GMAIL.COM';
  process.env.ADMIN_2FA_STATE_FILE = opts.stateFile || defaultStateFile;
  return require('../compression_server').app;
}

async function login(app, email) {
  var server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    var address = server.address();
    var response = await fetch('http://127.0.0.1:' + address.port + '/api/admin/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: email || 'admin@getreadyjob.com', password: 'Admin@2026!' })
    });
    assert.equal(response.status, 200);
    return response.json();
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
}

async function verifyTwoFactor(app, challengeToken, code) {
  var server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    var address = server.address();
    var response = await fetch('http://127.0.0.1:' + address.port + '/api/admin/2fa/verify', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ challengeToken: challengeToken, code: code })
    });
    var payload = await response.json();
    return { status: response.status, payload: payload };
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
}

async function resendTwoFactor(app, challengeToken) {
  var server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    var address = server.address();
    var response = await fetch('http://127.0.0.1:' + address.port + '/api/admin/2fa/resend', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ challengeToken: challengeToken })
    });
    assert.equal(response.status, 200);
    return response.json();
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
}

test('admin login requires email OTP challenge and never returns QR setup', async function () {
  var payload = await login(loadAppWithEmailOtp());

  assert.equal(payload.requireOTP, true);
  assert.equal(payload.requires2fa, true);
  assert.equal(payload.showQR, false);
  assert.ok(payload.challengeToken);
  assert.equal(payload.challengeExpiresInSec, 300);
  assert.equal(payload.qrCodeUrl, undefined);
  assert.match(String(payload.deliveryEmail || '').toLowerCase(), /^r\*\*\*a@gmail\.com$/);
  assert.match(payload.otpPreview, /^\d{6}$/);
});

test('email OTP verification returns admin token', async function () {
  var app = loadAppWithEmailOtp();
  var loginPayload = await login(app);
  var verifyPayload = await verifyTwoFactor(app, loginPayload.challengeToken, loginPayload.otpPreview);

  assert.equal(verifyPayload.status, 200);
  assert.equal(verifyPayload.payload.success, true);
  assert.equal(verifyPayload.payload.role, 'admin');
  assert.ok(verifyPayload.payload.token);
  assert.ok(verifyPayload.payload.expiresAt);
});

test('resend OTP invalidates previous OTP and accepts latest OTP', async function () {
  var app = loadAppWithEmailOtp();
  var loginPayload = await login(app);
  var oldOtp = loginPayload.otpPreview;
  var resendPayload = await resendTwoFactor(app, loginPayload.challengeToken);

  assert.equal(resendPayload.success, true);
  assert.match(resendPayload.otpPreview, /^\d{6}$/);

  var staleVerify = await verifyTwoFactor(app, loginPayload.challengeToken, oldOtp);
  assert.equal(staleVerify.status, 401);
  assert.equal(staleVerify.payload.success, false);

  var freshVerify = await verifyTwoFactor(app, loginPayload.challengeToken, resendPayload.otpPreview);
  assert.equal(freshVerify.status, 200);
  assert.equal(freshVerify.payload.success, true);
  assert.ok(freshVerify.payload.token);
});
