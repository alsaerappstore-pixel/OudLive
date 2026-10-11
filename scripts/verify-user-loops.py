"""Validate replacement library, original copies and trimmed loop seams."""
from pathlib import Path
from collections import Counter
import hashlib,json,sys,zipfile,struct,math
root=Path(__file__).resolve().parents[1]
folder=root/'OudLive/UserLoops'
manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
reports=json.loads((root/'Reports/loop-trims-314.json').read_text(encoding='utf-8'))
assert len(manifest)==160 and all(i['playable'] for i in manifest)
assert Counter(i['group'] for i in manifest)=={'منوع 1':142,'منوع 2':18}
assert len({i['id'] for i in manifest})==160
assert sum(i['trimmed'] for i in manifest)==8 and len(reports)==8
archive=zipfile.ZipFile(sys.argv[1]) if len(sys.argv)>1 else None
prefix='Payload/OudLive.app/UserLoops/'
actual={n[len(prefix):] for n in archive.namelist() if n.startswith(prefix) and not n.endswith('/')} if archive else {p.name for p in folder.iterdir() if p.is_file()}
assert actual=={i['file'] for i in manifest}|{'manifest.json'},'Old or missing library resources'
for item in manifest:
 data=archive.read(prefix+item['file']) if archive else (folder/item['file']).read_bytes()
 assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],item['originalPath']
 if not item['trimmed']:
  assert item['sha256']==item['sourceSHA256']
  continue
 report=next(r for r in reports if r['sourceSHA256']==item['sourceSHA256'])
 assert 0<report['startSeconds']<report['endSeconds']<report['originalDuration']
 assert report['cycles'] in (8,16) and report['boundaryCorrelation']>.6
 assert abs(report['duration']-item['duration'])<1/48000
 assert abs(report['endSeconds']-report['startSeconds']-report['duration'])<1/48000
 assert data[:4]==b'RIFF' and data[8:12]==b'WAVE'
 chunks={}; offset=12
 while offset+8<=len(data):
  key=data[offset:offset+4];size=struct.unpack_from('<I',data,offset+4)[0]
  chunks[key]=data[offset+8:offset+8+size];offset+=8+size+(size%2)
 fmt,channels,rate,_,align,bits=struct.unpack_from('<HHIIHH',chunks[b'fmt '])
 assert (fmt,channels,rate,bits)==(3,2,48000,32)
 samples=chunks[b'data'];frames=len(samples)//align
 assert abs(frames/rate-item['duration'])<1/rate
 first=struct.unpack_from('<ff',samples);last=struct.unpack_from('<ff',samples,len(samples)-align)
 jump=max(abs(a-b) for a,b in zip(first,last))
 assert jump<max(.015,report['normalDifferenceP999'])
 assert abs(jump-report['seamJump'])<1e-6
 assert all(math.isfinite(v) for frame in struct.iter_unpack('<ff',samples) for v in frame)
print('PASS: 160 replacement loops; 152 byte-identical originals; 8 individually trimmed loops and verified seams; no old resources')
