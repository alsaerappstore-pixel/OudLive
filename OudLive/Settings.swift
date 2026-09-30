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
    case decay, predelay, tone, makeup, intensity, recordGain
    var range: ClosedRange<Double> {
        switch self {
        case .recordGain: return -12...18
        case .input: return -24...30
        case .output: return -60...0
        case .low, .mid, .high: return -12...12
        case .delayTime: return 40...1200
        case .feedback: return 0...0.82
        case .decay: return 0.4...7
        case .predelay: return 0...100
        case .makeup: return 0...12
        case .intensity: return 0...1.5
        case .modRate: return 0.1...3
        default: return 0...1
        }
    }
    var label: String {
        switch self {
        case .input: return "تقوية الالتقاط"
        case .recordGain: return "مستوى التسجيل"
        case .output: return "مستوى السماعة"
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
        case .decay: return "طول ذيل الصدى"
        case .predelay: return "فاصل قبل الصدى"
        case .tone: return "لمعان الصدى"
        case .makeup: return "تعويض مستوى الضغط"
        case .intensity: return "قوة المؤثرات"
        default: return ""
        }
    }
    var explanation: String {
        switch self {
        case .input: return "يرفع صوت الميكروفون رقميًا؛ يرفع الضجيج أيضًا. قرّب الهاتف أولًا."
        case .recordGain: return "يضبط قوة الملف المحفوظ وحده. ارفعه تدريجيًا مع مراقبة مؤشر التسجيل."
        case .output: return "يضبط الاستماع في السماعة فقط، ولا يخفض التسجيل."
        case .low: return "يزيد أو يقلل عمق الصوت ودفء الأوتار الغليظة."
        case .mid: return "يبرز جسم النغمة وحضور العود وسط الصوت."
        case .high: return "يتحكم بلمعان الصوت ووضوح ضربة الريشة."
        case .compression: return "يقلّل الفرق بين الضربات القوية والهادئة ليصبح الأداء متوازنًا."
        case .reverb: return "يمزج رنين قاعة مع صوتك؛ زيادته تجعل المساحة أوضح."
        case .delay: return "يضيف نسخًا متكررة من النغمة بعد العزف."
        case .delayTime: return "يحدد الوقت الفاصل بين تكرارات النغمة."
        case .feedback: return "يزيد عدد التكرارات ومدة بقائها قبل أن تتلاشى."
        case .modulation: return "يحدد مقدار الامتلاء أو التموج حسب طابع الحركة المختار."
        case .modRate: return "يحدد سرعة تحرك طبقات الكورس أو تموّج الفلانجر."
        case .doubler: return "يضيف طبقة قصيرة متأخرة لإحساس قريب من عزف عودين معًا."
        case .decay: return "يحدد مدة بقاء رنين المكان بعد توقف العزف."
        case .predelay: return "يترك فراغًا قبل الرنين لتظل بداية النغمة واضحة."
        case .tone: return "يجعل رنين المكان داكنًا ودافئًا أو لامعًا ومشرقًا."
        case .makeup: return "يعوّض انخفاض المستوى بعد الضغط؛ خفّضه إذا زاد عمل حماية القمم."
        case .intensity: return "يزيد أو يقلل كمية المؤثرات المكانية والحركة معًا."
        default: return ""
        }
    }
    func text(_ value: Double) -> String {
        switch self {
        case .input, .output, .low, .mid, .high, .makeup, .recordGain: return String(format: "%.0f dB", value)
        case .delayTime, .predelay: return String(format: "%.0f ms", value)
        case .decay: return String(format: "%.1f s", value)
        case .modRate: return String(format: "%.1f Hz", value)
        default: return String(format: "%.0f%%", value * 100)
        }
    }
}

enum Effect: String, Codable, CaseIterable {
    case reverb, delay, motion, doubler, eq, compressor
    var parameters: [Parameter] {
        switch self {
        case .reverb: return [.reverb, .decay, .predelay, .tone]
        case .delay: return [.delay, .delayTime, .feedback]
        case .motion: return [.modulation, .modRate, .flanger]
        case .doubler: return [.doubler]
        case .eq: return [.low, .mid, .high]
        case .compressor: return [.compression, .makeup]
        }
    }
}

struct SoundSettings: Codable {
    var disabledEffects: Set<Effect> = []
    func enabled(_ effect: Effect) -> Bool { !disabledEffects.contains(effect) }
    func effective(_ p: Parameter) -> Double {
        for effect in disabledEffects where effect.parameters.contains(p) {
            switch p {
            case .reverb, .delay, .modulation, .doubler, .low, .mid, .high, .compression, .makeup: return 0
            default: break
            }
        }
        return self[p]
    }
    var preset = "طبيعي"
    var values: [Double] = [6,-9,0,0,0,0.25,0.24,0.12,320,0.32,0,0.7,0,0,0,0,2.4,22,0.5,4,1,0]
    init() {}
    private enum CodingKeys: String, CodingKey { case preset, values, disabledEffects }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decode(String.self, forKey: .preset)
        values = try container.decode([Double].self, forKey: .values)
        disabledEffects = try container.decodeIfPresent(Set<Effect>.self, forKey: .disabledEffects) ?? []
        // Preserve all v1 user settings; append only the new v2 controls.
        if values.count == 16 { values += [2.4,22,0.5,4,1] }
        if values.count == 21 { values += [0] }
    }
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
        case "عود صافي":
            s[.reverb] = 0.14; s[.decay] = 1.3; s[.predelay] = 25
            s[.delay] = 0; s[.modulation] = 0; s[.doubler] = 0
            s[.compression] = 0; s[.makeup] = 0
            s.disabledEffects = [.delay, .motion, .doubler, .eq, .compressor]
        case "كلاسيكي":
            s[.low] = 2; s[.high] = -2; s[.reverb] = 0.42; s[.compression] = 0.25
            s[.delay] = 0.14; s[.decay] = 2.8; s[.predelay] = 28; s[.tone] = 0.35
        case "فخم / ثقيل":
            s[.low] = 5; s[.mid] = -2; s[.high] = -1; s[.compression] = 0.48
            s[.reverb] = 0.58; s[.doubler] = 0.32; s[.delay] = 0.28
            s[.decay] = 4.4; s[.predelay] = 38; s[.tone] = 0.25; s[.makeup] = 6
        case "حاد":
            s[.low] = -4; s[.mid] = 4; s[.high] = 5; s[.reverb] = 0.18; s[.compression] = 0.3
            s[.delay] = 0.2; s[.delayTime] = 135; s[.decay] = 1.1; s[.tone] = 0.85
        case "مشكل":
            s[.low] = 2; s[.high] = 2; s[.reverb] = 0.5; s[.delay] = 0.42
            s[.delayTime] = 375; s[.modulation] = 0.36; s[.doubler] = 0.3; s[.compression] = 0.35
            s[.feedback] = 0.48; s[.decay] = 3.6
        case "تقاسيم":
            s[.reverb] = 0.38; s[.delay] = 0.08; s[.decay] = 3.2; s[.predelay] = 45; s[.compression] = 0.15
        case "طرب دافئ":
            s[.low] = 3; s[.high] = -3; s[.tone] = 0.2; s[.reverb] = 0.46; s[.decay] = 3.8
        case "ريشة واضحة":
            s[.low] = -2; s[.mid] = 3; s[.high] = 2; s[.predelay] = 60; s[.reverb] = 0.23; s[.delay] = 0.05
        case "مسرح":
            s[.compression] = 0.45; s[.reverb] = 0.5; s[.decay] = 3; s[.delay] = 0.23; s[.doubler] = 0.18
        case "مساحة واسعة":
            s[.reverb] = 0.6; s[.decay] = 4.8; s[.doubler] = 0.45; s[.modulation] = 0.15; s[.delay] = 0.18
        case "قاعة كبيرة":
            s[.reverb] = 0.78; s[.decay] = 6; s[.predelay] = 48
            s[.delay] = 0.3; s[.delayTime] = 470; s[.feedback] = 0.48; s[.doubler] = 0.25
        default: break
        }
        if mode == .voice {
            s[.low] = max(-12, s[.low] - 2); s[.mid] = min(12, s[.mid] + 1)
            s[.compression] = min(1, s[.compression] + 0.15)
        }
        return s
    }
    static let names = ["عود صافي", "طبيعي", "كلاسيكي", "فخم / ثقيل", "حاد", "مشكل", "قاعة كبيرة", "تقاسيم", "طرب دافئ", "ريشة واضحة", "مسرح", "مساحة واسعة"]
    static func detail(_ name: String) -> String {
        switch name {
        case "عود صافي": return "نبرة أصلية ومساحة خفيفة"
        case "تقاسيم": return "تفاصيل وزخارف حرة"
        case "طرب دافئ": return "نبرة ناعمة ورنين داكن"
        case "ريشة واضحة": return "بداية بارزة ومساحة خفيفة"
        case "مسرح": return "توازن وحضور للعزف"
        case "مساحة واسعة": return "اتساع وطبقات متحركة"
        case "طبيعي": return "واضح وقريب"
        case "كلاسيكي": return "دفء ومساحة ناعمة"
        case "فخم / ثقيل": return "عمق واتساع"
        case "حاد": return "ريشة بارزة وصدى قصير"
        case "مشكل": return "حركة وصدى متكرر"
        case "قاعة كبيرة": return "ذيل طويل وغامر"
        default: return "إعدادك الخاص"
        }
    }
}

struct SavedSettings: Codable {
    var oud = SoundSettings()
    var voice = SoundSettings.preset("طبيعي", mode: .voice)
    var mode = SoundMode.oud
    var stableBuffer = false
    var valid: Bool { oud.valid && voice.valid }
}

struct NamedSound: Codable, Identifiable {
    var id = UUID()
    var name: String
    var mode: SoundMode
    var settings: SoundSettings
}
