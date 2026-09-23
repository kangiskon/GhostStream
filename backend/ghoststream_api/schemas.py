from __future__ import annotations

from datetime import datetime
from math import isfinite
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid')


class SourceProfileUpsert(StrictModel):
    source_id: UUID
    display_name: str = Field(min_length=1, max_length=160)
    kind: Literal['m3u_url', 'm3u_file', 'm3u_text', 'provider', 'direct']
    fingerprint: str = Field(min_length=1, max_length=128)
    capabilities: dict[str, bool] = Field(default_factory=dict)
    updated_at: datetime | None = None


class DiagnosticSnapshotUpsert(StrictModel):
    source_id: UUID
    device_class: str = Field(min_length=1, max_length=32)
    health_score: int = Field(ge=0, le=100)
    response_time_ms: float | None = Field(default=None, ge=0)
    latency_ms: float | None = Field(default=None, ge=0)
    bitrate_mbps: float | None = Field(default=None, ge=0)
    width: int | None = Field(default=None, ge=0)
    height: int | None = Field(default=None, ge=0)
    video_codec: str | None = Field(default=None, max_length=80)
    audio_codec: str | None = Field(default=None, max_length=80)
    container: str | None = Field(default=None, max_length=80)
    buffering_events: int = Field(default=0, ge=0)
    error_category: str | None = Field(default=None, max_length=80)
    compatibility: str | None = Field(default=None, max_length=80)
    duration_seconds: float | None = Field(default=None, ge=0)
    created_at: datetime | None = None

    @model_validator(mode='after')
    def finite_metrics(self):
        for field in ('response_time_ms', 'latency_ms', 'bitrate_mbps', 'duration_seconds'):
            value = getattr(self, field)
            if value is not None and not isfinite(value):
                raise ValueError(f'{field} must be finite')
        return self


class RegisterRequest(StrictModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=256)
    device_id: UUID
    display_name: str = Field(min_length=1, max_length=160)
    platform: str = Field(min_length=1, max_length=32)
    os_version: str = Field(default='', max_length=64)
    public_key: str = Field(min_length=16)

    @field_validator('email')
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class LoginRequest(StrictModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)
    device_id: UUID

    @field_validator('email')
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class RefreshRequest(StrictModel):
    refresh_token: str = Field(min_length=32)


class LogoutRequest(StrictModel):
    refresh_token: str = Field(min_length=32)


class TokenPair(StrictModel):
    access_token: str
    refresh_token: str
    token_type: str = 'bearer'
    expires_in: int


class AccountDTO(StrictModel):
    id: UUID
    email: str
    email_verified: bool
    created_at: datetime


class DeviceRegisterRequest(StrictModel):
    device_id: UUID
    display_name: str = Field(min_length=1, max_length=160)
    platform: str = Field(min_length=1, max_length=32)
    os_version: str = Field(default='', max_length=64)
    public_key: str = Field(min_length=16)


class DeviceDTO(StrictModel):
    id: UUID
    display_name: str
    platform: str
    os_version: str
    public_key: str
    trust_state: str
    last_seen_at: datetime
    revoked_at: datetime | None = None


class FavoriteUpsert(StrictModel):
    source_id: UUID
    content_kind: Literal['live', 'vod', 'series']
    content_id: str = Field(min_length=1, max_length=255)
    is_favorite: bool
    updated_at: datetime


class PlaybackProgressUpsert(StrictModel):
    source_id: UUID
    content_kind: Literal['vod', 'episode']
    content_id: str = Field(min_length=1, max_length=255)
    position_seconds: float = Field(ge=0)
    duration_seconds: float = Field(ge=0)
    completed: bool = False
    updated_at: datetime

    @model_validator(mode='after')
    def validate_numbers(self):
        if not isfinite(self.position_seconds) or not isfinite(self.duration_seconds):
            raise ValueError('progress values must be finite')
        if self.duration_seconds > 0 and self.position_seconds > self.duration_seconds * 1.05:
            raise ValueError('position exceeds duration')
        return self


class SyncPush(StrictModel):
    favorites: list[FavoriteUpsert] = Field(default_factory=list)
    progress: list[PlaybackProgressUpsert] = Field(default_factory=list)
    sources: list[SourceProfileUpsert] = Field(default_factory=list)
    diagnostics: list[DiagnosticSnapshotUpsert] = Field(default_factory=list)
    settings: dict[str, Any] = Field(default_factory=dict)
