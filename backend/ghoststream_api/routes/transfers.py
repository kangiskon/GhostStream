from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session as DBSession

from ..db import get_session
from ..routes.auth import current_session
from ..schemas import CredentialTransferCreateRequest, CredentialTransferDTO
from ..services.auth_service import AuthContext
from ..services.transfer_service import TransferError, acknowledge_transfer, create_transfer, list_inbox

router = APIRouter(prefix='/api/v1/devices', tags=['credential-transfers'])


def _raise(error: TransferError) -> None:
    raise HTTPException(
        status_code=error.status_code,
        detail={'code': error.code, 'message': error.message},
    )


def _dto(item) -> CredentialTransferDTO:
    return CredentialTransferDTO(
        id=item.id,
        sender_device_id=item.sender_device_id,
        recipient_device_id=item.recipient_device_id,
        ephemeral_public_key=item.ephemeral_public_key,
        nonce=item.nonce,
        ciphertext=item.ciphertext,
        created_at=item.created_at,
        expires_at=item.expires_at,
    )


@router.post('/{device_id}/transfers', response_model=CredentialTransferDTO, status_code=201)
def send_transfer(
    device_id: uuid.UUID,
    payload: CredentialTransferCreateRequest,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> CredentialTransferDTO:
    try:
        return _dto(create_transfer(db, context, device_id, payload))
    except TransferError as error:
        _raise(error)


@router.get('/me/transfers', response_model=list[CredentialTransferDTO])
def inbox(
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> list[CredentialTransferDTO]:
    return [_dto(item) for item in list_inbox(db, context)]


@router.delete('/me/transfers/{transfer_id}', status_code=204)
def acknowledge(
    transfer_id: uuid.UUID,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> Response:
    try:
        acknowledge_transfer(db, context, transfer_id)
    except TransferError as error:
        _raise(error)
    return Response(status_code=204)
