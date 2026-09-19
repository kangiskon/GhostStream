"""Source-only guardrails; run on macOS with an archived app for final compliance."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parent
for name, project in [('GhostStream','GhostStream.xcodeproj'),('GhostStreamTV','GhostStreamTV.xcodeproj')]:
    target = ROOT / name
    manifest_path = target / 'PrivacyInfo.xcprivacy'
    assert manifest_path.is_file(), f'{name}: target privacy manifest missing'
    manifest = plistlib.loads(manifest_path.read_bytes())
    assert manifest.get('NSPrivacyTracking') is False
    assert manifest.get('NSPrivacyCollectedDataTypes') == [], 'Do not assert no data collection without independent audit'
    access = {entry['NSPrivacyAccessedAPIType']: entry['NSPrivacyAccessedAPITypeReasons'] for entry in manifest['NSPrivacyAccessedAPITypes']}
    assert access['NSPrivacyAccessedAPICategoryUserDefaults'] == ['CA92.1']
    pbx = (ROOT / project / 'project.pbxproj').read_text()
    assert 'PrivacyInfo.xcprivacy in Resources' in pbx
    assert 'PrivacyInfo.xcprivacy */ = {isa = PBXFileReference;' in pbx
    plist = plistlib.loads((target / 'Info.plist').read_bytes())
    assert plist.get('NSAppTransportSecurity', {}).get('NSAllowsArbitraryLoads') is True, 'Existing arbitrary user-supplied HTTP sources must not silently break'
assert not plistlib.loads((ROOT/'GhostStream'/'Info.plist').read_bytes()).get('UIBackgroundModes'), 'Unimplemented background audio capability should not be declared'
for path in ['Submission/PRIVACY-POLICY-DRAFT.md','Submission/APP-REVIEW-NOTES-DRAFT.md','Submission/RELEASE-CHECKLIST.md','Submission/ATS-JUSTIFICATION.md','Submission/SDK-PRIVACY-AUDIT.md']:
    assert (ROOT/path).is_file(), f'missing deliverable {path}'
assert '[REPLACE BEFORE PUBLICATION:' in (ROOT/'Submission/PRIVACY-POLICY-DRAFT.md').read_text()
ios_settings = (ROOT/'GhostStream/Views/SettingsView.swift').read_text()
for item in ('Provider Passwords', 'Provider Connections', 'Playback Data'):
    assert item in ios_settings, f'iOS in-app privacy summary missing {item}'
print('PASS: app privacy manifests, project membership, ATS continuity, background mode, and disclosure drafts')
