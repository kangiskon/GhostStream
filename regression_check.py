from pathlib import Path
import re, sys
s=Path('/mnt/data/debug_latest/GhostStream/Views/PlayerView.swift').read_text()
blocks=re.findall(r'func updateUIView\(_ uiView: [^\{]+\{(.*?)\n    \}', s, re.S)
if len(blocks) < 2:
    print('FAIL: expected two updateUIView implementations'); sys.exit(1)
for i,b in enumerate(blocks,1):
    if 'DispatchQueue.main.async {' not in b:
        print(f'FAIL updateUIView #{i}: player work is not deferred'); sys.exit(1)
    pre=b.split('DispatchQueue.main.async {',1)[0]
    for token in ['coordinator.update(', 'coordinator.handlePlaybackCommand(', 'coordinator.seek(']:
        if token in pre:
            print(f'FAIL updateUIView #{i}: synchronous {token}'); sys.exit(1)
print('PASS: representable player work is deferred outside SwiftUI updateUIView')
