from pathlib import Path
import plistlib
root = Path('.')
for name in ['MobileVLCKit','TVVLCKit']:
    xc = root / 'Frameworks' / f'{name}.xcframework'
    with (xc/'Info.plist').open('rb') as f:
        data = plistlib.load(f)
    for lib in data['AvailableLibraries']:
        assert 'DebugSymbolsPath' not in lib, f'{name}: manifest still references omitted dSYMs'
        assert 'BitcodeSymbolMapsPath' not in lib, f'{name}: manifest still references omitted BCSymbolMaps'
        fw = xc / lib['LibraryIdentifier'] / lib['LibraryPath']
        assert fw.is_dir(), f'{name}: runtime framework missing: {fw}'
        assert (fw/name).is_file(), f'{name}: framework binary missing: {fw/name}'
print('PASS: runtime XCFramework bundles contain every required slice without stale symbol references')
