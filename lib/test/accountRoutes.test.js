const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../compression_server');

test('account and password reset routes create and retrieve user profiles', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const createResponse = await fetch(baseUrl + '/api/user/account', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'acct@example.com',
        name: 'Jane Doe',
        company: 'Acme Inc',
        country: 'India'
      })
    });

    assert.equal(createResponse.status, 200);
    const createdPayload = await createResponse.json();
    assert.equal(createdPayload.success, true);
    assert.equal(createdPayload.user.email, 'acct@example.com');

    const getResponse = await fetch(baseUrl + '/api/user/account?email=acct%40example.com');
    assert.equal(getResponse.status, 200);
    const fetchedPayload = await getResponse.json();
    assert.equal(fetchedPayload.success, true);
    assert.equal(fetchedPayload.user.email, 'acct@example.com');

    const resetResponse = await fetch(baseUrl + '/api/user/password-reset', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'acct@example.com' })
    });
    assert.equal(resetResponse.status, 200);
    const resetPayload = await resetResponse.json();
    assert.equal(resetPayload.success, true);
    assert.equal(resetPayload.email, 'acct@example.com');
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});
