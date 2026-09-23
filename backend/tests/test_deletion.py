import uuid

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import (
    DeletionTombstone, Device, DiagnosticSnapshot, Favorite, PlaybackProgress,
    Session, SourceProfile, SyncEvent, User,
)
from ghoststream_api.services.auth_service import issue_session


def make_account():
    device_id = uuid.uuid4()
    with SessionLocal() as db:
        user = User(email='delete@example.com', email_verified=True, password_hash=None)
        db.add(user)
        db.flush()
        device = Device(
            id=device_id, user_id=user.id, display_name='Delete iPhone', platform='ios',
            os_version='26.7', public_key='Z' * 44, trust_state='trusted',
        )
        db.add(device)
        db.flush()
        pair = issue_session(db, user.id, device_id)
        source_id = uuid.uuid4()
        db.add(SourceProfile(user_id=user.id, source_id=source_id, display_name='Main', kind='provider', fingerprint='fp', capabilities={'live': True}))
        db.add(Favorite(user_id=user.id, source_id=source_id, content_kind='vod', content_id='movie-1'))
        db.add(PlaybackProgress(user_id=user.id, source_id=source_id, content_kind='vod', content_id='movie-1', position_seconds=30, duration_seconds=100, last_device_id=device_id))
        db.add(DiagnosticSnapshot(user_id=user.id, source_id=source_id, device_class='iphone', health_score=90))
        db.add(SyncEvent(user_id=user.id, cursor=1, entity_type='source', entity_key=str(source_id), operation='upsert', payload={}))
        user_id = user.id
        db.commit()
    return pair, user_id, device_id


def auth(access_token):
    return {'Authorization': f'Bearer {access_token}'}


def test_account_deletion_removes_personal_rows_and_leaves_only_hashed_tombstones():
    pair, user_id, device_id = make_account()
    client = TestClient(app)
    response = client.post('/api/v1/deletion/account', headers=auth(pair.access_token), json={'confirmation': 'DELETE'})
    assert response.status_code == 200
    assert response.json() == {'deleted': True}

    with SessionLocal() as db:
        assert db.get(User, user_id) is None
        assert db.get(Device, device_id) is None
        assert db.scalar(select(func.count()).select_from(Session)) == 0
        assert db.scalar(select(func.count()).select_from(SourceProfile)) == 0
        assert db.scalar(select(func.count()).select_from(Favorite)) == 0
        assert db.scalar(select(func.count()).select_from(PlaybackProgress)) == 0
        assert db.scalar(select(func.count()).select_from(DiagnosticSnapshot)) == 0
        assert db.scalar(select(func.count()).select_from(SyncEvent)) == 0
        tombstones = list(db.scalars(select(DeletionTombstone)))
        assert len(tombstones) >= 3
        assert all(len(item.identifier_hash) == 64 for item in tombstones)
        assert all(str(device_id) not in item.identifier_hash for item in tombstones)
        assert all(pair.refresh_token not in item.identifier_hash for item in tombstones)


def test_deleted_offline_device_gets_410_from_old_access_and_refresh_tokens():
    pair, _, _ = make_account()
    client = TestClient(app)
    assert client.post('/api/v1/deletion/account', headers=auth(pair.access_token), json={'confirmation': 'DELETE'}).status_code == 200

    state = client.get('/api/v1/account/state', headers=auth(pair.access_token))
    assert state.status_code == 410
    assert state.json()['detail']['code'] == 'account_deleted'

    refresh = client.post('/api/v1/auth/refresh', json={'refresh_token': pair.refresh_token})
    assert refresh.status_code == 410
    assert refresh.json()['detail']['code'] == 'account_deleted'
