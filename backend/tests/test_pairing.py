from datetime import timedelta
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import Device, PairingSession, User, utcnow
from ghoststream_api.services.auth_service import issue_session


def trusted_account():
    trusted_id = uuid.uuid4()
    with SessionLocal() as db:
        user = User(email='pairing@example.com', email_verified=True, password_hash=None)
        db.add(user)
        db.flush()
        db.add(Device(
            id=trusted_id,
            user_id=user.id,
            display_name='Trusted iPhone',
            platform='ios',
            os_version='26.7',
            public_key='T' * 44,
            trust_state='trusted',
        ))
        db.flush()
        pair = issue_session(db, user.id, trusted_id)
        db.commit()
    return pair.access_token, user.id, trusted_id


def auth(token: str) -> dict[str, str]:
    return {'Authorization': f'Bearer {token}'}


def new_target_payload():
    return {
        'device_id': str(uuid.uuid4()),
        'display_name': 'Living Room Apple TV',
        'platform': 'tvos',
        'os_version': '26.0',
        'public_key': 'N' * 44,
    }


def test_pairing_session_returns_plain_code_but_persists_only_hashes():
    client = TestClient(app)
    response = client.post('/api/v1/pairing/sessions', json=new_target_payload())
    assert response.status_code == 201
    body = response.json()
    assert len(body['manual_code']) == 6
    assert body['manual_code'].isdigit()
    assert body['qr_payload'].startswith('https://ghoststreams.ink/pair?')
    assert body['qr_token'] in body['qr_payload']
    assert 'password=' not in body['qr_payload']
    assert 'username=' not in body['qr_payload']

    with SessionLocal() as db:
        session = db.get(PairingSession, uuid.UUID(body['pairing_id']))
        assert session is not None
        assert session.code_hash != body['manual_code']
        assert session.qr_token_hash != body['qr_token']
        assert len(session.code_hash) == 64
        assert len(session.qr_token_hash) == 64


def test_pairing_code_is_single_use_and_approval_registers_target_device():
    client = TestClient(app)
    access, user_id, trusted_id = trusted_account()
    target = new_target_payload()
    created = client.post('/api/v1/pairing/sessions', json=target).json()

    claim = client.post(
        '/api/v1/pairing/claim',
        headers=auth(access),
        json={'manual_code': created['manual_code']},
    )
    assert claim.status_code == 200
    assert claim.json()['display_name'] == target['display_name']

    approved = client.post(
        f"/api/v1/pairing/{created['pairing_id']}/approve",
        headers=auth(access),
        json={'approve': True},
    )
    assert approved.status_code == 200
    assert approved.json()['state'] == 'approved'

    reused = client.post(
        '/api/v1/pairing/claim',
        headers=auth(access),
        json={'manual_code': created['manual_code']},
    )
    assert reused.status_code in (409, 410)

    with SessionLocal() as db:
        device = db.get(Device, uuid.UUID(target['device_id']))
        assert device is not None
        assert device.user_id == user_id
        assert device.trust_state == 'trusted'
        pairing = db.get(PairingSession, uuid.UUID(created['pairing_id']))
        assert pairing.initiating_device_id == trusted_id
        assert pairing.state == 'approved'


def test_expired_pairing_session_cannot_be_claimed_or_approved():
    client = TestClient(app)
    access, _, _ = trusted_account()
    created = client.post('/api/v1/pairing/sessions', json=new_target_payload()).json()

    with SessionLocal() as db:
        session = db.get(PairingSession, uuid.UUID(created['pairing_id']))
        session.expires_at = utcnow() - timedelta(seconds=1)
        db.commit()

    claim = client.post(
        '/api/v1/pairing/claim',
        headers=auth(access),
        json={'manual_code': created['manual_code']},
    )
    assert claim.status_code == 410

    approve = client.post(
        f"/api/v1/pairing/{created['pairing_id']}/approve",
        headers=auth(access),
        json={'approve': True},
    )
    assert approve.status_code == 410


def test_qr_claim_requires_pairing_id_and_server_token_not_credentials():
    client = TestClient(app)
    access, _, _ = trusted_account()
    created = client.post('/api/v1/pairing/sessions', json=new_target_payload()).json()

    claim = client.post('/api/v1/pairing/claim', headers=auth(access), json={
        'pairing_id': created['pairing_id'],
        'qr_token': created['qr_token'],
    })
    assert claim.status_code == 200
    assert 'password' not in claim.json()
    assert 'credentials' not in claim.json()


def test_target_can_poll_state_only_with_its_pairing_token():
    client = TestClient(app)
    created = client.post('/api/v1/pairing/sessions', json=new_target_payload()).json()

    no_token = client.get(f"/api/v1/pairing/{created['pairing_id']}/state")
    assert no_token.status_code in (401, 403)

    wrong = client.get(f"/api/v1/pairing/{created['pairing_id']}/state?token={'x' * 48}")
    assert wrong.status_code in (401, 403)

    good = client.get(
        f"/api/v1/pairing/{created['pairing_id']}/state",
        params={'token': created['qr_token']},
    )
    assert good.status_code == 200
    assert good.json()['state'] == 'pending'
