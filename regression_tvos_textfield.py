from pathlib import Path
p = Path(__file__).parent / 'GhostStreamTV' / 'TVRootView.swift'
s = p.read_text()
assert '.roundedBorder' not in s, 'tvOS-incompatible .roundedBorder is still present'
assert 'tvInputStyle()' in s, 'custom tvOS-safe input styling is missing'
print('tvOS text-field regression check passed')
