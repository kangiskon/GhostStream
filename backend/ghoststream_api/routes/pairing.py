from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session as DBSession

from ..db import get_session
from ..routes.auth import current_session
from ..schemas import (
    PairingApproveRequest,
    PairingClaimRequest,
    PairingClaimResponse,
    PairingCompleteRequest,
    PairingSessionCreateRequest,
    PairingSessionResponse,
    PairingStateResponse,
    TokenPair,
)
from ..services.auth_service import AuthContext
from ..services.pairing_service import (
    PairingError,
    approve_pairing,
    claim_pairing,
    complete_pairing,
    create_pairing,
    pairing_state,
)

router = APIRouter(prefix='/api/v1/pairing', tags=['pairing'])


def _raise(error: PairingError) -> None:
    raise HTTPException(
        status_code=error.status_code,
        detail={'code': error.code, 'message': error.message},
    )


@router.post('/sessions', response_model=PairingSessionResponse, status_code=201)
def create_session(payload: PairingSessionCreateRequest, db: DBSession = Depends(get_session)) -> PairingSessionResponse:
    try:
        pairing, manual_code, qr_token, qr_payload = create_pairing(db, payload)
    except PairingError as error:
        _raise(error)
    return PairingSessionResponse(
        pairing_id=pairing.id,
        manual_code=manual_code,
        qr_token=qr_token,
        qr_payload=qr_payload,
        expires_at=pairing.expires_at,
    )


@router.post('/claim', response_model=PairingClaimResponse)
def claim(
    payload: PairingClaimRequest,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> PairingClaimResponse:
    try:
        pairing = claim_pairing(db, payload, context)
    except PairingError as error:
        _raise(error)
    return PairingClaimResponse(
        pairing_id=pairing.id,
        device_id=pairing.target_device_id,
        display_name=pairing.target_display_name,
        platform=pairing.target_platform,
        os_version=pairing.target_os_version,
        public_key=pairing.target_public_key,
        expires_at=pairing.expires_at,
    )


@router.post('/{pairing_id}/approve', response_model=PairingStateResponse)
def approve(
    pairing_id: uuid.UUID,
    payload: PairingApproveRequest,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> PairingStateResponse:
    try:
        pairing = approve_pairing(db, pairing_id, payload.approve, context)
    except PairingError as error:
        _raise(error)
    return PairingStateResponse(
        pairing_id=pairing.id,
        state=pairing.state,
        expires_at=pairing.expires_at,
        device_id=pairing.target_device_id,
        account_id=pairing.user_id if pairing.state == 'approved' else None,
    )


@router.get('/{pairing_id}/state', response_model=PairingStateResponse)
def state(
    pairing_id: uuid.UUID,
    token: str = Query(min_length=32),
    db: DBSession = Depends(get_session),
) -> PairingStateResponse:
    try:
        pairing = pairing_state(db, pairing_id, token)
    except PairingError as error:
        _raise(error)
    return PairingStateResponse(
        pairing_id=pairing.id,
        state=pairing.state,
        expires_at=pairing.expires_at,
        device_id=pairing.target_device_id,
        account_id=pairing.user_id if pairing.state == 'approved' else None,
    )


@router.post('/{pairing_id}/complete', response_model=TokenPair)
def complete(
    pairing_id: uuid.UUID,
    payload: PairingCompleteRequest,
    db: DBSession = Depends(get_session),
) -> TokenPair:
    try:
        return complete_pairing(db, pairing_id, payload.qr_token)
    except PairingError as error:
        _raise(error)
