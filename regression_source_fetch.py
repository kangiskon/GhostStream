from pathlib import Path
root = Path(__file__).resolve().parent
pairs = [
    (root/'GhostStream/Services/LibraryViewModel.swift', 'iOS library'),
    (root/'GhostStreamTV/Shared/LibraryViewModel.swift', 'tvOS library'),
]
errors=[]
for p,label in pairs:
    s=p.read_text()
    if 'throw LibraryLoadError.allSectionsFailed' not in s:
        errors.append(f'{label}: all-section failure still does not throw')
    load_failure = s.split('} catch {', 1)[1].split('    func reset()', 1)[0] if label == 'iOS library' else s.split('catch {', 1)[1].split('}', 1)[0]
    if 'loadedSourceID = nil' not in load_failure:
        errors.append(f'{label}: failed load can still remain marked loaded')

s=(root/'GhostStream/Views/AddSourceView.swift').read_text()
if 'await library.load(source: source)' not in s:
    errors.append('iOS AddSource: does not fetch source before dismissing')


s=(root/'GhostStream/Views/LauncherView.swift').read_text()
if s.count('await library.load(source: source)') < 2:
    errors.append('iOS Launcher: imported/saved sources do not explicitly reload')

s=(root/'GhostStreamTV/TVRootView.swift').read_text()
if 'await library.load(source: source)' not in s:
    errors.append('tvOS source setup: does not fetch source before activation')

if errors:
    print('REGRESSION FAIL')
    for e in errors: print('-',e)
    raise SystemExit(1)
print('REGRESSION PASS')

for rel,label in [
    ('GhostStream/Services/LibraryViewModel.swift','iOS'),
    ('GhostStreamTV/Shared/LibraryViewModel.swift','tvOS'),
]:
    s=(root/rel).read_text()
    if 'async let liveResult' in s or 'async let cats' in s or 'async let items' in s:
        print(f'REGRESSION FAIL - {label}: provider requests are still burst-concurrent')
        raise SystemExit(1)
print('STAGED FETCH PASS')

for rel,label in [
    ('GhostStream/Services/LibraryViewModel.swift','iOS'),
    ('GhostStreamTV/Shared/LibraryViewModel.swift','tvOS'),
]:
    s=(root/rel).read_text()
    if 'channels.isEmpty && movies.isEmpty && series.isEmpty && !notes.isEmpty' in s:
        print(f'REGRESSION FAIL - {label}: empty successful API responses can still be marked loaded')
        raise SystemExit(1)
    if 'The provider accepted the login but returned an empty media library.' not in s:
        print(f'REGRESSION FAIL - {label}: empty provider library is not surfaced as an error')
        raise SystemExit(1)
    if 'The playlist contains no playable entries.' not in s:
        print(f'REGRESSION FAIL - {label}: pasted empty M3U can still be marked loaded')
        raise SystemExit(1)
print('EMPTY-LIBRARY GUARD PASS')
