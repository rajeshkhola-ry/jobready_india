const http = require('http');
const req = http.request({
  host: 'localhost',
  port: 3000,
  path: '/api/admin/login',
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
}, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log(res.statusCode);
    console.log(data);
  });
});
req.write(JSON.stringify({ email: 'admin@getreadyjob.com', password: 'Admin@2026!' }));
req.end();
