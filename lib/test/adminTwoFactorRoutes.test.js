'use strict';

var assert = require('node:assert/strict');
var http = require('node:http');
var test = require('node:test');

function loadAppWithTwoFactor(enabled) {
  var serverPath = require.resolve('../compression_server');
  delete require.cache[serverPath];
  process.env.ADMIN_EMAIL = 'admin@getreadyjob.com';
  process.env.ADMIN_ALLOWED_EMAILS = 'admin@getreadyjob.com,hello@tallyjob.com,rajesh.khola@gmail.com';
  process.env.ADMIN_2FA_ENABLED = enabled ? 'true' : 'false';
  process.env.ADMIN_2FA_SECRET = 'JBSWY3DPEHPK3PXP';
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

test('enabled 2FA requests only an OTP challenge', async function () {
  var payload = await login(loadAppWithTwoFactor(true));

  assert.equal(payload.requireOTP, true);
  assert.equal(payload.showQR, false);
  assert.equal(payload.qrCodeUrl, undefined);
  assert.ok(payload.challengeToken);
});

test('first-time 2FA setup returns a QR code and OTP challenge', async function () {
  var payload = await login(loadAppWithTwoFactor(false));

  assert.equal(payload.requireOTP, true);
  assert.equal(payload.showQR, true);
  assert.match(payload.qrCodeUrl, /^data:image\/png;base64,/);
  assert.ok(payload.challengeToken);
});

test('admin login accepts explicitly allowed alternate admin emails', async function () {
  var app = loadAppWithTwoFactor(true);

  var payloadForTally = await login(app, 'hello@tallyjob.com');
  assert.equal(payloadForTally.requireOTP, true);
  assert.ok(payloadForTally.challengeToken);

  var payloadForRajesh = await login(app, 'rajesh.khola@gmail.com');
  assert.equal(payloadForRajesh.requireOTP, true);
  assert.ok(payloadForRajesh.challengeToken);
});
