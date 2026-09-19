from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).parent
player=(root/'GhostStream/Views/PlayerView.swift').read_text()
settings=(root/'GhostStream/Views/SettingsView.swift').read_text()
# Controls must have a touch layer above UIKit/VLC rendering surfaces.
assert 'PlayerTapCatcher' in player, 'missing dedicated tap catcher over video surface'
assert 'Image(systemName: "chevron.left")' in player, 'missing visible back control'
assert 'Slider(' in player and 'requestedPosition' in player, 'missing seek/scrub control'
assert 'accessibilityLabel(isPlaying ? "Pause" : "Resume")' in player, 'missing play/pause/resume control'
# Settings rows must not contain dead action closures.
assert 'title: "Player Settings"' in settings and 'showPlayerSettings = true' in settings, 'Player Settings is not wired'
assert 'title: "Playback Options"' in settings and 'showPlaybackOptions = true' in settings, 'Playback Options is not wired'
assert 'title: "Privacy"' in settings and 'showPrivacy = true' in settings, 'Privacy is not wired'
assert 'title: "App Style"' in settings and 'showAppStyle = true' in settings, 'App Style is not wired'
assert '.contentShape(Rectangle())' in settings, 'settings rows do not expose full tappable card'
# Marketing icon artwork should occupy much more than the old tiny center mark.
im=Image.open(root/'GhostStream/Assets.xcassets/AppIcon.appiconset/Icon-1024.png').convert('RGB')
a=np.array(im)
# Purple-ish/bright artwork pixels distinct from nearly-black background.
mask=(a.max(2) > 55) & ((a.max(2)-a.min(2)) > 18)
ys,xs=np.where(mask)
assert len(xs)>0
width=xs.max()-xs.min()+1; height=ys.max()-ys.min()+1
assert width >= 560 and height >= 300, f'icon artwork still too small: {width}x{height}'
print('ios controls/settings/icon regression passed')
