import Foundation
let names = ["Slow Metal", "Dry Rhythm", "Stone Chamber", "Wooden Majlis", "Sharp Pick"]
precondition(SoundSettings.names == names && RecordingPreset.all.map(\.name) == names)
precondition(Parameter.allCases.count == 24 && SoundMode.allCases == [.oud])
let legacy = """
{"preset":"معدن بطيء","values":[12,-15,3,-5,4,0.3,0.22,0.2,390,0.2,0.95,0.15,1,0,1,0,1.8,25,0.6,1,1,7],"disabledEffects":["motion","doubler"],"unprocessed":true}
"""
let migrated = try JSONDecoder().decode(SoundSettings.self, from: Data(legacy.utf8))
precondition(migrated.valid && migrated.preset == "Slow Metal" && migrated[.input] == 12 && migrated[.output] == -15 && migrated[.recordGain] == 7)
precondition(!migrated.unprocessed && migrated[.bypass] == 0 && migrated[.roomSize] == 0.65 && migrated[.width] == 0.45)
let invalid = try JSONDecoder().decode(SoundSettings.self, from: Data("{\"preset\":\"bad\",\"values\":[0]}".utf8))
precondition(!invalid.valid)
var reference = SoundSettings(); reference[.input] = 17; reference[.output] = -23; reference[.recordGain] = 7; reference[.live] = 0
var rows = [String](); var unique = Set<[Double]>()
for recipe in RecordingPreset.all {
    let s = recipe.settings(preserving: reference)
    precondition(s.valid && s[.input] == 17 && s[.output] == -23 && s[.recordGain] == 7 && s[.live] == 0)
    let roundTrip = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(s))
    precondition(roundTrip.values == s.values && roundTrip.preset == recipe.name)
    unique.insert(s.values)
    var neutral = s; neutral[.input] = 0; neutral[.output] = 0; neutral[.recordGain] = 0; neutral[.mute] = 0
    rows.append(Parameter.allCases.map { String(neutral.effective($0)) }.joined(separator: " "))
    for effect in Effect.allCases {
        var off = s; off.disabledEffects.insert(effect)
        precondition(!off.enabled(effect))
        let saved = try JSONDecoder().decode(SoundSettings.self, from: JSONEncoder().encode(off))
        precondition(saved.disabledEffects == off.disabledEffects)
    }
}
precondition(unique.count == 5)
try FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try rows.joined(separator: "\n").write(toFile: "build/recording-presets.txt", atomically: true, encoding: .utf8)
var bank = SoundBank(); let sound = NamedSound(name: "مجلسي", mode: .oud, settings: migrated); bank.save(sound, at: 2)
var restored = try JSONDecoder().decode(SoundBank.self, from: JSONEncoder().encode(bank))
precondition(restored.valid && restored.slots[2]?.settings.values == migrated.values)
restored.clear(2); precondition(restored.slots[2] == nil)
print("PASS: exactly five acoustic recipes, safe legacy migration, current persistence, switches, eight custom slots and recipe export")
let audioFirst = RecordingTiming(audioStart: 10, videoStart: 12, audioDuration: 8, videoDuration: 9)!
precondition(audioFirst.audioTrim == 2 && audioFirst.videoTrim == 0 && audioFirst.duration == 6)
let videoFirst = RecordingTiming(audioStart: 12, videoStart: 10, audioDuration: 8, videoDuration: 9)!
precondition(videoFirst.audioTrim == 0 && videoFirst.videoTrim == 2 && videoFirst.duration == 7)
precondition(RecordingTiming(audioStart: 0, videoStart: 2, audioDuration: 8, videoDuration: 9) == nil)
precondition(RecordingTiming(audioStart: 1, videoStart: 20, audioDuration: 8, videoDuration: 9) == nil)
precondition(RecordingTiming(audioStart: .nan, videoStart: 2, audioDuration: 8, videoDuration: 9) == nil)
print("PASS: media alignment trims early audio or video, keeps overlap, rejects missing or invalid timestamps")

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
