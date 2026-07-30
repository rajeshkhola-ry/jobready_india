const base = 'http://127.0.0.1:3000';

async function req(path, opts = {}) {
  const res = await fetch(base + path, opts);
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch (e) { data = text; }
  console.log(path + ' -> ' + res.status);
  console.log(JSON.stringify(data));
  return { status: res.status, data };
}

(async () => {
  const login = await req('/api/admin/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'admin@getreadyjob.com', password: 'Admin@2026!' })
  });
  if (login.status !== 200) process.exit(1);
  const token = login.data.token;
  await req('/api/admin/promos', { headers: { authorization: 'Bearer ' + token } });
  await req('/api/admin/settings', { headers: { authorization: 'Bearer ' + token } });
  await req('/api/admin/promos', {
    method: 'POST',
    headers: { authorization: 'Bearer ' + token, 'content-type': 'application/json' },
    body: JSON.stringify({ code: 'TESTPROMO', discountPercent: 10, validUntil: '2030-01-01', usageLimit: 5 })
  });
  await req('/api/create-order', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ amount: 24900, currency: 'INR', planId: 'lifetime-pro', billing: { name: 'Test User', email: 'test@example.com', country: 'India' }, promoCode: 'TESTPROMO' })
  });
})();
