from __future__ import annotations

import uuid
from datetime import timedelta

from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session as DBSession

from ..models import (
    CredentialTransfer,
    DeletionTombstone,
    Device,
    DiagnosticSnapshot,
    EmailActionToken,
    Favorite,
    PairingSession,
    PlaybackProgress,
    Session as AccountSession,
    SourceProfile,
    SyncEvent,
    User,
    utcnow,
)
from ..security import sha256_text


def tombstone_hash(kind: str, value: str) -> str:
    return sha256_text(f'{kind}:{value}')


def identifier_is_tombstoned(db: DBSession, kind: str, value: str) -> bool:
    now = utcnow()
    expected = tombstone_hash(kind, value)
    return db.scalar(select(DeletionTombstone.id).where(
        DeletionTombstone.identifier_hash == expected,
        DeletionTombstone.kind == kind,
        DeletionTombstone.expires_at > now,
    )) is not None


def _add_tombstone(db: DBSession, kind: str, value: str) -> None:
    hashed = tombstone_hash(kind, value)
    existing = db.scalar(select(DeletionTombstone).where(DeletionTombstone.identifier_hash == hashed))
    if existing is None:
        db.add(DeletionTombstone(
            identifier_hash=hashed,
            kind=kind,
            expires_at=utcnow() + timedelta(days=90),
        ))


def delete_account(db: DBSession, user_id: uuid.UUID) -> None:
    user = db.get(User, user_id)
    if user is None:
        return

    sessions = list(db.scalars(select(AccountSession).where(AccountSession.user_id == user_id)))
    devices = list(db.scalars(select(Device).where(Device.user_id == user_id)))

    _add_tombstone(db, 'user_id', str(user_id))
    for session in sessions:
        _add_tombstone(db, 'session_id', str(session.id))
        _add_tombstone(db, 'refresh_hash', session.refresh_token_hash)
    for device in devices:
        _add_tombstone(db, 'device_id', str(device.id))
    db.flush()

    device_ids = [device.id for device in devices]
    if device_ids:
        db.execute(delete(CredentialTransfer).where(or_(
            CredentialTransfer.sender_device_id.in_(device_ids),
            CredentialTransfer.recipient_device_id.in_(device_ids),
        )))

    for model in (
        SyncEvent,
        DiagnosticSnapshot,
        PlaybackProgress,
        Favorite,
        SourceProfile,
        PairingSession,
        EmailActionToken,
        AccountSession,
        Device,
    ):
        db.execute(delete(model).where(model.user_id == user_id))
    db.delete(user)
    db.commit()
