from pathlib import Path
import re

root = Path(__file__).parent
service = root / 'GhostStream/Intelligence/SourceDiagnosticsService.swift'
probe = root / 'GhostStream/Intelligence/MediaProbe.swift'
sanitizer = root / 'GhostStream/Intelligence/DiagnosticSanitizer.swift'

for path in (service, probe, sanitizer):
    assert path.exists(), f'missing {path.relative_to(root)}'

text = service.read_text() + '\n' + probe.read_text() + '\n' + sanitizer.read_text()

for category in (
    'networkUnavailable',
    'dnsFailure',
    'timeout',
    'authenticationFailed',
    'notFound',
    'malformedSource',
    'unsupportedMedia',
    'providerUnavailable',
    'unknown',
):
    assert category in text, f'missing diagnostic error category: {category}'

sanitized = sanitizer.read_text()
for forbidden in ('rawURL', 'serverURL', 'username', 'password', 'authorizationHeader', 'playlistBody', 'm3uText'):
    assert not re.search(rf'\b(?:let|var)\s+{forbidden}\s*:', sanitized), (
        f'sanitized diagnostic model exposes secret/raw field: {forbidden}'
    )

for required in (
    'healthScore',
    'responseTimeMs',
    'latencyMs',
    'bitrateMbps',
    'videoCodec',
    'audioCodec',
    'container',
    'bufferingEvents',
    'compatibility',
):
    assert required in sanitized, f'missing sanitized diagnostic metric: {required}'

print('ghoststream2 diagnostics contract: PASS')
