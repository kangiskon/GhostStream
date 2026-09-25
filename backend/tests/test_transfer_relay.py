from datetime import timedelta
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import Device, User, utcnow
from ghoststream_api.services.auth_service import issue_session


def make_two_devices():
    with SessionLocal() as db:
        user = User(email='relay@example.com', email_verified=True, password_hash=None)
        db.add(user)
        db.flush()
        sender = Device(
            id=uuid.uuid4(), user_id=user.id, display_name='Sender iPhone',
            platform='ios', os_version='26.7', public_key='S' * 44, trust_state='trusted',
        )
        recipient = Device(
            id=uuid.uuid4(), user_id=user.id, display_name='Living Room TV',
            platform='tvos', os_version='26.0', public_key='R' * 44, trust_state='trusted',
        )
        db.add_all([sender, recipient])
        db.flush()
        sender_pair = issue_session(db, user.id, sender.id)
        recipient_pair = issue_session(db, user.id, recipient.id)
        db.commit()
    return sender, recipient, sender_pair, recipient_pair


def auth(token: str) -> dict[str, str]:
    return {'Authorization': f'Bearer {token}'}


def envelope():
    return {
        'ephemeral_public_key': 'E' * 44,
        'nonce': 'Tm9uY2VCYXNlNjQ=',
        'ciphertext': 'Q2hhQ2hhUG9seVNlYWxlZENpcGhlcnRleHRCYXNlNjQ=',
    }


def test_transfer_rejects_plaintext_credential_fields():
    sender, recipient, sender_pair, _ = make_two_devices()
    client = TestClient(app)
    for field, value in (
        ('password', 'secret'),
        ('username', 'user'),
        ('server_url', 'https://provider.invalid'),
        ('playlist_body', '#EXTM3U'),
    ):
        body = envelope()
        body[field] = value
        response = client.post(
            f'/api/v1/devices/{recipient.id}/transfers',
            headers=auth(sender_pair.access_token),
            json=body,
        )
        assert response.status_code == 422


def test_only_recipient_can_fetch_and_acknowledge_transfer():
    sender, recipient, sender_pair, recipient_pair = make_two_devices()
    client = TestClient(app)
    created = client.post(
        f'/api/v1/devices/{recipient.id}/transfers',
        headers=auth(sender_pair.access_token),
        json=envelope(),
    )
    assert created.status_code == 201
    transfer_id = created.json()['id']

    sender_inbox = client.get('/api/v1/devices/me/transfers', headers=auth(sender_pair.access_token))
    assert sender_inbox.status_code == 200
    assert sender_inbox.json() == []

    recipient_inbox = client.get('/api/v1/devices/me/transfers', headers=auth(recipient_pair.access_token))
    assert recipient_inbox.status_code == 200
    assert [item['id'] for item in recipient_inbox.json()] == [transfer_id]

    denied = client.delete(f'/api/v1/devices/me/transfers/{transfer_id}', headers=auth(sender_pair.access_token))
    assert denied.status_code == 404

    ack = client.delete(f'/api/v1/devices/me/transfers/{transfer_id}', headers=auth(recipient_pair.access_token))
    assert ack.status_code == 204

    empty = client.get('/api/v1/devices/me/transfers', headers=auth(recipient_pair.access_token))
    assert empty.status_code == 200
    assert empty.json() == []


def test_transfer_to_revoked_or_other_account_device_is_rejected():
    sender, recipient, sender_pair, _ = make_two_devices()
    client = TestClient(app)

    with SessionLocal() as db:
        target = db.get(Device, recipient.id)
        target.revoked_at = utcnow()
        target.trust_state = 'revoked'
        db.commit()

    revoked = client.post(
        f'/api/v1/devices/{recipient.id}/transfers',
        headers=auth(sender_pair.access_token),
        json=envelope(),
    )
    assert revoked.status_code in (403, 410)

    with SessionLocal() as db:
        other = User(email='other@example.com', email_verified=True, password_hash=None)
        db.add(other)
        db.flush()
        other_device = Device(
            id=uuid.uuid4(), user_id=other.id, display_name='Other TV',
            platform='tvos', os_version='26.0', public_key='O' * 44, trust_state='trusted',
        )
        db.add(other_device)
        other_id = other_device.id
        db.commit()

    foreign = client.post(
        f'/api/v1/devices/{other_id}/transfers',
        headers=auth(sender_pair.access_token),
        json=envelope(),
    )
    assert foreign.status_code == 404


def test_expired_transfer_is_not_returned():
    sender, recipient, sender_pair, recipient_pair = make_two_devices()
    client = TestClient(app)
    created = client.post(
        f'/api/v1/devices/{recipient.id}/transfers',
        headers=auth(sender_pair.access_token),
        json=envelope(),
    )
    assert created.status_code == 201

    from ghoststream_api.models import CredentialTransfer
    with SessionLocal() as db:
        transfer = db.scalar(select(CredentialTransfer))
        transfer.expires_at = utcnow() - timedelta(seconds=1)
        db.commit()

    inbox = client.get('/api/v1/devices/me/transfers', headers=auth(recipient_pair.access_token))
    assert inbox.status_code == 200
    assert inbox.json() == []


def test_revoking_device_purges_queued_transfers():
    sender, recipient, sender_pair, _ = make_two_devices()
    client = TestClient(app)
    created = client.post(
        f'/api/v1/devices/{recipient.id}/transfers',
        headers=auth(sender_pair.access_token),
        json=envelope(),
    )
    assert created.status_code == 201

    revoked = client.delete(
        f'/api/v1/devices/{recipient.id}',
        headers=auth(sender_pair.access_token),
    )
    assert revoked.status_code == 204

    from ghoststream_api.models import CredentialTransfer
    with SessionLocal() as db:
        assert db.scalar(select(CredentialTransfer)) is None
