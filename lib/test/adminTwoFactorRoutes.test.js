'use strict';

var assert = require('node:assert/strict');
var http = require('node:http');
var fs = require('node:fs');
var os = require('node:os');
var path = require('node:path');
var crypto = require('node:crypto');
var test = require('node:test');

function loadAppWithTwoFactor(enabled, options) {
  var opts = options || {};
  var defaultStateFile = path.join(
    os.tmpdir(),
    'jobready-admin-2fa-state-' + process.pid + '-' + Date.now() + '-' + Math.random().toString(16).slice(2) + '.json'
  );
  var serverPath = require.resolve('../compression_server');
  delete require.cache[serverPath];
  process.env.ADMIN_EMAIL = 'admin@getreadyjob.com';
  process.env.ADMIN_ALLOWED_EMAILS = 'admin@getreadyjob.com,hello@getreadyjob.com,rajesh.khola@gmail.com';
  process.env.ADMIN_2FA_ENABLED = enabled ? 'true' : 'false';
  process.env.ADMIN_2FA_SECRET = opts.secret || 'JBSWY3DPEHPK3PXP';
  process.env.ADMIN_2FA_STATE_FILE = opts.stateFile || defaultStateFile;
  return require('../compression_server').app;
}

function base32Decode(input) {
  var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var normalized = String(input || '').replace(/=/g, '').replace(/\s+/g, '').toUpperCase();
  var buffer = 0;
  var bitsLeft = 0;
  var output = [];

  for (var i = 0; i < normalized.length; i += 1) {
    var char = normalized[i];
    var index = alphabet.indexOf(char);
    if (index < 0) {
      continue;
    }
    buffer = (buffer << 5) | index;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      output.push((buffer >> (bitsLeft - 8)) & 0xff);
      bitsLeft -= 8;
    }
  }

  return Buffer.from(output);
}

function generateTotp(secret, counter) {
  var key = base32Decode(secret);
  var counterBuffer = Buffer.alloc(8);
  var temp = counter;
  for (var i = 7; i >= 0; i -= 1) {
    counterBuffer[i] = temp & 0xff;
    temp = Math.floor(temp / 256);
  }
  var digest = crypto.createHmac('sha1', key).update(counterBuffer).digest();
  var offset = digest[digest.length - 1] & 0x0f;
  var binary = ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  var otp = binary % 1000000;
  return String(otp).padStart(6, '0');
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
    assert.equal(response.status, 200);
    return response.json();
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
}

test('enabled 2FA requests only an OTP challenge', async function () {
  var payload = await login(loadAppWithTwoFactor(true));

  assert.equal(payload.requireOTP, true);
  assert.equal(payload.showQR, false);
  assert.equal(payload.qrCodeUrl, undefined);
  assert.ok(payload.challengeToken);
});

test('first-time 2FA setup returns a QR code and OTP challenge', async function () {
  var app = loadAppWithTwoFactor(false);
  var payload = await login(app);

  assert.equal(payload.requireOTP, true);
  assert.equal(payload.showQR, true);
  assert.match(payload.qrCodeUrl, /^data:image\/png;base64,/);
  assert.ok(payload.challengeToken);

  var followupPayload = await login(app);
  assert.equal(followupPayload.requireOTP, true);
  assert.equal(followupPayload.showQR, false);
  assert.equal(followupPayload.qrCodeUrl, undefined);
  assert.ok(followupPayload.challengeToken);
});

test('admin login accepts explicitly allowed alternate admin emails', async function () {
  var app = loadAppWithTwoFactor(true);

  var payloadForHello = await login(app, 'hello@getreadyjob.com');
  assert.equal(payloadForHello.requireOTP, true);
  assert.ok(payloadForHello.challengeToken);

  var payloadForRajesh = await login(app, 'rajesh.khola@gmail.com');
  assert.equal(payloadForRajesh.requireOTP, true);
  assert.ok(payloadForRajesh.challengeToken);
});

test('2FA setup remains configured after reload and does not show QR again', async function () {
  var stateFile = path.join(os.tmpdir(), 'jobready-admin-2fa-state-' + Date.now() + '.json');
  try {
    var appFirstBoot = loadAppWithTwoFactor(false, {
      secret: 'JBSWY3DPEHPK3PXP',
      stateFile: stateFile
    });

    var firstLogin = await login(appFirstBoot);
    assert.equal(firstLogin.requireOTP, true);
    assert.equal(firstLogin.showQR, true);
    assert.ok(firstLogin.challengeToken);

    var step = Math.floor(Date.now() / 1000 / 30);
    var code = generateTotp('JBSWY3DPEHPK3PXP', step);
    var verifyPayload = await verifyTwoFactor(appFirstBoot, firstLogin.challengeToken, code);
    assert.equal(verifyPayload.success, true);
    assert.ok(verifyPayload.token);

    var appReloaded = loadAppWithTwoFactor(false, {
      secret: '',
      stateFile: stateFile
    });
    var secondLogin = await login(appReloaded);
    assert.equal(secondLogin.requireOTP, true);
    assert.equal(secondLogin.showQR, false);
    assert.equal(secondLogin.qrCodeUrl, undefined);
    assert.ok(secondLogin.challengeToken);
  } finally {
    try {
      fs.unlinkSync(stateFile);
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
});
