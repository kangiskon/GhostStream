from pathlib import Path


def test_deployment_keeps_api_behind_nginx_and_smoke_covers_core_account_flow():
    nginx = Path('nginx-ghoststream-api.conf.example').read_text()
    compose = Path('docker-compose.example.yml').read_text()
    smoke = Path('scripts/smoke_test.sh').read_text()

    assert 'proxy_pass http://ghoststream-api:8098;' in nginx
    assert 'location ^~ /api/' in nginx
    assert 'ports:' not in compose
    assert '/ghoststream-api-health' in smoke
    assert '/api/v1/auth/login' in smoke
    assert '/api/v1/devices' in smoke
    assert '/api/v1/auth/refresh' in smoke
    assert '/api/v1/account/state' in smoke
    assert '/api/v1/deletion/account' in smoke
