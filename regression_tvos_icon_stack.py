import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent / 'GhostStreamTV' / 'Assets.xcassets' / 'App Icon & Top Shelf Image.brandassets'
for stack_name in ['App Icon - Small.imagestack', 'App Icon - Large.imagestack']:
    stack = root / stack_name
    data = json.loads((stack / 'Contents.json').read_text())
    layers = [entry['filename'] for entry in data['layers']]
    assert layers[-1] == 'Back.imagestacklayer', f'{stack_name}: last/base layer must be Back, got {layers[-1]}'
    back_set = stack / 'Back.imagestacklayer' / 'Content.imageset'
    for png in back_set.glob('*.png'):
        alpha = Image.open(png).convert('RGBA').getchannel('A')
        assert alpha.getextrema() == (255, 255), f'{png}: base layer is not fully opaque'
print('tvOS icon stack order and opacity OK')
