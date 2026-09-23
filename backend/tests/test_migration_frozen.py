from pathlib import Path

from ghoststream_api.models import SourceProfile


def test_initial_migration_is_frozen_and_not_bound_to_live_metadata():
    migration = Path('alembic/versions/0001_initial.py').read_text()
    assert 'Base.metadata' not in migration
    assert 'from ghoststream_api import models' not in migration
    assert "op.create_table('users'" in migration
    assert "op.create_table('sync_events'" in migration
    assert 'uq_sync_event_user_cursor' in migration


def test_source_fingerprint_database_column_matches_sha256_hex_length():
    assert SourceProfile.__table__.c.fingerprint.type.length == 64
