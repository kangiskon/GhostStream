from pathlib import Path

p = Path('GhostStream/Views/RootTabView.swift')
s = p.read_text()

ipad_start = s.index('    private var iPadShell: some View {')
ipad_end = s.index('    private func reloadIfNeeded()', ipad_start)
ipad = s[ipad_start:ipad_end]

assert 'GhostPadSidebar' not in ipad, 'iPad shell still mounts persistent sidebar'
assert '.frame(width: 236)' not in ipad, 'iPad shell still reserves sidebar width'
assert 'iPadFullScreenDestination' in s, 'missing full-screen iPad destination wrapper'
assert 'Label("Back", systemImage: "chevron.left")' in s, 'missing visible iPad back button'
assert 'selectedTab = 0' in s, 'back button does not return to iPad Home'
assert 'if selectedTab == 0' in ipad, 'iPad shell does not distinguish Home from destination screens'

print('PASS: iPad uses full-screen destinations with a Back button and no persistent sidebar')
