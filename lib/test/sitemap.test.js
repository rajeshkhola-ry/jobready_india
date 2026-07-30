const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../compression_server');

test('sitemap endpoint returns XML content for search engines', async function () {
  const server = http.createServer(app);
  await new Promise(function (resolve) {
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  const baseUrl = 'http://127.0.0.1:' + address.port;

  try {
    const response = await fetch(baseUrl + '/sitemap.xml');
    assert.equal(response.status, 200);
    const text = await response.text();
    assert.match(text, /<urlset/i);
    assert.match(text, /https:\/\/getreadyjob\.com\//i);
  } finally {
    await new Promise(function (resolve) {
      server.close(resolve);
    });
  }
});
