"""The removed accompaniment engine must not be compiled or bundled."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
project=(root/'OudLive.xcodeproj/project.pbxproj').read_text()
assert 'RhythmBank' not in project and 'LiveRhythms.swift' not in project
assert 'MixerView.swift' in project
for file in ['OudLive/Audio/AudioBridge.mm','OudLive/Audio/AudioBridge.h','OudLive/Audio/DSP.hpp']:
    text=(root/file).read_text()
    assert 'rhythm' not in text.lower() and 'backing' not in text.lower(), file
assert not list((root/'OudLive/RhythmBank').glob('*'))
assert not (root/'OudLive/Audio/RhythmEngine.hpp').exists()
print('PASS: mixer wired; rhythm engine, bridge, mixing inputs and bundled samples removed')
