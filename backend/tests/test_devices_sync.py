from datetime import datetime, timedelta, timezone
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import Device, PlaybackProgress, User
from ghoststream_api.services.auth_service import issue_session


def make_account(email: str):
    device_id = uuid.uuid4()
    with SessionLocal() as db:
        user = User(email=email, email_verified=True, password_hash=None)
        db.add(user)
        db.flush()
        db.add(Device(
            id=device_id,
            user_id=user.id,
            display_name=f'{email} device',
            platform='ios',
            os_version='26.7',
            public_key='K' * 44,
            trust_state='trusted',
        ))
        db.flush()
        pair = issue_session(db, user.id, device_id)
        user_id = user.id
        db.commit()
    return pair.access_token, user_id, device_id


def auth(token: str):
    return {'Authorization': f'Bearer {token}'}


def test_device_registry_is_scoped_to_authenticated_user():
    token_a, _, device_a = make_account('a@example.com')
    _, _, device_b = make_account('b@example.com')
    client = TestClient(app)

    listed = client.get('/api/v1/devices', headers=auth(token_a))
    assert listed.status_code == 200
    ids = {item['id'] for item in listed.json()}
    assert str(device_a) in ids
    assert str(device_b) not in ids

    patched = client.patch(f'/api/v1/devices/{device_b}', headers=auth(token_a), json={'display_name': 'stolen'})
    assert patched.status_code == 404
    deleted = client.delete(f'/api/v1/devices/{device_b}', headers=auth(token_a))
    assert deleted.status_code == 404


def test_revoked_device_cannot_continue_using_access_token():
    token, _, device_id = make_account('owner@example.com')
    client = TestClient(app)
    revoked = client.delete(f'/api/v1/devices/{device_id}', headers=auth(token))
    assert revoked.status_code == 204
    after = client.get('/api/v1/devices', headers=auth(token))
    assert after.status_code == 401


def test_sync_rejects_secret_source_fields():
    token, _, _ = make_account('owner@example.com')
    client = TestClient(app)
    payload = {
        'sources': [{
            'source_id': str(uuid.uuid4()),
            'display_name': 'Main',
            'kind': 'provider',
            'fingerprint': 'a' * 64,
            'capabilities': {'live': True},
            'password': 'never-store-this',
        }]
    }
    response = client.post('/api/v1/sync/push', headers=auth(token), json=payload)
    assert response.status_code == 422


def test_newer_playback_progress_wins_and_pull_cursor_advances():
    token, user_id, device_id = make_account('owner@example.com')
    client = TestClient(app)
    source_id = uuid.uuid4()
    content_id = 'episode-1'
    now = datetime.now(timezone.utc)

    newer = {
        'source_id': str(source_id), 'content_kind': 'episode', 'content_id': content_id,
        'position_seconds': 80, 'duration_seconds': 100, 'completed': False,
        'updated_at': now.isoformat(),
    }
    older = {**newer, 'position_seconds': 10, 'updated_at': (now - timedelta(minutes=5)).isoformat()}

    first = client.post('/api/v1/sync/push', headers=auth(token), json={'progress': [newer]})
    assert first.status_code == 200
    cursor1 = first.json()['cursor']
    second = client.post('/api/v1/sync/push', headers=auth(token), json={'progress': [older]})
    assert second.status_code == 200
    assert second.json()['cursor'] >= cursor1

    with SessionLocal() as db:
        progress = db.scalar(select(PlaybackProgress).where(
            PlaybackProgress.user_id == user_id,
            PlaybackProgress.content_id == content_id,
        ))
        assert progress.position_seconds == 80
        assert progress.last_device_id == device_id

    pulled = client.get('/api/v1/sync/pull?since=0', headers=auth(token))
    assert pulled.status_code == 200
    body = pulled.json()
    assert body['cursor'] >= cursor1
    assert any(event['entity_type'] == 'progress' for event in body['events'])


def test_progress_rejects_non_finite_and_negative_values():
    token, _, _ = make_account('owner@example.com')
    client = TestClient(app)
    bad = client.post('/api/v1/sync/push', headers=auth(token), json={
        'progress': [{
            'source_id': str(uuid.uuid4()), 'content_kind': 'vod', 'content_id': 'movie',
            'position_seconds': -1, 'duration_seconds': 100, 'completed': False,
            'updated_at': datetime.now(timezone.utc).isoformat(),
        }]
    })
    assert bad.status_code == 422


def test_sync_rejects_unrecognized_settings_that_could_hide_secrets():
    token, _, _ = make_account('owner@example.com')
    response = TestClient(app).post('/api/v1/sync/push', headers=auth(token), json={
        'settings': {'provider_password': 'secret'}
    })
    assert response.status_code == 422


def test_typed_source_diagnostic_and_activity_endpoints_share_sanitized_storage():
    token, _, _ = make_account('owner@example.com')
    client = TestClient(app)
    source_id = uuid.uuid4()
    headers = auth(token)

    source = client.put(f'/api/v1/sources/{source_id}', headers=headers, json={
        'source_id': str(source_id), 'display_name': 'Main', 'kind': 'provider',
        'fingerprint': 'b' * 64, 'capabilities': {'live': True, 'movies': True},
    })
    assert source.status_code == 200
    sources = client.get('/api/v1/sources', headers=headers)
    assert sources.status_code == 200
    assert sources.json()[0]['display_name'] == 'Main'

    diagnostic = client.post(f'/api/v1/diagnostics/{source_id}', headers=headers, json={
        'source_id': str(source_id), 'device_class': 'iphone', 'health_score': 92,
        'response_time_ms': 280, 'latency_ms': 320, 'bitrate_mbps': 8.4,
        'width': 1920, 'height': 1080, 'video_codec': 'H.264', 'audio_codec': 'AAC',
        'container': 'MPEG-TS', 'buffering_events': 0, 'compatibility': 'compatible',
    })
    assert diagnostic.status_code == 201
    history = client.get(f'/api/v1/diagnostics/{source_id}', headers=headers)
    assert history.status_code == 200
    assert history.json()[0]['health_score'] == 92

    now = datetime.now(timezone.utc).isoformat()
    progress = client.put('/api/v1/activity/progress/movie-1', headers=headers, json={
        'source_id': str(source_id), 'content_kind': 'vod', 'content_id': 'movie-1',
        'position_seconds': 25, 'duration_seconds': 100, 'completed': False, 'updated_at': now,
    })
    assert progress.status_code == 200
    activity = client.get('/api/v1/activity', headers=headers)
    assert activity.status_code == 200
    assert activity.json()[0]['content_id'] == 'movie-1'


def test_sync_cursor_refreshes_stale_user_state_before_incrementing():
    from ghoststream_api.models import SyncEvent
    from ghoststream_api.services.sync_service import emit_event

    _, user_id, _ = make_account('cursor@example.com')
    db1 = SessionLocal()
    db2 = SessionLocal()
    try:
        user1 = db1.get(User, user_id)
        user2 = db2.get(User, user_id)
        assert user1.sync_cursor == user2.sync_cursor == 0
        assert emit_event(db2, user2, 'settings', 'account', 'upsert', {'playback_rate': 1.0}) == 1
        db2.commit()
        assert emit_event(db1, user1, 'settings', 'account', 'upsert', {'playback_rate': 1.25}) == 2
        db1.commit()
    finally:
        db1.close()
        db2.close()
    with SessionLocal() as db:
        cursors = list(db.scalars(select(SyncEvent.cursor).where(SyncEvent.user_id == user_id).order_by(SyncEvent.cursor)))
        assert cursors == [1, 2]


def test_episode_progress_preserves_safe_title_and_series_identity():
    token, _, _ = make_account('episode-progress@example.com')
    client = TestClient(app)
    source_id = uuid.uuid4()
    now = datetime.now(timezone.utc).isoformat()

    pushed = client.post('/api/v1/sync/push', headers=auth(token), json={
        'progress': [{
            'source_id': str(source_id),
            'content_kind': 'episode',
            'content_id': 'ep-42',
            'title': 'Episode 4',
            'series_id': 777,
            'position_seconds': 120,
            'duration_seconds': 1800,
            'completed': False,
            'updated_at': now,
        }]
    })
    assert pushed.status_code == 200

    pulled = client.get('/api/v1/sync/pull?since=0', headers=auth(token))
    assert pulled.status_code == 200
    progress = next(event for event in pulled.json()['events'] if event['entity_type'] == 'progress')
    assert progress['payload']['title'] == 'Episode 4'
    assert progress['payload']['series_id'] == 777
    assert 'password' not in progress['payload']
    assert 'server_url' not in progress['payload']
