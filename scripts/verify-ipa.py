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
    assert not any('RhythmBank/' in name for name in ipa.namelist()), 'Rhythm resources must not ship'
    assert ipa.testzip() is None
print('IPA structure, device platform, arm64, no rhythm resources and ZIP integrity verified.')
