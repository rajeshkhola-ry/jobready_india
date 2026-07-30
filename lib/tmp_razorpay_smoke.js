const { createPaymentSignature, validateOrderPayload } = require('./Utils/razorpay');
console.log(JSON.stringify({
  signature: createPaymentSignature('order_123', 'pay_456', 'secret-key'),
  validation: validateOrderPayload({ amount: 50 })
}, null, 2));
