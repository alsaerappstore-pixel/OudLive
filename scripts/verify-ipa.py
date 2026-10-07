"""Reject empty, simulator, incorrectly packaged or non-arm64 deliverables."""
import plistlib
import struct
import sys
import zipfile
import json
import hashlib

with zipfile.ZipFile(sys.argv[1]) as ipa:
    root = 'Payload/OudLive.app/'
    info = plistlib.loads(ipa.read(root + 'Info.plist'))
    assert info['CFBundlePackageType'] == 'APPL'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Not an iPhone device app'
    assert info['NSMicrophoneUsageDescription']
    binary = ipa.read(root + info['CFBundleExecutable'])
    magic, cpu = struct.unpack('<II', binary[:8])
    assert magic == 0xFEEDFACF and cpu == 0x0100000C, 'Expected a thin arm64 Mach-O executable'
    assert len(binary) > 4096
    manifest = json.loads(ipa.read(root + 'RhythmBank/sample-manifest.json'))
    assert len(manifest['samples']) == 18
    for sample in manifest['samples']:
        bank = ipa.read(root + 'RhythmBank/' + sample['bundledFile'])
        assert hashlib.sha256(bank).hexdigest() == sample['bundledSHA256']
        assert struct.unpack('<I', bank[:4])[0] * 4 + 4 == len(bank)
    rhythms = json.loads(ipa.read(root + 'RhythmBank/catalogue.json'))
    assert len(rhythms) == 60 and [r['id'] for r in rhythms] == list(range(60))
    assert ipa.read(root + 'RhythmBank/CC0-LICENSE.txt')
    assert ipa.testzip() is None
print('IPA structure, device platform, arm64, 60 rhythms, recorded sample bank, license and ZIP integrity verified.')

