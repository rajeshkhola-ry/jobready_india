const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../compression_server');

test('google sign-in creates and returns a user profile from a verified Google identity', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const response = await fetch(baseUrl + '/api/user/google-signin', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        idToken: 'mock-google-token',
        profile: {
          email: 'google.user@example.com',
          name: 'Google User',
          sub: 'google-123',
          picture: 'https://example.com/photo.jpg'
        }
      })
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.success, true);
    assert.equal(payload.user.email, 'google.user@example.com');
    assert.equal(payload.provider, 'google');
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});
