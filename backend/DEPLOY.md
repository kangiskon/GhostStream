# GhostStream API deployment

The API is designed for the existing `ghoststreams.ink` Ubuntu/Docker/Nginx host. PostgreSQL and the API remain on a Docker-only network; Nginx is the only public entry point.

## 1. Configure

Copy `.env.example` to `.env` and set strong production values. `JWT_SECRET` must be at least 32 random bytes. Set `APPLE_ALLOWED_AUDIENCES` to the comma-separated native bundle id and, when the deletion website uses Sign in with Apple, its Apple Services ID. Configure SMTP before enabling public email/password registration.

## 2. Start PostgreSQL and API

```bash
docker compose -f docker-compose.example.yml up -d --build
```

Apply migrations from the API container before serving traffic:

```bash
docker compose -f docker-compose.example.yml exec ghoststream-api alembic upgrade head
```

## 3. Nginx

Merge `nginx-ghoststream-api.conf.example` into the existing HTTPS `ghoststreams.ink` server block. The API container is intentionally not published with a host port. Both Nginx and `ghoststream-api` must share a Docker network that resolves the service name.

Validate and reload Nginx:

```bash
docker exec ghosthost-nginx nginx -t
docker exec ghosthost-nginx nginx -s reload
```

## 4. Smoke test

The health-only check is safe:

```bash
bash scripts/smoke_test.sh
```

For the authenticated checks, use a verified disposable GhostStream account:

```bash
SMOKE_EMAIL='review-smoke@example.com' \
SMOKE_PASSWORD='use-a-disposable-strong-password' \
bash scripts/smoke_test.sh
```

Set `SMOKE_REGISTER=1` once to create an account, then verify the email and rerun with `SMOKE_REGISTER=0`. Account deletion is deliberately opt-in and should only be used with a disposable account:

```bash
SMOKE_DELETE=1 SMOKE_EMAIL='...' SMOKE_PASSWORD='...' bash scripts/smoke_test.sh
```

## Security notes

- Do not log request bodies for auth, pairing, source, transfer, or deletion routes.
- Do not add provider passwords, raw playlist bodies, source authorization headers, or decryptable source credentials to PostgreSQL.
- Back up PostgreSQL using encrypted storage and test restore procedures.
- Rotate `JWT_SECRET` through a documented session-invalidating maintenance procedure; changing it immediately invalidates existing access tokens.
