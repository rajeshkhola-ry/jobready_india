const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../compression_server');

test('validate-promo and create-order apply promo discounts through the public API', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const loginResponse = await fetch(baseUrl + '/api/admin/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'admin@getreadyjob.com', password: 'Admin@2026!' })
    });
    assert.equal(loginResponse.status, 200);
    const loginPayload = await loginResponse.json();
    const token = loginPayload.token;
    assert.ok(token);

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
