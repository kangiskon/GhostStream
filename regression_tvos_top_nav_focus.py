from pathlib import Path
root = Path(__file__).parent
tv = (root / 'GhostStreamTV' / 'TVRootView.swift').read_text()

# The persistent top navigation must participate explicitly in tvOS focus.
assert 'private enum TVTopFocus: Hashable' in tv, 'Missing explicit top-navigation focus identity'
assert '@FocusState private var focusedItem: TVTopFocus?' in tv, 'Top navigation has no FocusState'
assert '.focused($focusedItem, equals: .section(item))' in tv, 'Section buttons are not bound to tvOS focus'
assert '.focused($focusedItem, equals: .sources)' in tv, 'Sources/gear button is not bound to tvOS focus'
assert '.focusSection()' in tv, 'Top navigation is not a tvOS focus section'
assert 'focused: focusedItem == .section(item)' in tv, 'Section buttons have no focused visual state'
assert 'focused: focusedItem == .sources' in tv, 'Gear button has no focused visual state'
print('PASS: persistent top navigation has explicit remote focus and visual focus state')
