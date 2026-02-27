# 🔒 Security Rules

## Authentication & Authorization

### JWT Token Structure
```json
{
  "sub": "user-uuid",
  "role": "driver",
  "iat": 1705312200,
  "exp": 1705398600,
  "device_id": "device-fingerprint"
}
```

### Rules
1. **Access Token TTL**: 15 phút (short-lived)
2. **Refresh Token TTL**: 7 ngày (stored in HttpOnly cookie)
3. **MQTT Auth**: Dùng JWT trong password field, verify tại broker
4. **gRPC Auth**: Propagate JWT qua metadata headers
5. **Rate Limiting**: 100 req/min per user, 10 req/min cho booking

## Data Protection

| Data | Encryption | Storage |
|------|-----------|---------|
| Password | bcrypt (cost=12) | PostgreSQL |
| Phone number | AES-256-GCM | PostgreSQL |
| Payment info | PCI-DSS compliant vault | External |
| GPS coordinates | TLS in transit | Redis (TTL) |
| MQTT messages | TLS 1.3 | In transit only |

## API Security Checklist

- [ ] All endpoints require authentication (except /health, /login)
- [ ] Input validation on every handler
- [ ] SQL parameterized queries (no string concat)
- [ ] Rate limiting per IP and per user
- [ ] CORS whitelist for web clients
- [ ] Request/Response logging (mask PII)
- [ ] HTTPS only (redirect HTTP → HTTPS)
- [ ] Helmet headers (X-Frame-Options, CSP, etc.)

## MQTT Security

```yaml
# ACL Rules
driver/{driver_id}/location:
  publish: only driver with matching ID
  subscribe: location-service only

drivers/{driver_id}/rides/request:
  publish: ride-service only
  subscribe: only driver with matching ID
```
