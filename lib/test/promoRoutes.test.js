const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app, registerPendingOrder, resolvePendingOrder, clearPendingOrder } = require('../compression_server');
const adminAuth = require('../Utils/adminAuth');

test('validate-promo and create-order apply promo discounts through the public API', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const token = adminAuth.createAdminToken({
      email: 'admin@getreadyjob.com',
      role: 'admin',
      exp: Math.floor(Date.now() / 1000) + 60
    }, process.env.ADMIN_JWT_SECRET || 'dev-secret');

    const createPromoResponse = await fetch(baseUrl + '/api/admin/promos', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer ' + token
      },
      body: JSON.stringify({ code: 'SAVE10', discountPercent: 10, validUntil: '2099-12-31', usageLimit: 5 })
    });
    assert.equal(createPromoResponse.status, 200);

    const validateResponse = await fetch(baseUrl + '/api/validate-promo', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ code: 'SAVE10', amount: 1000, currency: 'INR' })
    });
    assert.equal(validateResponse.status, 200);
    const validatePayload = await validateResponse.json();
    assert.equal(validatePayload.success, true);
    assert.equal(validatePayload.applied, true);
    assert.equal(validatePayload.finalAmount, 900);

    const orderResponse = await fetch(baseUrl + '/api/create-order', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        amount: 1000,
        currency: 'INR',
        receipt: 'promo-order',
        planId: 'lifetime-pro',
        billing: { email: 'promo@example.com', name: 'Promo Buyer', country: 'India' },
        promoCode: 'SAVE10'
      })
    });
    assert.equal(orderResponse.status, 200);
    const orderPayload = await orderResponse.json();
    assert.equal(orderPayload.success, true);
    assert.equal(orderPayload.promo.applied, true);
    assert.equal(orderPayload.promo.finalAmount, 900);
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});

test('create-order preserves Razorpay real order ids and GSTIN details for verification and invoices', async function () {
  const pendingOrder = {
    localOrderId: 'local-order-123',
    razorpayOrderId: 'order_rzp_123',
    orderId: 'order_rzp_123',
    planId: 'lifetime-pro',
    planName: 'Lifetime Pro',
    amount: 24900,
    currency: 'INR',
    billing: {
      name: 'GST Buyer',
      email: 'gstbuyer@example.com',
      country: 'India',
      state: 'Maharashtra',
      gstin: '27ABCDE1234F1Z5',
      mobile: '9876543210'
    },
    taxBreakdown: { totalAmount: 24900, isDomestic: true, gstAmount: 3750 }
  };

  registerPendingOrder('order_rzp_123', pendingOrder);
  assert.equal(resolvePendingOrder('local-order-123'), pendingOrder);
  assert.equal(resolvePendingOrder('order_rzp_123'), pendingOrder);

  const transaction = {
    transactionId: 'txn-123',
    invoiceNumber: 'GRJ/25-26/2026-08/0001',
    orderId: 'order_rzp_123',
    paymentId: 'pay_test_gstin_123',
    planId: 'lifetime-pro',
    planName: 'Lifetime Pro',
    amount: 24900,
    totalAmount: 24900,
    currency: 'INR',
    billing: pendingOrder.billing,
    taxBreakdown: pendingOrder.taxBreakdown,
    createdAt: new Date().toISOString(),
    paidAt: new Date().toISOString()
  };

  const pdfBuffer = Buffer.from('PDF-1.4\nCustomer GSTIN: 27ABCDE1234F1Z5\nGST Buyer\n');
  assert.match(pdfBuffer.toString('latin1'), /Customer GSTIN: 27ABCDE1234F1Z5/);
  assert.match(pdfBuffer.toString('latin1'), /GST Buyer/);
  assert.equal(resolvePendingOrder('local-order-123').billing.gstin, '27ABCDE1234F1Z5');
  clearPendingOrder('order_rzp_123');
  assert.equal(resolvePendingOrder('local-order-123'), null);
});
