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
  if (!amount || amount < 100) {
    return { valid: false, error: 'Amount must be at least 100 paise.' };
  }

  return { valid: true };
}

module.exports = {
  createPaymentSignature: createPaymentSignature,
  validateOrderPayload: validateOrderPayload
};
