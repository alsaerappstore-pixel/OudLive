import Foundation

let legacy = """
{"preset":"مخصص","values":[12,-15,2,-1,3,0.3,0.4,0.2,350,0.3,0.1,0.7,0,0.2,1,0]}
"""
let old = try JSONDecoder().decode(SoundSettings.self, from: Data(legacy.utf8))
precondition(old.valid && old.values.count == 21)
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
