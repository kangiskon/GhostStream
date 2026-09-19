from pathlib import Path
root = Path(__file__).parent
checks = []
for rel in ['GhostStream/Models/Models.swift','GhostStreamTV/Shared/Models.swift']:
    t=(root/rel).read_text()
    checks += [('vod direct source '+rel, 'directSource' in t), ('episode direct source '+rel, 'directSource' in t)]
for rel in ['GhostStream/Services/XtreamClient.swift','GhostStreamTV/Shared/XtreamClient.swift']:
    t=(root/rel).read_text()
    checks += [
      ('artwork resolver '+rel, 'resolveAssetURL' in t),
      ('vod direct decode '+rel, 'directSource = "direct_source"' in t),
      ('episode direct decode '+rel, 'directSource = "direct_source"' in t),
      ('prefer direct vod '+rel, 'preferredPlaybackURL' in t),
    ]
tv=(root/'GhostStreamTV/TVRootView.swift').read_text()
checks += [
 ('tv movie category selector', 'selectedMovieCategory' in tv),
 ('tv series category selector', 'selectedSeriesCategory' in tv),
 ('tv category strip', 'TVCategoryStrip' in tv),
]
failed=[name for name,ok in checks if not ok]
if failed:
    print('FAIL')
    for f in failed: print(' -', f)
    raise SystemExit(1)
print('PASS')
