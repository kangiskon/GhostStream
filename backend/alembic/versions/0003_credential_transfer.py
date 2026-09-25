"""add opaque credential transfer relay

Revision ID: 0003_credential_transfer
Revises: 0002_pairing_target
Create Date: 2026-09-25
"""
from alembic import op
import sqlalchemy as sa

revision = '0003_credential_transfer'
down_revision = '0002_pairing_target'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'credential_transfers',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('sender_device_id', sa.Uuid(), nullable=False),
        sa.Column('recipient_device_id', sa.Uuid(), nullable=False),
        sa.Column('ephemeral_public_key', sa.Text(), nullable=False),
        sa.Column('nonce', sa.String(length=128), nullable=False),
        sa.Column('ciphertext', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['sender_device_id'], ['devices.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['recipient_device_id'], ['devices.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_credential_transfers_sender_device_id'), 'credential_transfers', ['sender_device_id'])
    op.create_index(op.f('ix_credential_transfers_recipient_device_id'), 'credential_transfers', ['recipient_device_id'])
    op.create_index(op.f('ix_credential_transfers_expires_at'), 'credential_transfers', ['expires_at'])
    op.create_index('ix_credential_transfers_recipient_expiry', 'credential_transfers', ['recipient_device_id', 'expires_at'])


def downgrade():
    op.drop_index('ix_credential_transfers_recipient_expiry', table_name='credential_transfers')
    op.drop_index(op.f('ix_credential_transfers_expires_at'), table_name='credential_transfers')
    op.drop_index(op.f('ix_credential_transfers_recipient_device_id'), table_name='credential_transfers')
    op.drop_index(op.f('ix_credential_transfers_sender_device_id'), table_name='credential_transfers')
    op.drop_table('credential_transfers')
