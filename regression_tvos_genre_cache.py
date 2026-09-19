from pathlib import Path
root = Path('/mnt/data/tvcat_perf_fix')
lib = (root/'GhostStreamTV/Shared/LibraryViewModel.swift').read_text()
view = (root/'GhostStreamTV/TVRootView.swift').read_text()
checks = {
    'movie bucket cache': 'movieGenreBuckets' in lib,
    'series bucket cache': 'seriesGenreBuckets' in lib,
    'movie id genre cache': 'movieGenresByID' in lib,
    'series id genre cache': 'seriesGenresByID' in lib,
    'movie view uses cache': 'library.movieGenreBuckets' in view,
    'series view uses cache': 'library.seriesGenreBuckets' in view,
    'no repeated movie classifier helper': 'private func genres(for movie:' not in view,
    'no repeated series classifier helper': 'private func genres(for series:' not in view,
}
failed = [k for k,v in checks.items() if not v]
for k,v in checks.items(): print(('PASS' if v else 'FAIL'), k)
raise SystemExit(1 if failed else 0)
