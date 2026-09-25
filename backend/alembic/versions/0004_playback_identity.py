"""add playback identity metadata

Revision ID: 0004_playback_identity
Revises: 0003_credential_transfer
Create Date: 2026-09-25
"""
from alembic import op
import sqlalchemy as sa

revision = '0004_playback_identity'
down_revision = '0003_credential_transfer'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('playback_progress', sa.Column('title', sa.String(length=255), nullable=True))
    op.add_column('playback_progress', sa.Column('series_id', sa.Integer(), nullable=True))


def downgrade():
    op.drop_column('playback_progress', 'series_id')
    op.drop_column('playback_progress', 'title')
