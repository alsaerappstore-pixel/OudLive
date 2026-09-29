import Foundation

enum SoundMode: String, Codable, CaseIterable, Identifiable {
    case oud, voice
    var id: String { rawValue }
    var title: String { self == .oud ? "العود" : "الصوت البشري" }
}

enum Parameter: Int, CaseIterable {
    // Must match oud::Param in DSP.hpp.
    case input, output, low, mid, high, compression, reverb, delay
    case delayTime, feedback, modulation, modRate, flanger, doubler, bypass, mute
    var range: ClosedRange<Double> {
        switch self {
        case .input: return -24...18
        case .output: return -60...0
        case .low, .mid, .high: return -12...12
        case .delayTime: return 40...800
        case .feedback: return 0...0.7
        case .modulation, .doubler, .reverb, .delay: return 0...0.8
        case .modRate: return 0.1...3
        default: return 0...1
        }
    }
    var label: String {
        switch self {
        case .input: return "حساسية الميكروفون"
        case .output: return "مستوى الخروج"
        case .low: return "دفء • 180 Hz"
        case .mid: return "حضور • 1.1 kHz"
        case .high: return "لمعان • 4.8 kHz"
        case .compression: return "ضغط الصوت • Compressor"
        case .reverb: return "مساحة • Reverb"
        case .delay: return "صدى • Delay"
        case .delayTime: return "زمن الصدى"
        case .feedback: return "تكرار الصدى"
        case .modulation: return "عمق التأثير"
        case .modRate: return "سرعة الحركة"
        case .doubler: return "توسيع • Doubler"
        default: return ""
        }
    }
    func text(_ value: Double) -> String {
        switch self {
        case .input, .output, .low, .mid, .high: return String(format: "%.0f dB", value)
        case .delayTime: return String(format: "%.0f ms", value)
        case .modRate: return String(format: "%.1f Hz", value)
        default: return String(format: "%.0f%%", value * 100)
        }
    }
}

struct SoundSettings: Codable {
    var preset = "طبيعي"
    var values: [Double] = [0,-9,0,0,0,0.2,0.12,0,280,0.25,0,0.7,0,0,0,0]
    subscript(_ p: Parameter) -> Double {
        get { values[p.rawValue] }
        set { values[p.rawValue] = min(p.range.upperBound, max(p.range.lowerBound, newValue)) }
    }
    var valid: Bool {
        values.count == Parameter.allCases.count && values.enumerated().allSatisfy { index, value in
            value.isFinite && Parameter(rawValue: index)!.range.contains(value)
        }
    }
    static func preset(_ name: String, mode: SoundMode) -> SoundSettings {
        var s = SoundSettings(); s.preset = name
        switch name {
        case "كلاسيكي":
            s[.low] = 2; s[.high] = -2; s[.reverb] = 0.22; s[.compression] = 0.25
        case "فخم / ثقيل":
            s[.low] = 5; s[.mid] = -2; s[.high] = -1; s[.compression] = 0.48
            s[.reverb] = 0.3; s[.doubler] = 0.16
        case "حاد":
            s[.low] = -3; s[.mid] = 3; s[.high] = 4; s[.reverb] = 0.08; s[.compression] = 0.3
        case "مشكل":
            s[.low] = 2; s[.high] = 2; s[.reverb] = 0.26; s[.delay] = 0.18
            s[.delayTime] = 320; s[.modulation] = 0.18; s[.doubler] = 0.15; s[.compression] = 0.35
        default: break
        }
        if mode == .voice {
            s[.low] = max(-12, s[.low] - 2); s[.mid] = min(12, s[.mid] + 1)
            s[.compression] = min(1, s[.compression] + 0.15)
        }
        return s
    }
}

struct SavedSettings: Codable {
    var oud = SoundSettings()
    var voice = SoundSettings.preset("طبيعي", mode: .voice)
    var mode = SoundMode.oud
    var stableBuffer = false
    var valid: Bool { oud.valid && voice.valid }
}
