from __future__ import annotations

import uuid
from datetime import timedelta

from sqlalchemy import delete, select
from sqlalchemy.orm import Session as DBSession

from ..models import CredentialTransfer, Device, utcnow
from ..schemas import CredentialTransferCreateRequest
from .auth_service import AuthContext


class TransferError(Exception):
    def __init__(self, code: str, status_code: int, message: str):
        super().__init__(message)
        self.code = code
        self.status_code = status_code
        self.message = message


def create_transfer(
    db: DBSession,
    context: AuthContext,
    recipient_device_id: uuid.UUID,
    payload: CredentialTransferCreateRequest,
) -> CredentialTransfer:
    recipient = db.scalar(select(Device).where(
        Device.id == recipient_device_id,
        Device.user_id == context.user.id,
    ))
    if recipient is None:
        raise TransferError('device_not_found', 404, 'Recipient device was not found')
    if recipient.revoked_at is not None or recipient.trust_state != 'trusted':
        raise TransferError('device_revoked', 410, 'Recipient device is not trusted')
    if recipient.id == context.device.id:
        raise TransferError('same_device_transfer', 409, 'A device cannot transfer credentials to itself')

    transfer = CredentialTransfer(
        sender_device_id=context.device.id,
        recipient_device_id=recipient.id,
        ephemeral_public_key=payload.ephemeral_public_key,
        nonce=payload.nonce,
        ciphertext=payload.ciphertext,
        expires_at=utcnow() + timedelta(minutes=10),
    )
    db.add(transfer)
    db.commit()
    return transfer


def list_inbox(db: DBSession, context: AuthContext) -> list[CredentialTransfer]:
    now = utcnow()
    db.execute(delete(CredentialTransfer).where(CredentialTransfer.expires_at <= now))
    items = list(db.scalars(select(CredentialTransfer).where(
        CredentialTransfer.recipient_device_id == context.device.id,
        CredentialTransfer.expires_at > now,
    ).order_by(CredentialTransfer.created_at.asc())))
    db.commit()
    return items


def acknowledge_transfer(db: DBSession, context: AuthContext, transfer_id: uuid.UUID) -> None:
    transfer = db.scalar(select(CredentialTransfer).where(
        CredentialTransfer.id == transfer_id,
        CredentialTransfer.recipient_device_id == context.device.id,
    ))
    if transfer is None:
        raise TransferError('transfer_not_found', 404, 'Transfer was not found')
    db.delete(transfer)
    db.commit()
