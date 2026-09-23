from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session as DBSession

from ..config import get_settings
from ..models import Device, EmailActionToken, Session, User, utcnow
from ..schemas import TokenPair
from ..security import as_utc, encode_access_token, hash_password, new_secret, sha256_text, utcnow as utcnow_aware, verify_password


class AuthError(Exception):
    def __init__(self, code: str, message: str = 'Authentication failed'):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class AuthContext:
    user: User
    device: Device
    session: Session


def upsert_device(
    db: DBSession,
    *,
    user_id: uuid.UUID,
    device_id: uuid.UUID,
    display_name: str,
    platform: str,
    os_version: str,
    public_key: str,
) -> Device:
    device = db.get(Device, device_id)
    if device is not None and device.user_id != user_id:
        raise AuthError('device_owned_by_other_account', 'Device is already registered to another account')
    if device is None:
        device = Device(
            id=device_id,
            user_id=user_id,
            display_name=display_name,
            platform=platform,
            os_version=os_version,
            public_key=public_key,
            trust_state='trusted',
        )
        db.add(device)
    else:
        if device.revoked_at is not None:
            raise AuthError('device_revoked', 'Device has been revoked')
        device.display_name = display_name
        device.platform = platform
        device.os_version = os_version
        device.public_key = public_key
        device.last_seen_at = utcnow()
    db.flush()
    return device


def issue_session(db: DBSession, user_id: uuid.UUID, device_id: uuid.UUID, *, family_id: uuid.UUID | None = None) -> TokenPair:
    settings = get_settings()
    raw_refresh = new_secret()
    session = Session(
        user_id=user_id,
        device_id=device_id,
        refresh_token_hash=sha256_text(raw_refresh),
        token_family_id=family_id or uuid.uuid4(),
        expires_at=utcnow() + timedelta(days=settings.refresh_token_days),
    )
    db.add(session)
    db.flush()
    access, seconds = encode_access_token(user_id=str(user_id), device_id=str(device_id), session_id=str(session.id))
    return TokenPair(access_token=access, refresh_token=raw_refresh, expires_in=seconds)


def rotate_refresh_token(db: DBSession, raw_token: str) -> TokenPair:
    token_hash = sha256_text(raw_token)
    session = db.scalar(select(Session).where(Session.refresh_token_hash == token_hash))
    if session is None:
        raise AuthError('invalid_refresh_token')
    if session.rotated_at is not None:
        db.execute(
            update(Session)
            .where(Session.token_family_id == session.token_family_id, Session.revoked_at.is_(None))
            .values(revoked_at=utcnow())
        )
        db.commit()
        raise AuthError('refresh_token_reuse', 'Refresh token reuse detected')
    if session.revoked_at is not None or as_utc(session.expires_at) <= utcnow_aware():
        raise AuthError('invalid_refresh_token')
    device = db.get(Device, session.device_id)
    user = db.get(User, session.user_id)
    if device is None or user is None or device.revoked_at is not None or user.deletion_started_at is not None:
        raise AuthError('invalid_refresh_token')

    session.rotated_at = utcnow()
    pair = issue_session(db, session.user_id, session.device_id, family_id=session.token_family_id)
    db.commit()
    return pair


def revoke_refresh_token(db: DBSession, raw_token: str) -> None:
    session = db.scalar(select(Session).where(Session.refresh_token_hash == sha256_text(raw_token)))
    if session is not None and session.revoked_at is None:
        session.revoked_at = utcnow()
        db.commit()


def issue_email_action(db: DBSession, user_id: uuid.UUID, kind: str, *, lifetime_minutes: int = 30) -> str:
    if kind not in {'verify_email', 'reset_password'}:
        raise ValueError('invalid email action kind')
    for old in db.scalars(
        select(EmailActionToken).where(
            EmailActionToken.user_id == user_id,
            EmailActionToken.kind == kind,
            EmailActionToken.used_at.is_(None),
        )
    ):
        old.used_at = utcnow()
    raw = new_secret()
    db.add(
        EmailActionToken(
            user_id=user_id,
            kind=kind,
            token_hash=sha256_text(raw),
            expires_at=utcnow() + timedelta(minutes=lifetime_minutes),
        )
    )
    db.commit()
    return raw


def consume_email_action(db: DBSession, raw_token: str, kind: str) -> User:
    token = db.scalar(
        select(EmailActionToken).where(
            EmailActionToken.token_hash == sha256_text(raw_token),
            EmailActionToken.kind == kind,
        )
    )
    if token is None or token.used_at is not None or as_utc(token.expires_at) <= utcnow_aware():
        raise AuthError('invalid_or_expired_token', 'Token is invalid or expired')
    user = db.get(User, token.user_id)
    if user is None:
        raise AuthError('invalid_or_expired_token', 'Token is invalid or expired')
    token.used_at = utcnow()
    if kind == 'verify_email':
        user.email_verified = True
    db.flush()
    return user


def authenticate_password(db: DBSession, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == email.lower()))
    if user is None or not verify_password(password, user.password_hash):
        raise AuthError('invalid_credentials')
    if not user.email_verified:
        raise AuthError('email_not_verified', 'Email address has not been verified')
    if user.deletion_started_at is not None:
        raise AuthError('account_deleted', 'Account is unavailable')
    return user


def change_password(db: DBSession, user: User, current_password: str, new_password: str, *, keep_session_id: uuid.UUID | None = None) -> None:
    if not verify_password(current_password, user.password_hash):
        raise AuthError('invalid_credentials')
    user.password_hash = hash_password(new_password)
    stmt = update(Session).where(Session.user_id == user.id, Session.revoked_at.is_(None))
    if keep_session_id is not None:
        stmt = stmt.where(Session.id != keep_session_id)
    db.execute(stmt.values(revoked_at=utcnow()))
    db.commit()


def reset_password(db: DBSession, raw_token: str, new_password: str) -> None:
    user = consume_email_action(db, raw_token, 'reset_password')
    user.password_hash = hash_password(new_password)
    db.execute(update(Session).where(Session.user_id == user.id, Session.revoked_at.is_(None)).values(revoked_at=utcnow()))
    db.commit()
