from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
from jwt import InvalidTokenError
from jwt.algorithms import RSAAlgorithm

from ..config import get_settings

APPLE_ISSUER = 'https://appleid.apple.com'
APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys'
_JWKS_CACHE: tuple[float, dict[str, Any]] | None = None


class AppleAuthError(Exception):
    pass


@dataclass(frozen=True)
class AppleIdentity:
    subject: str
    email: str | None


def _fetch_apple_jwks() -> dict[str, Any]:
    global _JWKS_CACHE
    now = time.time()
    if _JWKS_CACHE is not None and now - _JWKS_CACHE[0] < 3600:
        return _JWKS_CACHE[1]
    response = httpx.get(APPLE_JWKS_URL, timeout=5.0)
    response.raise_for_status()
    data = response.json()
    _JWKS_CACHE = (now, data)
    return data


def _configured_audiences() -> set[str]:
    raw = get_settings().apple_allowed_audiences
    return {item.strip() for item in raw.split(',') if item.strip()}


def verify_apple_identity_token(
    token: str,
    *,
    jwks: dict[str, Any] | None = None,
    allowed_audiences: set[str] | None = None,
) -> AppleIdentity:
    audiences = allowed_audiences if allowed_audiences is not None else _configured_audiences()
    if not audiences:
        raise AppleAuthError('Apple Sign In audience is not configured')
    try:
        header = jwt.get_unverified_header(token)
        kid = header.get('kid')
        keys = (jwks or _fetch_apple_jwks()).get('keys', [])
        jwk = next((key for key in keys if key.get('kid') == kid), None)
        if jwk is None:
            raise AppleAuthError('No matching Apple signing key')
        public_key = RSAAlgorithm.from_jwk(json.dumps(jwk))
        claims = jwt.decode(
            token,
            public_key,
            algorithms=['RS256'],
            issuer=APPLE_ISSUER,
            audience=list(audiences),
            options={'require': ['exp', 'iat', 'iss', 'aud', 'sub']},
        )
    except AppleAuthError:
        raise
    except (InvalidTokenError, StopIteration, ValueError, TypeError, httpx.HTTPError) as exc:
        raise AppleAuthError('Invalid Apple identity token') from exc

    subject = claims.get('sub')
    if not isinstance(subject, str) or not subject:
        raise AppleAuthError('Apple identity token is missing subject')
    email = claims.get('email')
    if email is not None and not isinstance(email, str):
        email = None
    return AppleIdentity(subject=subject, email=email.lower() if email else None)
