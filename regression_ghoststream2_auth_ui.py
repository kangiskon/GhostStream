from pathlib import Path

root = Path(__file__).parent
paths = [
    root / 'GhostStream/Account/AccountStore.swift',
    root / 'GhostStream/Account/AuthView.swift',
    root / 'GhostStream/Account/AppleSignInCoordinator.swift',
]
for path in paths:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in paths)
for required in (
    'SignInWithAppleButton',
    'Sign In',
    'Create Account',
    'Forgot Password',
    'email',
    'password',
    'restoreSession',
    'refreshTask',
):
    assert required in text, f'missing auth behavior: {required}'

assert 'ASAuthorizationAppleIDCredential' in text
print('ghoststream2 auth UI contract: PASS')
