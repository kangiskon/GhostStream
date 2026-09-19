from pathlib import Path
p = Path('GhostStream/Views/PlayerView.swift').read_text()
required = [
    'private var liveMockupOverlay',
    'Text("Live TV - EPG")',
    'accessibilityLabel("Back")',
    'Text("Guide")',
    'title: "Favorite"',
    'title: "Channels"',
    'title: "Audio"',
    'title: "Subtitles"',
    'title: "More"',
    'upcomingProgrammes',
    'currentProgramme',
    'PlayerEPGProgressBar',
]
missing = [x for x in required if x not in p]
assert not missing, f'Missing Live mockup player elements: {missing}'
print('PASS: Live mockup player layout markers are present')
