from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Index, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = 'users'

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(512), nullable=True)
    apple_subject: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    deletion_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sync_cursor: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    sync_settings: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)


class Device(Base):
    __tablename__ = 'devices'
    __table_args__ = (Index('ix_devices_user_last_seen', 'user_id', 'last_seen_at'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    display_name: Mapped[str] = mapped_column(String(160))
    platform: Mapped[str] = mapped_column(String(32))
    os_version: Mapped[str] = mapped_column(String(64), default='')
    public_key: Mapped[str] = mapped_column(Text)
    trust_state: Mapped[str] = mapped_column(String(32), default='trusted', index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Session(Base):
    __tablename__ = 'sessions'
    __table_args__ = (Index('ix_sessions_user_device', 'user_id', 'device_id'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    device_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('devices.id', ondelete='CASCADE'), index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    token_family_id: Mapped[uuid.UUID] = mapped_column(default=uuid.uuid4, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    rotated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class EmailActionToken(Base):
    __tablename__ = 'email_action_tokens'
    __table_args__ = (Index('ix_email_action_user_kind', 'user_id', 'kind'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    kind: Mapped[str] = mapped_column(String(32))
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class SourceProfile(Base):
    __tablename__ = 'source_profiles'
    __table_args__ = (UniqueConstraint('user_id', 'source_id', name='uq_source_profile_user_source'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    source_id: Mapped[uuid.UUID] = mapped_column(index=True)
    display_name: Mapped[str] = mapped_column(String(160))
    kind: Mapped[str] = mapped_column(String(32))
    fingerprint: Mapped[str] = mapped_column(String(64))
    capabilities: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class Favorite(Base):
    __tablename__ = 'favorites'
    __table_args__ = (UniqueConstraint('user_id', 'source_id', 'content_kind', 'content_id', name='uq_favorite'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    source_id: Mapped[uuid.UUID] = mapped_column(index=True)
    content_kind: Mapped[str] = mapped_column(String(24))
    content_id: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class PlaybackProgress(Base):
    __tablename__ = 'playback_progress'
    __table_args__ = (UniqueConstraint('user_id', 'source_id', 'content_kind', 'content_id', name='uq_progress'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    source_id: Mapped[uuid.UUID] = mapped_column(index=True)
    content_kind: Mapped[str] = mapped_column(String(24))
    content_id: Mapped[str] = mapped_column(String(255))
    position_seconds: Mapped[float] = mapped_column(Float, default=0.0)
    duration_seconds: Mapped[float] = mapped_column(Float, default=0.0)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    last_device_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False, index=True)


class DiagnosticSnapshot(Base):
    __tablename__ = 'diagnostic_snapshots'
    __table_args__ = (Index('ix_diagnostics_source_timestamp', 'user_id', 'source_id', 'created_at'),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    source_id: Mapped[uuid.UUID] = mapped_column(index=True)
    device_class: Mapped[str] = mapped_column(String(32))
    health_score: Mapped[int] = mapped_column(Integer)
    response_time_ms: Mapped[float | None] = mapped_column(Float, nullable=True)
    latency_ms: Mapped[float | None] = mapped_column(Float, nullable=True)
    bitrate_mbps: Mapped[float | None] = mapped_column(Float, nullable=True)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    video_codec: Mapped[str | None] = mapped_column(String(80), nullable=True)
    audio_codec: Mapped[str | None] = mapped_column(String(80), nullable=True)
    container: Mapped[str | None] = mapped_column(String(80), nullable=True)
    buffering_events: Mapped[int] = mapped_column(Integer, default=0)
    error_category: Mapped[str | None] = mapped_column(String(80), nullable=True)
    compatibility: Mapped[str | None] = mapped_column(String(80), nullable=True)
    duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class PairingSession(Base):
    __tablename__ = 'pairing_sessions'

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=True, index=True)
    initiating_device_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    target_public_key: Mapped[str] = mapped_column(Text)
    target_display_name: Mapped[str] = mapped_column(String(160))
    target_platform: Mapped[str] = mapped_column(String(32))
    code_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    qr_token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    state: Mapped[str] = mapped_column(String(32), default='pending', index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class DeletionTombstone(Base):
    __tablename__ = 'deletion_tombstones'

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    identifier_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    kind: Mapped[str] = mapped_column(String(24))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)


class SyncEvent(Base):
    __tablename__ = 'sync_events'
    __table_args__ = (
        Index('ix_sync_events_user_cursor', 'user_id', 'cursor'),
        UniqueConstraint('user_id', 'cursor', name='uq_sync_event_user_cursor'),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    cursor: Mapped[int] = mapped_column(Integer)
    entity_type: Mapped[str] = mapped_column(String(32))
    entity_key: Mapped[str] = mapped_column(String(255))
    operation: Mapped[str] = mapped_column(String(16))
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
