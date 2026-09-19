from pathlib import Path
root=Path('.')
view=(root/'GhostStreamTV/TVRootView.swift').read_text()
lib=(root/'GhostStreamTV/Shared/LibraryViewModel.swift').read_text()
models=(root/'GhostStreamTV/Shared/Models.swift').read_text()
checks={
 'genre strip exists':'private struct TVGenreStrip' in view,
 'movie selection uses standard genre':'@State private var selectedMovieGenre: StandardMediaGenre?' in view,
 'series selection uses standard genre':'@State private var selectedSeriesGenre: StandardMediaGenre?' in view,
 'classifier still defined':'static func classify(categoryName:' in models,
 'movie classifier cached during load':'StandardMediaGenre.classify(' in lib and 'for movie in items' in lib,
 'series classifier cached during load':'for show in items' in lib and 'seriesGenreBuckets' in lib,
 'movie screen reads cache':'library.movieGenreBuckets' in view,
 'series screen reads cache':'library.seriesGenreBuckets' in view,
}
failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(('PASS' if v else 'FAIL'), k)
if failed: raise SystemExit('FAIL: '+', '.join(failed))
print('tvOS standard genre cached UI regression passed')
