from __future__ import annotations

import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session as DBSession

from ..db import get_session
from ..models import DiagnosticSnapshot, PlaybackProgress, SourceProfile
from ..routes.auth import current_session
from ..schemas import DiagnosticSnapshotUpsert, PlaybackProgressUpsert, SourceProfileUpsert, SyncPushRequest
from ..services.auth_service import AuthContext
from ..services.sync_service import add_diagnostic, apply_sync_push, pull_events, upsert_progress, upsert_source

router = APIRouter(prefix='/api/v1/sync', tags=['sync'])
sources_router = APIRouter(prefix='/api/v1/sources', tags=['sources'])
diagnostics_router = APIRouter(prefix='/api/v1/diagnostics', tags=['diagnostics'])
activity_router = APIRouter(prefix='/api/v1/activity', tags=['activity'])


@router.post('/push')
def push(payload: SyncPushRequest, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> dict:
    cursor = apply_sync_push(db, context.user, context.device.id, payload)
    return {'cursor': cursor}


@router.get('/pull')
def pull(since: int = Query(default=0, ge=0), context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> dict:
    events = pull_events(db, context.user, since)
    return {
        'cursor': int(context.user.sync_cursor or 0),
        'events': [{
            'cursor': event.cursor,
            'entity_type': event.entity_type,
            'entity_key': event.entity_key,
            'operation': event.operation,
            'payload': event.payload,
            'created_at': event.created_at.isoformat(),
        } for event in events],
    }


@sources_router.get('')
def list_sources(context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> list[dict]:
    items = db.scalars(select(SourceProfile).where(SourceProfile.user_id == context.user.id).order_by(SourceProfile.created_at.asc()))
    return [{
        'source_id': str(item.source_id), 'display_name': item.display_name, 'kind': item.kind,
        'fingerprint': item.fingerprint, 'capabilities': item.capabilities,
        'updated_at': item.updated_at.isoformat(),
    } for item in items]


@sources_router.put('/{source_id}')
def put_source(source_id: uuid.UUID, payload: SourceProfileUpsert, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> dict:
    if source_id != payload.source_id:
        raise HTTPException(status_code=400, detail={'code': 'source_id_mismatch'})
    item = upsert_source(db, context.user, payload)
    db.commit()
    return {'source_id': str(item.source_id), 'display_name': item.display_name, 'kind': item.kind, 'fingerprint': item.fingerprint, 'capabilities': item.capabilities}


@diagnostics_router.post('/{source_id}', status_code=201)
def post_diagnostic(source_id: uuid.UUID, payload: DiagnosticSnapshotUpsert, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> dict:
    if source_id != payload.source_id:
        raise HTTPException(status_code=400, detail={'code': 'source_id_mismatch'})
    item = add_diagnostic(db, context.user, payload)
    db.commit()
    return {'id': str(item.id), 'health_score': item.health_score}


@diagnostics_router.get('/{source_id}')
def list_diagnostics(source_id: uuid.UUID, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> list[dict]:
    items = db.scalars(select(DiagnosticSnapshot).where(
        DiagnosticSnapshot.user_id == context.user.id,
        DiagnosticSnapshot.source_id == source_id,
    ).order_by(DiagnosticSnapshot.created_at.desc()).limit(100))
    return [{
        'id': str(item.id), 'source_id': str(item.source_id), 'device_class': item.device_class,
        'health_score': item.health_score, 'response_time_ms': item.response_time_ms,
        'latency_ms': item.latency_ms, 'bitrate_mbps': item.bitrate_mbps,
        'width': item.width, 'height': item.height, 'video_codec': item.video_codec,
        'audio_codec': item.audio_codec, 'container': item.container,
        'buffering_events': item.buffering_events, 'error_category': item.error_category,
        'compatibility': item.compatibility, 'created_at': item.created_at.isoformat(),
    } for item in items]


@activity_router.get('')
def list_activity(context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> list[dict]:
    items = db.scalars(select(PlaybackProgress).where(PlaybackProgress.user_id == context.user.id).order_by(PlaybackProgress.updated_at.desc()).limit(200))
    return [{
        'source_id': str(item.source_id), 'content_kind': item.content_kind, 'content_id': item.content_id,
        'title': item.title, 'series_id': item.series_id,
        'position_seconds': item.position_seconds, 'duration_seconds': item.duration_seconds,
        'completed': item.completed, 'last_device_id': str(item.last_device_id) if item.last_device_id else None,
        'updated_at': item.updated_at.isoformat(),
    } for item in items]


@activity_router.put('/progress/{content_id}')
def put_progress(content_id: str, payload: PlaybackProgressUpsert, context: AuthContext = Depends(current_session), db: DBSession = Depends(get_session)) -> dict:
    if content_id != payload.content_id:
        raise HTTPException(status_code=400, detail={'code': 'content_id_mismatch'})
    item = upsert_progress(db, context.user, context.device.id, payload)
    db.commit()
    return {'content_id': item.content_id, 'position_seconds': item.position_seconds, 'updated_at': item.updated_at.isoformat()}
