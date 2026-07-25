# GETREADYJOB Bank API Packet (V1.1)

Prepared date: 2026-07-25
Website: https://getreadyjob.com
API base: https://api.getreadyjob.com/api/v1

## Payment API Endpoints

- Create Order:
  - POST https://api.getreadyjob.com/api/v1/payments/create-order
- Verify Payment:
  - POST https://api.getreadyjob.com/api/v1/payments/verify
- Webhook Receiver:
  - POST https://api.getreadyjob.com/api/v1/payments/webhook
- Callback URL:
  - https://api.getreadyjob.com/api/v1/payments/callback
- Cancel URL:
  - https://api.getreadyjob.com/api/v1/payments/cancel

## Security Notes

- Keep all payment secrets on backend only.
- Validate webhook signature on every callback.
- Use HTTPS and idempotency protection.
- Do not share secrets over email/chat.

## Support

- hello@getreadyjob.com
