import Foundation

let legacy = """
{"preset":"مخصص","values":[12,-15,2,-1,3,0.3,0.4,0.2,350,0.3,0.1,0.7,0,0.2,1,0]}
"""
let old = try JSONDecoder().decode(SoundSettings.self, from: Data(legacy.utf8))
precondition(old.valid && old.values.count == 22)
precondition(old[.input] == 12 && old[.output] == -15 && old[.bypass] == 1)
precondition(old[.decay] == 2.4 && old[.intensity] == 1)
let roundTrip = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(old))
precondition(roundTrip.values == old.values)
for mode in SoundMode.allCases {
    var unique = Set<[Double]>()
    for name in SoundSettings.names {
        let s = SoundSettings.preset(name, mode: mode)
        precondition(s.valid, name); unique.insert(s.values)
    }
    precondition(unique.count == SoundSettings.names.count)
}
let bad = try JSONDecoder().decode(SoundSettings.self, from: Data("{\"preset\":\"bad\",\"values\":[0]}".utf8))
precondition(!bad.valid)
print("PASS: v1 migration preserves levels, v2 persistence round-trips, presets are distinct and bounded, invalid settings rejected")

var switched = SoundSettings.preset("مشكل", mode: .oud)
for effect in Effect.allCases {
    let original = switched.values
    switched.disabledEffects.insert(effect)
    let decoded = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(switched))
    precondition(!decoded.enabled(effect) && decoded.values == original)
    for p in effect.parameters where [.reverb, .delay, .modulation, .doubler, .low, .mid, .high, .compression, .makeup].contains(p) {
        precondition(decoded.effective(p) == 0)
    }
    switched.disabledEffects.remove(effect)
    precondition(switched.values == original)
}
precondition(old.disabledEffects.isEmpty)
let named = NamedSound(name: "تجربة", mode: .voice, settings: switched)
let restored = try JSONDecoder().decode(NamedSound.self, from: JSONEncoder().encode(named))
precondition(restored.id == named.id && restored.mode == .voice && restored.settings.values == switched.values)
print("PASS: independent switches preserve settings, bypass correctly and persist; named sounds round-trip")
let audioFirst = RecordingTiming(audioStart: 10, videoStart: 12, audioDuration: 8, videoDuration: 9)!
precondition(audioFirst.audioTrim == 2 && audioFirst.videoTrim == 0 && audioFirst.duration == 6)
let videoFirst = RecordingTiming(audioStart: 12, videoStart: 10, audioDuration: 8, videoDuration: 9)!
precondition(videoFirst.audioTrim == 0 && videoFirst.videoTrim == 2 && videoFirst.duration == 7)
precondition(RecordingTiming(audioStart: 0, videoStart: 2, audioDuration: 8, videoDuration: 9) == nil)
precondition(RecordingTiming(audioStart: 1, videoStart: 20, audioDuration: 8, videoDuration: 9) == nil)
precondition(RecordingTiming(audioStart: .nan, videoStart: 2, audioDuration: 8, videoDuration: 9) == nil)
print("PASS: media alignment trims early audio or video, keeps overlap, rejects missing or invalid timestamps")

precondition(old[.recordGain] == 0)
let clear = SoundSettings.preset("عود صافي", mode: .oud)
precondition(!clear.enabled(.motion) && !clear.enabled(.doubler) && !clear.enabled(.compressor))
precondition(clear.effective(.makeup) == 0 && clear.effective(.low) == 0)
let v22 = "{\"preset\":\"طبيعي\",\"values\":[6,-9,0,0,0,0.25,0.24,0.12,320,0.32,0,0.7,0,0,0,0,2.4,22,0.5,4,1]}"
let migrated = try JSONDecoder().decode(SoundSettings.self, from: Data(v22.utf8))
precondition(migrated.valid && migrated[.recordGain] == 0 && migrated[.output] == -9)
print("PASS: independent recording gain migrates v2.2 settings and clear oud disables pitch-modulating layers")

precondition(RecordingPreset.all.count == 15)
precondition(Set(RecordingPreset.all.map(\.name)).count == 15)
var reference = SoundSettings()
reference[.input] = 17; reference[.output] = -23; reference[.recordGain] = 7; reference[.mute] = 1; reference[.bypass] = 1
var audible = Set<[Double]>()
var recipeRows = [String]()
for preset in RecordingPreset.all {
    let s = preset.settings(preserving: reference)
    precondition(s.valid && s[.input] == 17 && s[.output] == -23 && s[.recordGain] == 7 && s[.mute] == 1 && s[.bypass] == 0)
    let decoded = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(s))
    precondition(decoded.values == s.values && decoded.disabledEffects == s.disabledEffects)
    audible.insert(Parameter.allCases.map { s.effective($0) })
    var neutral = preset.settings(preserving: SoundSettings())
    neutral[.input] = 0; neutral[.output] = 0; neutral[.recordGain] = 0; neutral[.mute] = 0
    recipeRows.append(Parameter.allCases.map { String(neutral.effective($0)) }.joined(separator: " "))
}
precondition(audible.count == 15)
try FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try recipeRows.joined(separator: "\n").write(toFile: "build/recording-presets.txt", atomically: true, encoding: .utf8)
print("PASS: 15 recording presets are distinct, preserve live levels, activate processing and persist; actual effective values exported for DSP tests")
