from pathlib import Path
p = Path('GhostStream/Views/PlayerView.swift').read_text()
assert 'private func timeRange(_ programme: EPGProgramme) -> String' in p, 'missing timeRange helper'
assert 'private func shortTime(_ date: Date) -> String' in p, 'missing shortTime helper'
print('PASS: Live EPG time-formatting helpers are present')
