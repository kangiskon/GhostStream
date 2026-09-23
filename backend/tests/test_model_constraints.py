import pytest
from pydantic import ValidationError


def make_payload(**extra):
    payload = {
        'source_id': '11111111-1111-1111-1111-111111111111',
        'display_name': 'Main',
        'kind': 'provider',
        'fingerprint': 'a' * 64,
        'capabilities': {'live': True, 'movies': True, 'series': True},
    }
    payload.update(extra)
    return payload


@pytest.mark.parametrize('field,value', [
    ('password', 'secret'),
    ('authorization', 'Bearer secret'),
    ('playlist_body', '#EXTM3U'),
    ('raw_url', 'https://example.invalid/list.m3u'),
])
def test_source_profile_schema_rejects_secret_fields(field, value):
    from ghoststream_api.schemas import SourceProfileUpsert
    with pytest.raises(ValidationError):
        SourceProfileUpsert(**make_payload(**{field: value}))


def test_diagnostic_schema_rejects_non_finite_metrics():
    from ghoststream_api.schemas import DiagnosticSnapshotUpsert
    with pytest.raises(ValidationError):
        DiagnosticSnapshotUpsert(
            source_id='11111111-1111-1111-1111-111111111111',
            device_class='iphone',
            health_score=85,
            duration_seconds=float('nan'),
        )


def test_source_profile_fingerprint_must_be_sha256_hex_not_a_raw_url():
    from ghoststream_api.schemas import SourceProfileUpsert
    with pytest.raises(ValidationError):
        SourceProfileUpsert(**make_payload(fingerprint='https://provider.example/user/list.m3u'))
    valid = SourceProfileUpsert(**make_payload(fingerprint='a' * 64))
    assert valid.fingerprint == 'a' * 64
