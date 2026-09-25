"""add pairing target device metadata

Revision ID: 0002_pairing_target
Revises: 0001_initial
Create Date: 2026-09-25
"""
from alembic import op
import sqlalchemy as sa

revision = '0002_pairing_target'
down_revision = '0001_initial'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('pairing_sessions', sa.Column('target_device_id', sa.Uuid(), nullable=True))
    op.add_column('pairing_sessions', sa.Column('target_os_version', sa.String(length=64), nullable=False, server_default=''))
    op.create_index(op.f('ix_pairing_sessions_target_device_id'), 'pairing_sessions', ['target_device_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_pairing_sessions_target_device_id'), table_name='pairing_sessions')
    op.drop_column('pairing_sessions', 'target_os_version')
    op.drop_column('pairing_sessions', 'target_device_id')
