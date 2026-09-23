from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session as DBSession

from ..models import DiagnosticSnapshot, Favorite, PlaybackProgress, SourceProfile, SyncEvent, User, utcnow
from ..schemas import DiagnosticSnapshotUpsert, FavoriteUpsert, PlaybackProgressUpsert, SourceProfileUpsert, SyncPushRequest
from ..security import as_utc


def _json_ready(value: Any) -> Any:
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _json_ready(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_ready(v) for v in value]
    return value


def emit_event(db: DBSession, user: User, entity_type: str, entity_key: str, operation: str, payload: dict[str, Any]) -> int:
    locked_user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if locked_user is None:
        raise ValueError('user no longer exists')
    locked_user.sync_cursor = int(locked_user.sync_cursor or 0) + 1
    event = SyncEvent(
        user_id=locked_user.id,
        cursor=locked_user.sync_cursor,
        entity_type=entity_type,
        entity_key=entity_key,
        operation=operation,
        payload=_json_ready(payload),
    )
    db.add(event)
    db.flush()
    return locked_user.sync_cursor


def upsert_source(db: DBSession, user: User, item: SourceProfileUpsert) -> SourceProfile:
    source = db.scalar(select(SourceProfile).where(SourceProfile.user_id == user.id, SourceProfile.source_id == item.source_id))
    incoming_time = item.updated_at or datetime.now(timezone.utc)
    if source is None:
        source = SourceProfile(
            user_id=user.id,
            source_id=item.source_id,
            display_name=item.display_name,
            kind=item.kind,
            fingerprint=item.fingerprint,
            capabilities=item.capabilities,
            updated_at=incoming_time,
        )
        db.add(source)
        changed = True
    elif as_utc(source.updated_at) < as_utc(incoming_time):
        source.display_name = item.display_name
        source.kind = item.kind
        source.fingerprint = item.fingerprint
        source.capabilities = item.capabilities
        source.updated_at = incoming_time
        changed = True
    else:
        changed = False
    if changed:
        emit_event(db, user, 'source', str(item.source_id), 'upsert', item.model_dump(mode='json', exclude_none=True))
    db.flush()
    return source


def upsert_progress(db: DBSession, user: User, device_id: uuid.UUID, item: PlaybackProgressUpsert) -> PlaybackProgress:
    progress = db.scalar(select(PlaybackProgress).where(
        PlaybackProgress.user_id == user.id,
        PlaybackProgress.source_id == item.source_id,
        PlaybackProgress.content_kind == item.content_kind,
        PlaybackProgress.content_id == item.content_id,
    ))
    if progress is None:
        progress = PlaybackProgress(
            user_id=user.id,
            source_id=item.source_id,
            content_kind=item.content_kind,
            content_id=item.content_id,
            position_seconds=item.position_seconds,
            duration_seconds=item.duration_seconds,
            completed=item.completed,
            last_device_id=device_id,
            updated_at=item.updated_at,
        )
        db.add(progress)
        changed = True
    elif as_utc(progress.updated_at) < as_utc(item.updated_at):
        progress.position_seconds = item.position_seconds
        progress.duration_seconds = item.duration_seconds
        progress.completed = item.completed
        progress.last_device_id = device_id
        progress.updated_at = item.updated_at
        changed = True
    else:
        changed = False
    if changed:
        emit_event(db, user, 'progress', f'{item.content_kind}:{item.content_id}', 'upsert', item.model_dump(mode='json'))
    db.flush()
    return progress


def apply_favorite(db: DBSession, user: User, item: FavoriteUpsert) -> None:
    favorite = db.scalar(select(Favorite).where(
        Favorite.user_id == user.id,
        Favorite.source_id == item.source_id,
        Favorite.content_kind == item.content_kind,
        Favorite.content_id == item.content_id,
    ))
    key = f'{item.content_kind}:{item.content_id}'
    if item.is_favorite:
        if favorite is None:
            favorite = Favorite(
                user_id=user.id,
                source_id=item.source_id,
                content_kind=item.content_kind,
                content_id=item.content_id,
                updated_at=item.updated_at,
            )
            db.add(favorite)
            emit_event(db, user, 'favorite', key, 'upsert', item.model_dump(mode='json'))
        elif as_utc(favorite.updated_at) < as_utc(item.updated_at):
            favorite.updated_at = item.updated_at
            emit_event(db, user, 'favorite', key, 'upsert', item.model_dump(mode='json'))
    elif favorite is not None:
        db.delete(favorite)
        emit_event(db, user, 'favorite', key, 'delete', {'updated_at': item.updated_at.isoformat()})


def add_diagnostic(db: DBSession, user: User, item: DiagnosticSnapshotUpsert) -> DiagnosticSnapshot:
    diagnostic = DiagnosticSnapshot(
        user_id=user.id,
        source_id=item.source_id,
        device_class=item.device_class,
        health_score=item.health_score,
        response_time_ms=item.response_time_ms,
        latency_ms=item.latency_ms,
        bitrate_mbps=item.bitrate_mbps,
        width=item.width,
        height=item.height,
        video_codec=item.video_codec,
        audio_codec=item.audio_codec,
        container=item.container,
        buffering_events=item.buffering_events,
        error_category=item.error_category,
        compatibility=item.compatibility,
        duration_seconds=item.duration_seconds,
        created_at=item.created_at or utcnow(),
    )
    db.add(diagnostic)
    emit_event(db, user, 'diagnostic', str(item.source_id), 'append', item.model_dump(mode='json', exclude_none=True))
    db.flush()
    return diagnostic


def apply_sync_push(db: DBSession, user: User, device_id: uuid.UUID, payload: SyncPushRequest) -> int:
    for item in payload.sources:
        upsert_source(db, user, item)
    for item in payload.favorites:
        apply_favorite(db, user, item)
    for item in payload.progress:
        upsert_progress(db, user, device_id, item)
    for item in payload.diagnostics:
        add_diagnostic(db, user, item)
    if payload.settings is not None:
        user.sync_settings = payload.settings.model_dump(exclude_none=True)
        emit_event(db, user, 'settings', 'account', 'upsert', user.sync_settings)
    db.commit()
    return int(user.sync_cursor or 0)


def pull_events(db: DBSession, user: User, since: int) -> list[SyncEvent]:
    return list(db.scalars(select(SyncEvent).where(
        SyncEvent.user_id == user.id,
        SyncEvent.cursor > max(0, since),
    ).order_by(SyncEvent.cursor.asc())))
