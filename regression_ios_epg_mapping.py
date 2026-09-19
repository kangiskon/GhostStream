from pathlib import Path
root=Path(__file__).parent
svc=(root/'GhostStream/Services/EPGService.swift').read_text()
rootview=(root/'GhostStream/Views/RootTabView.swift').read_text()
live=(root/'GhostStream/Views/LiveView.swift').read_text()
checks={
'normalized name resolver': 'resolvedChannelId' in svc and 'normalizedChannelName' in svc,
'EPG reload independent': 'await epg.load(for: source)' in rootview and 'library.loadedSourceID != source.id' in rootview,
'live row uses resolver': 'epg.nowPlaying(channel:' in live and 'epg.upcoming(channel:' in live,
}
failed=[k for k,v in checks.items() if not v]
if failed:
    print('FAIL:', ', '.join(failed)); raise SystemExit(1)
print('PASS: EPG mapping and reload regression')
