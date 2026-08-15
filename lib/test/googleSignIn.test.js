const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../compression_server');

test('google sign-in verifies the Google ID token and returns the real, verified email', async function () {
  process.env.NODE_ENV = 'test';
  process.env.GOOGLE_OAUTH_CLIENT_ID = 'test-client-id.apps.googleusercontent.com';

  const mockClaims = {
    aud: process.env.GOOGLE_OAUTH_CLIENT_ID,
    email: 'google.user@example.com',
    email_verified: 'true',
    name: 'Google User',
    sub: 'google-123',
    picture: 'https://example.com/photo.jpg'
  };
  const mockIdToken = 'test-mock-token:' + Buffer.from(JSON.stringify(mockClaims)).toString('base64');

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
      body: JSON.stringify({ id_token: mockIdToken })
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.success, true);
    assert.equal(payload.user.email, 'google.user@example.com');
    assert.equal(payload.provider, 'google');
    assert.equal(payload.emailVerified, true);
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});

test('google sign-in rejects requests without a verifiable Google ID token', async function () {
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
      body: JSON.stringify({ profile: { email: 'spoofed@example.com' } })
    });

    assert.equal(response.status, 400);
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});
