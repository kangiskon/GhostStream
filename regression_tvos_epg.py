from pathlib import Path
root=Path(__file__).parent
app=(root/'GhostStreamTV/GhostStreamTVApp.swift').read_text()
view=(root/'GhostStreamTV/TVRootView.swift').read_text()
models=(root/'GhostStreamTV/Shared/Models.swift').read_text()
proj=(root/'GhostStreamTV.xcodeproj/project.pbxproj').read_text()
assert '@StateObject private var epg = EPGService()' in app
assert '.environmentObject(epg)' in app
assert 'struct EPGProgramme' in models
assert 'TVLiveListRow' in view and 'let now: EPGProgramme?' in view and 'let next: EPGProgramme?' in view
assert 'NOW' in view and 'NEXT' in view
assert 'epgChannelId:' in view
assert 'TVLiveEPGOverlay' in view
assert 'EPGService.swift in Sources' in proj
assert 'XMLTVParser.swift in Sources' in proj
print('PASS: tvOS EPG integration present')
