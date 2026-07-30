'use strict';

var assert = require('assert');
var test = require('node:test');
var adminAuth = require('../Utils/adminAuth');

test('hashes and verifies admin passwords', function () {
  var password = 'StrongAdminPass!123';
  var hash = adminAuth.hashPassword(password);
  assert.ok(hash);
  assert.strictEqual(adminAuth.verifyPassword(password, hash), true);
  assert.strictEqual(adminAuth.verifyPassword('wrong-password', hash), false);
});

test('creates and verifies an admin JWT', function () {
  var token = adminAuth.createAdminToken({ email: 'admin@getreadyjob.com', role: 'admin' }, 'dev-secret');
  var payload = adminAuth.verifyAdminToken(token, 'dev-secret');
  assert.strictEqual(payload.email, 'admin@getreadyjob.com');
  assert.strictEqual(payload.role, 'admin');
});
