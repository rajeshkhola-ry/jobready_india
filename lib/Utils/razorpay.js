'use strict';

var crypto = require('crypto');

function createPaymentSignature(orderId, paymentId, keySecret) {
  return crypto
    .createHmac('sha256', keySecret)
    .update(orderId + '|' + paymentId)
    .digest('hex');
}

function validateOrderPayload(payload) {
  var amount = parseInt(payload && payload.amount, 10);
  // Razorpay's documented minimum differs by currency (roughly INR 1 / USD
  // 0.50) - a flat 100-paise floor incorrectly rejected valid low-cost USD
  // top-up packs (e.g. a $0.99 pack = 99 minor units) once the client
  // started sending the actually-selected currency instead of always INR.
  var currency = String((payload && payload.currency) || 'INR').toUpperCase();
  var minimumMinorUnits = currency === 'USD' ? 50 : 100;
  if (!amount || amount < minimumMinorUnits) {
    return { valid: false, error: 'Amount must be at least ' + minimumMinorUnits + ' ' + (currency === 'USD' ? 'cents' : 'paise') + '.' };
  }

  return { valid: true };
}

module.exports = {
  createPaymentSignature: createPaymentSignature,
  validateOrderPayload: validateOrderPayload
};
