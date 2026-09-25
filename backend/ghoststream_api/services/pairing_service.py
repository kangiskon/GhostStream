from __future__ import annotations

import secrets
import uuid
from datetime import timedelta
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.orm import Session as DBSession

from ..config import get_settings
from ..models import Device, PairingSession, utcnow
from ..schemas import PairingClaimRequest, PairingSessionCreateRequest, TokenPair
from ..security import as_utc, new_secret, sha256_text, utcnow as utcnow_aware
from .auth_service import AuthContext, issue_session


class PairingError(Exception):
    def __init__(self, code: str, status_code: int, message: str):
        super().__init__(message)
        self.code = code
        self.status_code = status_code
        self.message = message


def _ensure_not_expired(db: DBSession, session: PairingSession) -> None:
    if as_utc(session.expires_at) <= utcnow_aware():
        if session.state not in {'approved', 'rejected', 'expired'}:
            session.state = 'expired'
            db.commit()
        raise PairingError('pairing_expired', 410, 'Pairing session has expired')


def _require_qr_token(session: PairingSession, raw_token: str) -> None:
    if not secrets.compare_digest(session.qr_token_hash, sha256_text(raw_token)):
        raise PairingError('invalid_pairing_token', 403, 'Pairing token is invalid')


def create_pairing(db: DBSession, payload: PairingSessionCreateRequest) -> tuple[PairingSession, str, str, str]:
    now = utcnow()
    pairing_id = uuid.uuid4()

    manual_code = ''
    for _ in range(20):
        candidate = f'{secrets.randbelow(1_000_000):06d}'
        candidate_hash = sha256_text(candidate)
        collision = db.scalar(select(PairingSession.id).where(
            PairingSession.code_hash == candidate_hash,
            PairingSession.expires_at > now,
            PairingSession.state.in_(['pending', 'claimed']),
        ))
        if collision is None:
            manual_code = candidate
            break
    if not manual_code:
        raise PairingError('pairing_capacity', 503, 'Unable to allocate a pairing code')

    qr_token = new_secret()
    pairing = PairingSession(
        id=pairing_id,
        target_device_id=payload.device_id,
        target_public_key=payload.public_key,
        target_display_name=payload.display_name,
        target_platform=payload.platform,
        target_os_version=payload.os_version,
        code_hash=sha256_text(manual_code),
        qr_token_hash=sha256_text(qr_token),
        state='pending',
        expires_at=now + timedelta(minutes=5),
    )
    db.add(pairing)
    db.commit()

    base = get_settings().public_web_base_url.rstrip('/')
    qr_payload = f'{base}/pair?' + urlencode({
        'pairing_id': str(pairing.id),
        'token': qr_token,
    })
    return pairing, manual_code, qr_token, qr_payload


def find_pairing_for_claim(db: DBSession, payload: PairingClaimRequest) -> PairingSession:
    if payload.manual_code is not None:
        pairing = db.scalar(select(PairingSession).where(
            PairingSession.code_hash == sha256_text(payload.manual_code)
        ))
    else:
        pairing = db.get(PairingSession, payload.pairing_id)
        if pairing is not None:
            _require_qr_token(pairing, payload.qr_token or '')
    if pairing is None:
        raise PairingError('pairing_not_found', 404, 'Pairing session was not found')
    return pairing


def claim_pairing(db: DBSession, payload: PairingClaimRequest, context: AuthContext) -> PairingSession:
    pairing = find_pairing_for_claim(db, payload)
    _ensure_not_expired(db, pairing)
    if pairing.state != 'pending':
        raise PairingError('pairing_already_claimed', 409, 'Pairing session is no longer available')
    pairing.user_id = context.user.id
    pairing.initiating_device_id = context.device.id
    pairing.state = 'claimed'
    db.commit()
    return pairing


def approve_pairing(db: DBSession, pairing_id: uuid.UUID, approve: bool, context: AuthContext) -> PairingSession:
    pairing = db.get(PairingSession, pairing_id)
    if pairing is None:
        raise PairingError('pairing_not_found', 404, 'Pairing session was not found')
    _ensure_not_expired(db, pairing)
    if pairing.state != 'claimed':
        raise PairingError('pairing_not_claimed', 409, 'Pairing session is not awaiting approval')
    if pairing.user_id != context.user.id or pairing.initiating_device_id != context.device.id:
        raise PairingError('pairing_forbidden', 403, 'Only the claiming trusted device may approve this pairing')

    if not approve:
        pairing.state = 'rejected'
        pairing.consumed_at = utcnow()
        db.commit()
        return pairing

    device = db.get(Device, pairing.target_device_id)
    if device is not None and device.user_id != context.user.id:
        raise PairingError('device_owned_by_other_account', 409, 'Target device belongs to another account')
    if device is None:
        device = Device(
            id=pairing.target_device_id,
            user_id=context.user.id,
            display_name=pairing.target_display_name,
            platform=pairing.target_platform,
            os_version=pairing.target_os_version,
            public_key=pairing.target_public_key,
            trust_state='trusted',
        )
        db.add(device)
    else:
        device.display_name = pairing.target_display_name
        device.platform = pairing.target_platform
        device.os_version = pairing.target_os_version
        device.public_key = pairing.target_public_key
        device.trust_state = 'trusted'
        device.revoked_at = None
        device.last_seen_at = utcnow()

    pairing.state = 'approved'
    db.commit()
    return pairing


def pairing_state(db: DBSession, pairing_id: uuid.UUID, raw_token: str) -> PairingSession:
    pairing = db.get(PairingSession, pairing_id)
    if pairing is None:
        raise PairingError('pairing_not_found', 404, 'Pairing session was not found')
    _require_qr_token(pairing, raw_token)
    if as_utc(pairing.expires_at) <= utcnow_aware() and pairing.state not in {'approved', 'rejected'}:
        pairing.state = 'expired'
        db.commit()
    return pairing


def complete_pairing(db: DBSession, pairing_id: uuid.UUID, raw_token: str) -> TokenPair:
    pairing = db.get(PairingSession, pairing_id)
    if pairing is None:
        raise PairingError('pairing_not_found', 404, 'Pairing session was not found')
    _require_qr_token(pairing, raw_token)
    _ensure_not_expired(db, pairing)
    if pairing.state != 'approved' or pairing.user_id is None:
        raise PairingError('pairing_not_approved', 409, 'Pairing has not been approved')
    if pairing.consumed_at is not None:
        raise PairingError('pairing_already_completed', 409, 'Pairing session has already been completed')
    device = db.get(Device, pairing.target_device_id)
    if device is None or device.user_id != pairing.user_id or device.revoked_at is not None:
        raise PairingError('paired_device_unavailable', 409, 'Paired device is unavailable')

    pair = issue_session(db, pairing.user_id, device.id)
    pairing.consumed_at = utcnow()
    db.commit()
    return pair
