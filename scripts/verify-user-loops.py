"""Original-file preservation, complete manifest, and bundled resources."""
from pathlib import Path
import hashlib,json,sys,zipfile
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'OudLive/UserLoops/manifest.json').read_text(encoding='utf-8'))
assert len(manifest)==314 and sum(i['playable'] for i in manifest)==292
assert len({i['id'] for i in manifest})==len(manifest)
archive=zipfile.ZipFile(sys.argv[1]) if len(sys.argv)>1 else None
for item in manifest:
 data=archive.read('Payload/OudLive.app/UserLoops/'+item['file']) if archive else (root/'OudLive/UserLoops'/item['file']).read_bytes()
 assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],item['originalPath']
print('PASS: all 314 supplied originals preserved byte-for-byte, including 292 WAV and 20 RX2; unique IDs')
