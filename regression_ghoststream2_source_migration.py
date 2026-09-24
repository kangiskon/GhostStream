from pathlib import Path

root = Path(__file__).parent
profile = root / 'GhostStream/Sources/CloudSourceProfile.swift'
migration = root / 'GhostStream/Sources/SourceMigrationCoordinator.swift'
store = root / 'GhostStream/Services/SourceStore.swift'

for path in (profile, migration, store):
    assert path.exists(), f'missing {path.relative_to(root)}'

profile_text = profile.read_text()
migration_text = migration.read_text()
store_text = store.read_text()

assert 'SHA256' in profile_text
assert 'ghoststream.v2.migration.completed' in migration_text
assert 'wipeAllLocalData' in store_text
for forbidden in ('password:', 'm3uURL:', 'serverURL:', 'username:'):
    assert forbidden not in profile_text, f'cloud profile exposes {forbidden}'

print('ghoststream2 source migration contract: PASS')
