from pathlib import Path
p = Path('GhostStreamTV/TVRootView.swift').read_text()
assert p.count('Menu("Season \\(season)")') == 1, 'nested season menu must appear exactly once'
assert p.count('if #available(tvOS 17.0, *) {') >= 2, 'tvOS 16 deployment requires Menu availability guards'
assert '}if #available' not in p and ';if #available' not in p, 'mangled availability splice remains'
assert 'Menu("Season \\(season)") { ForEach' not in p, 'compressed duplicate menu pattern remains'
print('PASS: tvOS menu integrity')
