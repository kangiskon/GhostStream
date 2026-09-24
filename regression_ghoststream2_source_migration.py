from pathlib import Path
import re

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

for forbidden_property in ('password', 'm3uURL', 'serverURL', 'username'):
    assert not re.search(rf'\b(?:let|var)\s+{forbidden_property}\s*:', profile_text), (
        f'cloud profile exposes {forbidden_property}'
    )

print('ghoststream2 source migration contract: PASS')
