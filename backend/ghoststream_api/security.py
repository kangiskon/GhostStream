from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from .config import get_settings

_password_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return _password_hasher.hash(password)


def verify_password(password: str, encoded: str | None) -> bool:
    if not encoded:
        return False
    try:
        return _password_hasher.verify(encoded, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def new_secret() -> str:
    return secrets.token_urlsafe(48)


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def encode_access_token(*, user_id: str, device_id: str, session_id: str) -> tuple[str, int]:
    settings = get_settings()
    seconds = settings.access_token_minutes * 60
    now = utcnow()
    payload: dict[str, Any] = {
        'sub': user_id,
        'device_id': device_id,
        'session_id': session_id,
        'iat': now,
        'exp': now + timedelta(seconds=seconds),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm='HS256'), seconds


def decode_access_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    return jwt.decode(token, settings.jwt_secret, algorithms=['HS256'])
