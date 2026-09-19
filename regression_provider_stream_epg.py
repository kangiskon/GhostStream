from pathlib import Path
root = Path(__file__).parent
checks = []
for rel in [
    'GhostStream/Services/XtreamClient.swift',
    'GhostStreamTV/Shared/XtreamClient.swift',
]:
    t = (root/rel).read_text()
    checks.append(('short_epg endpoint in '+rel, 'get_short_epg' in t and 'stream_id' in t))
for rel in [
    'GhostStream/Services/EPGService.swift',
    'GhostStreamTV/Shared/EPGService.swift',
]:
    t=(root/rel).read_text()
    checks.append(('provider per-stream loader in '+rel, 'ensureProviderEPG' in t and 'streamId' in t))
    checks.append(('no XMLTV dependency in '+rel, 'XMLTVParser' not in t and 'xmltv' not in t.lower()))
for rel in ['GhostStream/Views/LiveView.swift','GhostStreamTV/TVRootView.swift']:
    t=(root/rel).read_text()
    checks.append(('visible live rows trigger EPG load in '+rel, 'ensureProviderEPG' in t))
failed=[name for name,ok in checks if not ok]
if failed:
    print('FAIL')
    for name in failed: print('-', name)
    raise SystemExit(1)
print('PASS')
