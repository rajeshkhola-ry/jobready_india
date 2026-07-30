'use strict';

var assert = require('assert');
var test = require('node:test');
var adminRateLimiter = require('../Utils/adminRateLimiter');

test('rate limiter allows a bounded number of attempts', function () {
  var key = 'rate-limit-test';
  assert.strictEqual(adminRateLimiter.isAllowed(key, 3, 60000), true);
  assert.strictEqual(adminRateLimiter.isAllowed(key, 3, 60000), true);
  assert.strictEqual(adminRateLimiter.isAllowed(key, 3, 60000), true);
  assert.strictEqual(adminRateLimiter.isAllowed(key, 3, 60000), false);
});
