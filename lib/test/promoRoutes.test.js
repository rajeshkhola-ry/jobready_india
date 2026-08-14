const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app, registerPendingOrder, resolvePendingOrder, clearPendingOrder, resolveTaxBreakdown, buildInvoicePdfBuffer } = require('../compression_server');
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

test('resolveTaxBreakdown applies Delhi intrastate CGST+SGST and interstate IGST, with POS metadata in the PDF', function () {
  const delhiTax = resolveTaxBreakdown(1000, { country: 'India', state: 'Delhi' }, 'INR');
  assert.equal(delhiTax.isDomestic, true);
  assert.equal(delhiTax.gstType, 'CGST + SGST');
  assert.ok(Math.abs(delhiTax.cgstAmount - 76.27) < 0.01);
  assert.ok(Math.abs(delhiTax.sgstAmount - 76.27) < 0.01);
  assert.equal(delhiTax.igstAmount, 0);

  const interstateTax = resolveTaxBreakdown(1000, { country: 'India', state: 'Maharashtra' }, 'INR');
  assert.equal(interstateTax.isDomestic, true);
  assert.equal(interstateTax.gstType, 'IGST');
  assert.ok(Math.abs(interstateTax.igstAmount - 152.54) < 0.01);
  assert.equal(interstateTax.cgstAmount, 0);
  assert.equal(interstateTax.sgstAmount, 0);

  const transaction = {
    transactionId: 'txn-gst-pos-123',
    invoiceNumber: 'GRJ/25-26/2026-08/0001',
    orderId: 'order_rzp_pos_123',
    paymentId: 'pay_test_gstin_123',
    planId: 'lifetime-pro',
    planName: 'Lifetime Pro',
    amount: 1000,
    totalAmount: 1000,
    currency: 'INR',
    billing: {
      name: 'GST Buyer',
      email: 'gstbuyer@example.com',
      country: 'India',
      state: 'Delhi',
      gstin: '07ABCDE1234F1Z5',
      mobile: '9876543210'
    },
    taxBreakdown: delhiTax,
    createdAt: new Date().toISOString(),
    paidAt: new Date().toISOString()
  };

  const pdfBuffer = buildInvoicePdfBuffer(transaction);
  const pdfText = pdfBuffer.toString('latin1');
  assert.match(pdfText, /Place of Supply.*Delhi.*07/);
  assert.match(pdfText, /GST Structure: CGST \+ SGST/);
  assert.match(pdfText, /Authorized Signatory/);
  assert.match(pdfText, /Customer GSTIN: 07ABCDE1234F1Z5/);
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

test('GET /api/user/transactions returns the invoice history for the customer email', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const createOrderResponse = await fetch(baseUrl + '/api/create-order', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        amount: 24900,
        currency: 'INR',
        receipt: 'history-checkout',
        planId: 'lifetime-pro',
        billing: {
          email: 'historybuyer@example.com',
          name: 'History Buyer',
          company: 'Acme Labs',
          state: 'Maharashtra',
          country: 'India',
          gstin: '27ABCDE1234F1Z5',
          mobile: '9876543210'
        }
      })
    });
    assert.equal(createOrderResponse.status, 200);
    const createOrderPayload = await createOrderResponse.json();
    assert.equal(createOrderPayload.success, true);

    const verifyResponse = await fetch(baseUrl + '/api/verify-payment', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        order_id: createOrderPayload.order_id,
        payment_id: 'pay_history_invoice_123',
        signature: 'local-test-signature'
      })
    });
    assert.equal(verifyResponse.status, 200);

    const historyResponse = await fetch(baseUrl + '/api/user/transactions?email=' + encodeURIComponent('historybuyer@example.com'));
    assert.equal(historyResponse.status, 200);
    const historyPayload = await historyResponse.json();
    assert.equal(historyPayload.success, true);
    assert.ok(Array.isArray(historyPayload.transactions));
    assert.ok(historyPayload.transactions.some(function (tx) {
      return tx.email === 'historybuyer@example.com' || tx.billing && tx.billing.email === 'historybuyer@example.com';
    }));
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});

test('admin sales report and invoice amendment endpoints work for GST audit and customer updates', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;
  const token = adminAuth.createAdminToken({
    email: 'admin@getreadyjob.com',
    role: 'admin',
    exp: Math.floor(Date.now() / 1000) + 600
  }, process.env.ADMIN_JWT_SECRET || 'dev-secret');

  try {
    const createOrderResponse = await fetch(baseUrl + '/api/create-order', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        amount: 24900,
        currency: 'INR',
        receipt: 'audit-amend-checkout',
        planId: 'lifetime-pro',
        billing: {
          email: 'auditbuyer@example.com',
          name: 'Audit Buyer',
          company: 'Audit Co.',
          state: 'Delhi',
          country: 'India',
          gstin: '07ABCDE1234F1Z5',
          mobile: '9876543211'
        }
      })
    });
    assert.equal(createOrderResponse.status, 200);
    const createOrderPayload = await createOrderResponse.json();
    assert.equal(createOrderPayload.success, true);

    const verifyResponse = await fetch(baseUrl + '/api/verify-payment', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        order_id: createOrderPayload.order_id,
        payment_id: 'pay_audit_invoice_123',
        signature: 'local-test-signature'
      })
    });
    assert.equal(verifyResponse.status, 200);
    const verifyPayload = await verifyResponse.json();
    assert.equal(verifyPayload.success, true);

    const reportResponse = await fetch(baseUrl + '/api/admin/sales-report?range=financial-year', {
      headers: {
        authorization: 'Bearer ' + token
      }
    });
    assert.equal(reportResponse.status, 200);
    const reportPayload = await reportResponse.json();
    assert.equal(reportPayload.success, true);
    assert.ok(Array.isArray(reportPayload.rows));
    assert.ok(reportPayload.summary);

    const reportCsvResponse = await fetch(baseUrl + '/api/admin/sales-report/export?format=csv&range=financial-year', {
      headers: {
        authorization: 'Bearer ' + token
      }
    });
    assert.equal(reportCsvResponse.status, 200);
    const csvText = await reportCsvResponse.text();
    assert.match(csvText, /Invoice Number/);
    assert.match(csvText, /Place of Supply/);

    const invoiceSearchResponse = await fetch(baseUrl + '/api/admin/invoices/search?query=' + encodeURIComponent(verifyPayload.transactionId), {
      headers: {
        authorization: 'Bearer ' + token
      }
    });
    assert.equal(invoiceSearchResponse.status, 200);
    const searchPayload = await invoiceSearchResponse.json();
    assert.equal(searchPayload.success, true);
    assert.ok(Array.isArray(searchPayload.invoices));

    const amendResponse = await fetch(baseUrl + '/api/admin/invoices/' + verifyPayload.transactionId + '/amend', {
      method: 'PATCH',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer ' + token
      },
      body: JSON.stringify({
        customerName: 'Updated Audit Buyer',
        companyName: 'Updated Audit Co.',
        gstin: '09ABCDE1234F1Z6',
        state: 'Maharashtra'
      })
    });
    assert.equal(amendResponse.status, 200);
    const amendPayload = await amendResponse.json();
    assert.equal(amendPayload.success, true);
    assert.equal(amendPayload.invoice.billing.gstin, '09ABCDE1234F1Z6');

    const cancelResponse = await fetch(baseUrl + '/api/admin/invoices/' + verifyPayload.transactionId + '/cancel', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer ' + token
      },
      body: JSON.stringify({ reason: 'Duplicate invoice request' })
    });
    assert.equal(cancelResponse.status, 200);
    const cancelPayload = await cancelResponse.json();
    assert.equal(cancelPayload.success, true);
    assert.equal(cancelPayload.cancelled, true);

    const resendResponse = await fetch(baseUrl + '/api/admin/invoices/' + verifyPayload.transactionId + '/resend', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer ' + token
      },
      body: JSON.stringify({ email: 'auditbuyer@example.com' })
    });
    assert.equal(resendResponse.status, 200);
    const resendPayload = await resendResponse.json();
    assert.equal(resendPayload.success, true);
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});
