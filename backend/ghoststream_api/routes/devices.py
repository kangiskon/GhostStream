from __future__ import annotations

import uuid
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, update
from sqlalchemy.orm import Session as DBSession

from ..db import get_session
from ..models import Device, Session, utcnow
from ..routes.auth import current_session
from ..schemas import DeviceDTO, DeviceRegisterRequest, DeviceUpdateRequest
from ..services.auth_service import AuthContext, AuthError, upsert_device

router = APIRouter(prefix='/api/v1/devices', tags=['devices'])


def to_dto(device: Device) -> DeviceDTO:
    return DeviceDTO(
        id=device.id,
        display_name=device.display_name,
        platform=device.platform,
        os_version=device.os_version,
        public_key=device.public_key,
        trust_state=device.trust_state,
        last_seen_at=device.last_seen_at,
        revoked_at=device.revoked_at,
    )


@router.post('/register', response_model=DeviceDTO)
def register_device(payload: DeviceRegisterRequest, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> DeviceDTO:
    if payload.device_id != context.device.id:
        raise HTTPException(status_code=403, detail={'code': 'pairing_required'})
    try:
        device = upsert_device(
            db,
            user_id=context.user.id,
            device_id=payload.device_id,
            display_name=payload.display_name,
            platform=payload.platform,
            os_version=payload.os_version,
            public_key=payload.public_key,
        )
        db.commit()
    except AuthError as error:
        db.rollback()
        raise HTTPException(status_code=409, detail={'code': error.code})
    return to_dto(device)


@router.get('', response_model=list[DeviceDTO])
def list_devices(context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> list[DeviceDTO]:
    devices = db.scalars(select(Device).where(Device.user_id == context.user.id).order_by(Device.created_at.asc()))
    return [to_dto(device) for device in devices]


@router.patch('/{device_id}', response_model=DeviceDTO)
def rename_device(device_id: uuid.UUID, payload: DeviceUpdateRequest, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> DeviceDTO:
    device = db.scalar(select(Device).where(Device.id == device_id, Device.user_id == context.user.id))
    if device is None:
        raise HTTPException(status_code=404, detail={'code': 'device_not_found'})
    device.display_name = payload.display_name
    db.commit()
    return to_dto(device)


@router.delete('/{device_id}', status_code=204)
def revoke_device(device_id: uuid.UUID, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> Response:
    device = db.scalar(select(Device).where(Device.id == device_id, Device.user_id == context.user.id))
    if device is None:
        raise HTTPException(status_code=404, detail={'code': 'device_not_found'})
    device.revoked_at = utcnow()
    device.trust_state = 'revoked'
    db.execute(update(Session).where(Session.device_id == device.id, Session.revoked_at.is_(None)).values(revoked_at=utcnow()))
    db.commit()
    return Response(status_code=204)
