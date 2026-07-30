import json
import urllib.request

BASE = 'http://127.0.0.1:3000'


def request(path, method='GET', data=None, headers=None):
    body = None if data is None else json.dumps(data).encode('utf-8')
    req = urllib.request.Request(BASE + path, data=body, method=method)
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=10) as response:
        payload = response.read().decode('utf-8')
        try:
            return response.status, json.loads(payload)
        except Exception:
            return response.status, payload


if __name__ == '__main__':
    print(request('/api/info'))
    login_status, login_payload = request('/api/admin/login', method='POST', data={'email': 'admin@getreadyjob.com', 'password': 'Admin@2026!'}, headers={'Content-Type': 'application/json'})
    print('login', login_status, login_payload)
    token = login_payload.get('token')
    promos_status, promos_payload = request('/api/admin/promos', headers={'Authorization': 'Bearer ' + token})
    print('promos', promos_status, promos_payload)
    settings_status, settings_payload = request('/api/admin/settings', headers={'Authorization': 'Bearer ' + token})
    print('settings', settings_status, settings_payload)
    create_status, create_payload = request('/api/admin/promos', method='POST', data={'code': 'TESTPROMO', 'discountPercent': 10, 'validUntil': '2030-01-01', 'usageLimit': 5}, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    print('create promo', create_status, create_payload)
    checkout_status, checkout_payload = request('/api/create-order', method='POST', data={'amount': 24900, 'currency': 'INR', 'planId': 'lifetime-pro', 'billing': {'name': 'Test User', 'email': 'test@example.com', 'country': 'India'}, 'promoCode': 'TESTPROMO'}, headers={'Content-Type': 'application/json'})
    print('checkout', checkout_status, checkout_payload)
