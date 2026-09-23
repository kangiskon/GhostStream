#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://ghoststreams.ink}"
HEALTH_URL="${HEALTH_URL:-${BASE_URL}/ghoststream-api-health}"
SMOKE_EMAIL="${SMOKE_EMAIL:-}"
SMOKE_PASSWORD="${SMOKE_PASSWORD:-}"
SMOKE_DEVICE_ID="${SMOKE_DEVICE_ID:-11111111-1111-4111-8111-111111111111}"
SMOKE_PUBLIC_KEY="${SMOKE_PUBLIC_KEY:-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA}"
SMOKE_REGISTER="${SMOKE_REGISTER:-0}"
SMOKE_DELETE="${SMOKE_DELETE:-0}"

json_get() {
  local key="$1"
  python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$key"
}

curl -fsS "$HEALTH_URL" >/dev/null
echo "health: ok"

if [[ -z "$SMOKE_EMAIL" || -z "$SMOKE_PASSWORD" ]]; then
  echo "Set SMOKE_EMAIL and SMOKE_PASSWORD for account-flow checks."
  exit 0
fi

if [[ "$SMOKE_REGISTER" == "1" ]]; then
  curl -fsS -X POST "$BASE_URL/api/v1/auth/register"     -H 'Content-Type: application/json'     -d "{\"email\":\"$SMOKE_EMAIL\",\"password\":\"$SMOKE_PASSWORD\",\"device_id\":\"$SMOKE_DEVICE_ID\",\"display_name\":\"Smoke Test\",\"platform\":\"ios\",\"os_version\":\"smoke\",\"public_key\":\"$SMOKE_PUBLIC_KEY\"}" >/dev/null
  echo "registration: accepted; verify the email, then rerun"
  exit 0
fi

LOGIN_JSON="$(curl -fsS -X POST "$BASE_URL/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$SMOKE_EMAIL\",\"password\":\"$SMOKE_PASSWORD\",\"device_id\":\"$SMOKE_DEVICE_ID\",\"display_name\":\"Smoke Test\",\"platform\":\"ios\",\"os_version\":\"smoke\",\"public_key\":\"$SMOKE_PUBLIC_KEY\"}")"
ACCESS="$(printf '%s' "$LOGIN_JSON" | json_get access_token)"
REFRESH="$(printf '%s' "$LOGIN_JSON" | json_get refresh_token)"

curl -fsS "$BASE_URL/api/v1/devices" -H "Authorization: Bearer $ACCESS" >/dev/null
curl -fsS "$BASE_URL/api/v1/account/state" -H "Authorization: Bearer $ACCESS" >/dev/null

REFRESH_JSON="$(curl -fsS -X POST "$BASE_URL/api/v1/auth/refresh" -H 'Content-Type: application/json' -d "{\"refresh_token\":\"$REFRESH\"}")"
ACCESS="$(printf '%s' "$REFRESH_JSON" | json_get access_token)"

if [[ "$SMOKE_DELETE" == "1" ]]; then
  curl -fsS -X POST "$BASE_URL/api/v1/deletion/account"     -H "Authorization: Bearer $ACCESS"     -H 'Content-Type: application/json'     -d '{"confirmation":"DELETE"}' >/dev/null
fi

echo "GhostStream API smoke checks: ok"
