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

precondition(RecordingPreset.all.count == 35)
precondition(Set(RecordingPreset.all.map(\.name)).count == 35)
precondition(RecordingPreset.all.first?.isUnprocessed == true)
precondition(RecordingPreset.all.filter(\.isUnprocessed).count == 1)
var reference = SoundSettings()
reference[.input] = 17; reference[.output] = -23; reference[.recordGain] = 7; reference[.mute] = 1; reference[.bypass] = 1
var audible = Set<[Double]>()
var recipeRows = [String]()
for preset in RecordingPreset.all {
    let s = preset.settings(preserving: reference)
    precondition(s.valid && s[.input] == 17 && s[.output] == -23 && s[.recordGain] == 7 && s[.mute] == 1)
    precondition(s.effective(.bypass) == (preset.isUnprocessed ? 1 : 0))
    if preset.isUnprocessed { precondition(Effect.allCases.allSatisfy { !s.enabled($0) }) }
    let decoded = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(s))
    precondition(decoded.values == s.values && decoded.disabledEffects == s.disabledEffects && decoded.unprocessed == s.unprocessed)
    audible.insert(Parameter.allCases.map { s.effective($0) })
    var neutral = preset.settings(preserving: SoundSettings())
    neutral[.input] = 0; neutral[.output] = 0; neutral[.recordGain] = 0; neutral[.mute] = 0
    recipeRows.append(Parameter.allCases.map { String(neutral.effective($0)) }.joined(separator: " "))
}
precondition(audible.count == 35)
precondition(!old.unprocessed)
var restoredRaw = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(RecordingPreset.all[0].settings(preserving: reference)))
restoredRaw[.bypass] = 0 // Runtime comparisons reset on launch/load; permanent raw mode must survive.
precondition(restoredRaw.effective(.bypass) == 1 && restoredRaw.unprocessed)
try FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try recipeRows.joined(separator: "\n").write(toFile: "build/recording-presets.txt", atomically: true, encoding: .utf8)
print("PASS: 35 quick presets preserve live levels, persist raw mode and effect switches; legacy settings migrate and actual effective values exported for DSP tests")

var bank = SoundBank()
let originalSound = NamedSound(name: "اختباري", mode: .voice, settings: switched)
bank.save(originalSound, at: 2)
bank.save(named, at: 7)
bank.save(NamedSound(name: "خام محفوظ", mode: .voice, settings: restoredRaw), at: 0)
let bankData = try JSONEncoder().encode(bank)
var restoredBank = try JSONDecoder().decode(SoundBank.self, from: bankData)
precondition(restoredBank.valid && restoredBank.slots.count == 8)
precondition(restoredBank.slots[0]?.settings.unprocessed == true && restoredBank.slots[0]?.settings.effective(.bypass) == 1)
precondition(restoredBank.slots[2]?.settings.values == switched.values && restoredBank.slots[2]?.mode == .voice)
precondition(restoredBank.slots[2]?.settings.disabledEffects == switched.disabledEffects)
restoredBank.save(named, at: 2)
precondition(restoredBank.slots[2]?.id == named.id && restoredBank.slots[7]?.id == named.id)
restoredBank.clear(2)
precondition(restoredBank.slots[2] == nil && restoredBank.slots[7] != nil)
restoredBank.save(named, at: 8); restoredBank.clear(-1)
precondition(restoredBank.valid)
print("PASS: eight sound slots persist mode, parameter values and effect switches; replace and clear affect only the selected slot")

let libraryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
let takesRoot = libraryRoot.appendingPathComponent("Recordings", isDirectory: true)
try FileManager.default.createDirectory(at: takesRoot, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: libraryRoot) }
let takeURLs = ["A.wav", "A.mp4", "B.wav", "C.mp4"].map { takesRoot.appendingPathComponent($0) }
for url in takeURLs { try Data([1]).write(to: url) }
let outside = libraryRoot.appendingPathComponent("keep.wav"); try Data([1]).write(to: outside)
let takes = RecordingEntry.grouped(takeURLs + [takeURLs[0]])
precondition(takes.count == 3 && takes.first { $0.id.lastPathComponent == "A" }?.files.count == 2)
precondition(takes.first { $0.id.lastPathComponent == "A" }?.primaryURL.pathExtension == "mp4")
let ids = Set(takes.filter { $0.id.lastPathComponent != "B" }.map(\.id))
let deletion = RecordingEntry.deletionURLs(takes + RecordingEntry.grouped([outside]), selected: ids.union([outside.deletingPathExtension()]), directory: takesRoot)
precondition(deletion.count == 3 && !deletion.contains(outside))
for url in deletion { try FileManager.default.removeItem(at: url) }
precondition(FileManager.default.fileExists(atPath: takeURLs[2].path) && FileManager.default.fileExists(atPath: outside.path))
let all = RecordingEntry.deletionURLs(takes, selected: Set(takes.map(\.id)), directory: takesRoot)
precondition(Set(all) == Set(takeURLs))
print("PASS: legacy WAV/MP4 pairs group once; selected/all deletion includes both siblings and rejects files outside the library")
