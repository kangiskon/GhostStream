from pathlib import Path
p = Path(__file__).parent / 'GhostStream/Views/LiveView.swift'
s = p.read_text()
assert 'GhostLivePreviewMode' in s
assert 'case phoneTap' in s and 'case padDelayed' in s
assert '0.75' in s, 'iPad preview delay must remain approximately 0.75s'
assert 'isMuted = true' in s
assert 'previewWorkItem?.cancel()' in s
assert 'onDisappear' in s and 'stopPreview' in s
assert 'lineLimit(2)' in s, 'category names must be allowed to wrap'
assert 'PlayerView(title:' in s and 'kind: .live' in s
print('PASS unified live preview')
