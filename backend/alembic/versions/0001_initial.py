"""initial GhostStream 2 account schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-09-23
"""
from alembic import op
import sqlalchemy as sa

revision = '0001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('deletion_tombstones',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('identifier_hash', sa.String(length=64), nullable=False),
        sa.Column('kind', sa.String(length=24), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_deletion_tombstones_expires_at'), 'deletion_tombstones', ['expires_at'], unique=False)
    op.create_index(op.f('ix_deletion_tombstones_identifier_hash'), 'deletion_tombstones', ['identifier_hash'], unique=True)

    op.create_table('users',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('email', sa.String(length=320), nullable=False),
        sa.Column('email_verified', sa.Boolean(), nullable=False),
        sa.Column('password_hash', sa.String(length=512), nullable=True),
        sa.Column('apple_subject', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('deletion_started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sync_cursor', sa.Integer(), nullable=False),
        sa.Column('sync_settings', sa.JSON(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_apple_subject'), 'users', ['apple_subject'], unique=True)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    op.create_table('devices',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('display_name', sa.String(length=160), nullable=False),
        sa.Column('platform', sa.String(length=32), nullable=False),
        sa.Column('os_version', sa.String(length=64), nullable=False),
        sa.Column('public_key', sa.Text(), nullable=False),
        sa.Column('trust_state', sa.String(length=32), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('last_seen_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_devices_trust_state'), 'devices', ['trust_state'], unique=False)
    op.create_index(op.f('ix_devices_user_id'), 'devices', ['user_id'], unique=False)
    op.create_index('ix_devices_user_last_seen', 'devices', ['user_id', 'last_seen_at'], unique=False)

    op.create_table('diagnostic_snapshots',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('source_id', sa.Uuid(), nullable=False),
        sa.Column('device_class', sa.String(length=32), nullable=False),
        sa.Column('health_score', sa.Integer(), nullable=False),
        sa.Column('response_time_ms', sa.Float(), nullable=True),
        sa.Column('latency_ms', sa.Float(), nullable=True),
        sa.Column('bitrate_mbps', sa.Float(), nullable=True),
        sa.Column('width', sa.Integer(), nullable=True),
        sa.Column('height', sa.Integer(), nullable=True),
        sa.Column('video_codec', sa.String(length=80), nullable=True),
        sa.Column('audio_codec', sa.String(length=80), nullable=True),
        sa.Column('container', sa.String(length=80), nullable=True),
        sa.Column('buffering_events', sa.Integer(), nullable=False),
        sa.Column('error_category', sa.String(length=80), nullable=True),
        sa.Column('compatibility', sa.String(length=80), nullable=True),
        sa.Column('duration_seconds', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_diagnostic_snapshots_source_id'), 'diagnostic_snapshots', ['source_id'], unique=False)
    op.create_index(op.f('ix_diagnostic_snapshots_user_id'), 'diagnostic_snapshots', ['user_id'], unique=False)
    op.create_index('ix_diagnostics_source_timestamp', 'diagnostic_snapshots', ['user_id', 'source_id', 'created_at'], unique=False)

    op.create_table('email_action_tokens',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('kind', sa.String(length=32), nullable=False),
        sa.Column('token_hash', sa.String(length=64), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_email_action_tokens_token_hash'), 'email_action_tokens', ['token_hash'], unique=True)
    op.create_index(op.f('ix_email_action_tokens_user_id'), 'email_action_tokens', ['user_id'], unique=False)
    op.create_index('ix_email_action_user_kind', 'email_action_tokens', ['user_id', 'kind'], unique=False)

    op.create_table('favorites',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('source_id', sa.Uuid(), nullable=False),
        sa.Column('content_kind', sa.String(length=24), nullable=False),
        sa.Column('content_id', sa.String(length=255), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'source_id', 'content_kind', 'content_id', name='uq_favorite')
    )
    op.create_index(op.f('ix_favorites_source_id'), 'favorites', ['source_id'], unique=False)
    op.create_index(op.f('ix_favorites_user_id'), 'favorites', ['user_id'], unique=False)

    op.create_table('pairing_sessions',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=True),
        sa.Column('initiating_device_id', sa.Uuid(), nullable=True),
        sa.Column('target_public_key', sa.Text(), nullable=False),
        sa.Column('target_display_name', sa.String(length=160), nullable=False),
        sa.Column('target_platform', sa.String(length=32), nullable=False),
        sa.Column('code_hash', sa.String(length=64), nullable=False),
        sa.Column('qr_token_hash', sa.String(length=64), nullable=False),
        sa.Column('state', sa.String(length=32), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('consumed_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_pairing_sessions_code_hash'), 'pairing_sessions', ['code_hash'], unique=True)
    op.create_index(op.f('ix_pairing_sessions_qr_token_hash'), 'pairing_sessions', ['qr_token_hash'], unique=True)
    op.create_index(op.f('ix_pairing_sessions_state'), 'pairing_sessions', ['state'], unique=False)
    op.create_index(op.f('ix_pairing_sessions_user_id'), 'pairing_sessions', ['user_id'], unique=False)

    op.create_table('playback_progress',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('source_id', sa.Uuid(), nullable=False),
        sa.Column('content_kind', sa.String(length=24), nullable=False),
        sa.Column('content_id', sa.String(length=255), nullable=False),
        sa.Column('position_seconds', sa.Float(), nullable=False),
        sa.Column('duration_seconds', sa.Float(), nullable=False),
        sa.Column('completed', sa.Boolean(), nullable=False),
        sa.Column('last_device_id', sa.Uuid(), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'source_id', 'content_kind', 'content_id', name='uq_progress')
    )
    op.create_index(op.f('ix_playback_progress_source_id'), 'playback_progress', ['source_id'], unique=False)
    op.create_index(op.f('ix_playback_progress_updated_at'), 'playback_progress', ['updated_at'], unique=False)
    op.create_index(op.f('ix_playback_progress_user_id'), 'playback_progress', ['user_id'], unique=False)

    op.create_table('source_profiles',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('source_id', sa.Uuid(), nullable=False),
        sa.Column('display_name', sa.String(length=160), nullable=False),
        sa.Column('kind', sa.String(length=32), nullable=False),
        sa.Column('fingerprint', sa.String(length=64), nullable=False),
        sa.Column('capabilities', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'source_id', name='uq_source_profile_user_source')
    )
    op.create_index(op.f('ix_source_profiles_source_id'), 'source_profiles', ['source_id'], unique=False)
    op.create_index(op.f('ix_source_profiles_user_id'), 'source_profiles', ['user_id'], unique=False)

    op.create_table('sync_events',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('cursor', sa.Integer(), nullable=False),
        sa.Column('entity_type', sa.String(length=32), nullable=False),
        sa.Column('entity_key', sa.String(length=255), nullable=False),
        sa.Column('operation', sa.String(length=16), nullable=False),
        sa.Column('payload', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'cursor', name='uq_sync_event_user_cursor')
    )
    op.create_index('ix_sync_events_user_cursor', 'sync_events', ['user_id', 'cursor'], unique=False)
    op.create_index(op.f('ix_sync_events_user_id'), 'sync_events', ['user_id'], unique=False)

    op.create_table('sessions',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('device_id', sa.Uuid(), nullable=False),
        sa.Column('refresh_token_hash', sa.String(length=64), nullable=False),
        sa.Column('token_family_id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('rotated_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['device_id'], ['devices.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_sessions_device_id'), 'sessions', ['device_id'], unique=False)
    op.create_index(op.f('ix_sessions_refresh_token_hash'), 'sessions', ['refresh_token_hash'], unique=True)
    op.create_index(op.f('ix_sessions_token_family_id'), 'sessions', ['token_family_id'], unique=False)
    op.create_index('ix_sessions_user_device', 'sessions', ['user_id', 'device_id'], unique=False)
    op.create_index(op.f('ix_sessions_user_id'), 'sessions', ['user_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_sessions_user_id'), table_name='sessions')
    op.drop_index('ix_sessions_user_device', table_name='sessions')
    op.drop_index(op.f('ix_sessions_token_family_id'), table_name='sessions')
    op.drop_index(op.f('ix_sessions_refresh_token_hash'), table_name='sessions')
    op.drop_index(op.f('ix_sessions_device_id'), table_name='sessions')
    op.drop_table('sessions')
    op.drop_index(op.f('ix_sync_events_user_id'), table_name='sync_events')
    op.drop_index('ix_sync_events_user_cursor', table_name='sync_events')
    op.drop_table('sync_events')
    op.drop_index(op.f('ix_source_profiles_user_id'), table_name='source_profiles')
    op.drop_index(op.f('ix_source_profiles_source_id'), table_name='source_profiles')
    op.drop_table('source_profiles')
    op.drop_index(op.f('ix_playback_progress_user_id'), table_name='playback_progress')
    op.drop_index(op.f('ix_playback_progress_updated_at'), table_name='playback_progress')
    op.drop_index(op.f('ix_playback_progress_source_id'), table_name='playback_progress')
    op.drop_table('playback_progress')
    op.drop_index(op.f('ix_pairing_sessions_user_id'), table_name='pairing_sessions')
    op.drop_index(op.f('ix_pairing_sessions_state'), table_name='pairing_sessions')
    op.drop_index(op.f('ix_pairing_sessions_qr_token_hash'), table_name='pairing_sessions')
    op.drop_index(op.f('ix_pairing_sessions_code_hash'), table_name='pairing_sessions')
    op.drop_table('pairing_sessions')
    op.drop_index(op.f('ix_favorites_user_id'), table_name='favorites')
    op.drop_index(op.f('ix_favorites_source_id'), table_name='favorites')
    op.drop_table('favorites')
    op.drop_index('ix_email_action_user_kind', table_name='email_action_tokens')
    op.drop_index(op.f('ix_email_action_tokens_user_id'), table_name='email_action_tokens')
    op.drop_index(op.f('ix_email_action_tokens_token_hash'), table_name='email_action_tokens')
    op.drop_table('email_action_tokens')
    op.drop_index('ix_diagnostics_source_timestamp', table_name='diagnostic_snapshots')
    op.drop_index(op.f('ix_diagnostic_snapshots_user_id'), table_name='diagnostic_snapshots')
    op.drop_index(op.f('ix_diagnostic_snapshots_source_id'), table_name='diagnostic_snapshots')
    op.drop_table('diagnostic_snapshots')
    op.drop_index('ix_devices_user_last_seen', table_name='devices')
    op.drop_index(op.f('ix_devices_user_id'), table_name='devices')
    op.drop_index(op.f('ix_devices_trust_state'), table_name='devices')
    op.drop_table('devices')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_index(op.f('ix_users_apple_subject'), table_name='users')
    op.drop_table('users')
    op.drop_index(op.f('ix_deletion_tombstones_identifier_hash'), table_name='deletion_tombstones')
    op.drop_index(op.f('ix_deletion_tombstones_expires_at'), table_name='deletion_tombstones')
    op.drop_table('deletion_tombstones')
