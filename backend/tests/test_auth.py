import hashlib
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import EmailActionToken, Session, User


DEVICE_ID = str(uuid.uuid4())
PUBLIC_KEY = 'A' * 44


def register_payload(email='owner@example.com', password='correct-horse-battery'):
    return {
        'email': email,
        'password': password,
        'device_id': DEVICE_ID,
        'display_name': 'Justin iPhone',
        'platform': 'ios',
        'os_version': '26.7',
        'public_key': PUBLIC_KEY,
    }


def login_payload(password='correct-horse-battery'):
    return {
        'email': 'owner@example.com',
        'password': password,
        'device_id': DEVICE_ID,
        'display_name': 'Justin iPhone',
        'platform': 'ios',
        'os_version': '26.7',
        'public_key': PUBLIC_KEY,
    }


def verify_latest_email_token(raw_token: str):
    response = TestClient(app).post('/api/v1/auth/verify-email', json={'token': raw_token})
    assert response.status_code == 200


def test_registration_hashes_password_and_stores_only_hashed_verification_token(monkeypatch):
    sent = {}
    monkeypatch.setattr('ghoststream_api.routes.auth.send_verification_email', lambda email, token: sent.update(email=email, token=token))
    response = TestClient(app).post('/api/v1/auth/register', json=register_payload())
    assert response.status_code == 201
    assert response.json()['verification_required'] is True
    assert sent['email'] == 'owner@example.com'
    assert len(sent['token']) >= 32

    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == 'owner@example.com'))
        token = db.scalar(select(EmailActionToken).where(EmailActionToken.user_id == user.id))
        assert user.password_hash != 'correct-horse-battery'
        assert 'correct-horse-battery' not in user.password_hash
        assert token.token_hash == hashlib.sha256(sent['token'].encode()).hexdigest()
        assert token.token_hash != sent['token']


def test_verified_user_can_login_and_invalid_password_is_401(monkeypatch):
    sent = {}
    monkeypatch.setattr('ghoststream_api.routes.auth.send_verification_email', lambda email, token: sent.update(token=token))
    client = TestClient(app)
    assert client.post('/api/v1/auth/register', json=register_payload()).status_code == 201
    verify_latest_email_token(sent['token'])

    ok = client.post('/api/v1/auth/login', json=login_payload())
    assert ok.status_code == 200
    body = ok.json()
    assert body['access_token']
    assert body['refresh_token']

    bad = client.post('/api/v1/auth/login', json=login_payload('wrong-password'))
    assert bad.status_code == 401

    with SessionLocal() as db:
        session = db.scalar(select(Session).order_by(Session.created_at.desc()))
        assert session.refresh_token_hash == hashlib.sha256(body['refresh_token'].encode()).hexdigest()
        assert session.refresh_token_hash != body['refresh_token']


def test_refresh_rotates_and_replay_revokes_family(monkeypatch):
    sent = {}
    monkeypatch.setattr('ghoststream_api.routes.auth.send_verification_email', lambda email, token: sent.update(token=token))
    client = TestClient(app)
    client.post('/api/v1/auth/register', json=register_payload())
    verify_latest_email_token(sent['token'])
    first = client.post('/api/v1/auth/login', json=login_payload()).json()

    rotated = client.post('/api/v1/auth/refresh', json={'refresh_token': first['refresh_token']})
    assert rotated.status_code == 200
    second = rotated.json()
    assert second['refresh_token'] != first['refresh_token']

    replay = client.post('/api/v1/auth/refresh', json={'refresh_token': first['refresh_token']})
    assert replay.status_code == 401
    newest = client.post('/api/v1/auth/refresh', json={'refresh_token': second['refresh_token']})
    assert newest.status_code == 401


def test_forgot_password_has_same_public_response_for_known_and_unknown_email(monkeypatch):
    monkeypatch.setattr('ghoststream_api.routes.auth.send_reset_email', lambda email, token: None)
    client = TestClient(app)
    known = client.post('/api/v1/auth/forgot-password', json={'email': 'known@example.com'})
    unknown = client.post('/api/v1/auth/forgot-password', json={'email': 'unknown@example.com'})
    assert known.status_code == unknown.status_code == 202
    assert known.json() == unknown.json() == {'accepted': True}


def test_default_jwt_secret_meets_hs256_minimum_length():
    from ghoststream_api.config import Settings
    assert len(Settings().jwt_secret.encode('utf-8')) >= 32
