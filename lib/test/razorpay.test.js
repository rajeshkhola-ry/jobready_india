'use strict';

var assert = require('assert');
var test = require('node:test');
var razorpayUtils = require('../Utils/razorpay');

test('creates a Razorpay signature from order and payment IDs', function () {
  var signature = razorpayUtils.createPaymentSignature('order_123', 'pay_456', 'secret-key');
  assert.strictEqual(signature, '44d4253bc1b93247d34a9e9273231f903fa8a6fb92989b50a9e401e1fb9a1e85');
});

test('rejects amounts below the Razorpay minimum', function () {
  var result = razorpayUtils.validateOrderPayload({ amount: 50, currency: 'INR', receipt: 'demo' });
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.error, 'Amount must be at least 100 paise.');
});
