import json
import time
import uuid

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from jwt.algorithms import RSAAlgorithm
from sqlalchemy import select

from ghoststream_api.db import SessionLocal
from ghoststream_api.main import app
from ghoststream_api.models import User

AUD = 'com.ghostapk.ghoststream.ios'
ISS = 'https://appleid.apple.com'


def make_keys():
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = json.loads(RSAAlgorithm.to_jwk(private.public_key()))
    public_jwk['kid'] = 'test-key'
    public_jwk['alg'] = 'RS256'
    return private, {'keys': [public_jwk]}


def make_token(private, *, aud=AUD, exp_offset=600, sub='apple-sub-1', email='relay@privaterelay.appleid.com'):
    now = int(time.time())
    return jwt.encode(
        {'iss': ISS, 'aud': aud, 'iat': now, 'exp': now + exp_offset, 'sub': sub, 'email': email},
        private,
        algorithm='RS256',
        headers={'kid': 'test-key'},
    )


def test_verify_apple_identity_token_accepts_valid_token_and_private_relay_email():
    from ghoststream_api.services.apple_auth import verify_apple_identity_token
    private, jwks = make_keys()
    identity = verify_apple_identity_token(make_token(private), jwks=jwks, allowed_audiences={AUD})
    assert identity.subject == 'apple-sub-1'
    assert identity.email == 'relay@privaterelay.appleid.com'


def test_verify_apple_identity_token_rejects_wrong_audience():
    from ghoststream_api.services.apple_auth import AppleAuthError, verify_apple_identity_token
    private, jwks = make_keys()
    with pytest.raises(AppleAuthError):
        verify_apple_identity_token(make_token(private, aud='wrong.app'), jwks=jwks, allowed_audiences={AUD})


def test_verify_apple_identity_token_rejects_expired_token():
    from ghoststream_api.services.apple_auth import AppleAuthError, verify_apple_identity_token
    private, jwks = make_keys()
    with pytest.raises(AppleAuthError):
        verify_apple_identity_token(make_token(private, exp_offset=-10), jwks=jwks, allowed_audiences={AUD})


def test_apple_route_keys_account_on_subject_not_email(monkeypatch):
    from ghoststream_api.services.apple_auth import AppleIdentity

    identities = [
        AppleIdentity(subject='stable-subject', email='first@privaterelay.appleid.com'),
        AppleIdentity(subject='stable-subject', email='changed@privaterelay.appleid.com'),
    ]
    monkeypatch.setattr('ghoststream_api.routes.auth.verify_apple_identity_token', lambda token: identities.pop(0))
    client = TestClient(app)
    device_id = str(uuid.uuid4())
    base = {
        'identity_token': 'token-value-is-long-enough',
        'device_id': device_id,
        'display_name': 'Justin iPhone',
        'platform': 'ios',
        'os_version': '26.7',
        'public_key': 'B' * 44,
    }
    first = client.post('/api/v1/auth/apple', json=base)
    second = client.post('/api/v1/auth/apple', json=base)
    assert first.status_code == second.status_code == 200
    with SessionLocal() as db:
        users = list(db.scalars(select(User).where(User.apple_subject == 'stable-subject')))
        assert len(users) == 1
        assert users[0].email == 'first@privaterelay.appleid.com'
