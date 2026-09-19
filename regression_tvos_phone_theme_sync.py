from pathlib import Path
p = Path('GhostStreamTV/TVRootView.swift')
s = p.read_text()
checks = {
    'phone accent': 'static let accent = Color(red: 0.00, green: 0.92, blue: 1.00)' in s,
    'phone background': 'static let background = Color(red: 0.001, green: 0.010, blue: 0.014)' in s,
    'phone card': 'static let card = Color(red: 0.018, green: 0.055, blue: 0.065)' in s,
    'phone card2': 'static let card2 = Color(red: 0.030, green: 0.085, blue: 0.095)' in s,
    'phone gradient': 'static let cardGradient = LinearGradient(' in s,
    'hero mask': '.mask(' in s and 'GhostHeroExact' in s,
    'ghost focus style': 'TVGhostFocusStyle' in s,
    'media cards plain focus-safe': '.buttonStyle(TVGhostFocusStyle' in s,
    'source form themed': 'TVGhostInputField' in s,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL:', ', '.join(failed))
    raise SystemExit(1)
print('PASS: tvOS visual system is synchronized with the phone GhostStream theme')
