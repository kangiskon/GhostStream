from pathlib import Path
root = Path('.')
checks=[]
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
 ('tv category strip', 'TVProviderCategoryStrip' in tv),
]
failed=[name for name,ok in checks if not ok]
for name,ok in checks: print(('PASS' if ok else 'FAIL'), name)
raise SystemExit(1 if failed else 0)
