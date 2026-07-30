const http = require('http');
const body = JSON.stringify({ email: 'admin@getreadyjob.com', password: 'Admin@2026!' });
const req = http.request({
  host: '127.0.0.1',
  port: 3000,
  path: '/admin/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  }
}, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('STATUS', res.statusCode);
    console.log(data);
  });
});
req.on('error', (err) => {
  console.error(err);
  process.exit(1);
});
req.write(body);
req.end();
