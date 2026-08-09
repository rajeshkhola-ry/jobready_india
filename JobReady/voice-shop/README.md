# Caddaddy Voice Shop

Isolated Voice Shop module for `caddaddy.com`. This application lives entirely under `JobReady/voice-shop` and does not depend on GetReadyJob routes or source files.

## Included

- Signup with full name, email, mobile, country, and password
- Login, logout, forgot-password, and single-use reset tokens
- Google and Microsoft OAuth entry points with environment placeholders
- Account-required two-minute trial, limited to one claim per account
- Atomic global 1,000-account trial cap with automatic disable and admin alert record
- Wallet schema and low-balance threshold
- Personal and Business per-minute rates
- 1-Day, 7-Day, 30-Day, and 1-Year passes
- IP/country-based INR or USD pricing
- Monthly-average USD-INR rate with a configurable fallback
- Dedicated Voice Shop admin controls for DB-backed rates and trial availability

## Local Setup

```bash
npm install
# Create .env.local from .env.example and set AUTH_SECRET.
npm run dev
```

Open `http://localhost:3000`.

SQLite data is stored under `data/` and excluded from Git. Set `DATABASE_PATH` to a filename only; database files remain sandboxed inside that directory.

## OAuth Configuration

Create provider applications and add these values through the deployment platform's secret manager:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI`
- `MICROSOFT_CLIENT_ID`
- `MICROSOFT_CLIENT_SECRET`
- `MICROSOFT_TENANT_ID`
- `MICROSOFT_REDIRECT_URI`

The social buttons return a configuration-required response until their provider credentials are present. Never commit OAuth secrets.

## Voice Shop Admin Controls

Open `/admin` and authenticate with `VOICE_SHOP_ADMIN_KEY`. The dedicated card controls only Voice Shop settings:

- Personal INR per-minute rate
- Business INR per-minute rate
- Global two-minute trial ON/OFF switch

The protected `GET` and `PUT` endpoint is `/api/admin/voice-shop`. When the toggle is OFF, `/api/trial/claim` returns HTTP `403` and public Voice Shop screens omit all trial promotions and references.

## Currency Rules

- `IN` country header: INR
- Other or unknown country: USD
- Monthly average source: `EXCHANGE_RATE_API_URL`
- Offline/API fallback: `USD_INR_FALLBACK_RATE`
- Wallet rates preserve two-decimal precision; passes and top-ups use rounded whole amounts.

## Validation

```bash
npm test
npm run lint
npm run build
```
