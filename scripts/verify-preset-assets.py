"""Ensure every preset's selectable artwork ships in the asset catalog."""
from pathlib import Path
import json, re, hashlib
root = Path(__file__).resolve().parents[1]
source = (root/'OudLive/Settings.swift').read_text(encoding='utf-8')
ids = list(map(int, re.findall(r'RecordingPreset\(id: (\d+)', source)))
assert ids == list(range(10))
hashes = set()
for i in ids:
    folder = root/f'OudLive/Assets.xcassets/OudPreset{i}.imageset'
    manifest = json.loads((folder/'Contents.json').read_text(encoding='utf-8-sig'))
    data = (folder/manifest['images'][0]['filename']).read_bytes()
    assert data[:2] == b'\xff\xd8' and len(data)>5000
    hashes.add(hashlib.sha256(data).hexdigest())
assert len(hashes)==10
print('PASS: ten distinct preset photographs included in the Xcode asset catalog')

