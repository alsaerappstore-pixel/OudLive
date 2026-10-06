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
        case .flanger: return "طابع الحركة"
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
        case .flanger: return "لف من الكورس الممتلئ إلى الفلانجر المعدني؛ المنتصف يمزج الطابعين."
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
        case .flanger: return value < 0.01 ? "كورس" : (value > 0.99 ? "فلانجر" : String(format: "مزج %.0f%%", value * 100))
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
    var unprocessed = false
    var disabledEffects: Set<Effect> = []
    func enabled(_ effect: Effect) -> Bool { !unprocessed && !disabledEffects.contains(effect) }
    func effective(_ p: Parameter) -> Double {
        if p == .bypass && unprocessed { return 1 }
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
    private enum CodingKeys: String, CodingKey { case preset, values, disabledEffects, unprocessed }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decode(String.self, forKey: .preset)
        values = try container.decode([Double].self, forKey: .values)
        unprocessed = try container.decodeIfPresent(Bool.self, forKey: .unprocessed) ?? false
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
        if let preset = RecordingPreset.all.first(where: { $0.name == name }) { return preset.description }
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


struct RecordingPreset: Identifiable {
    let id: Int
    let name: String
    let description: String
    private let controls: [Double]
    var isUnprocessed: Bool { id == 0 }
    func settings(preserving current: SoundSettings) -> SoundSettings {
        var s = SoundSettings(); s.preset = name; s.unprocessed = isUnprocessed
        let parameters: [Parameter] = [.low, .mid, .high, .compression, .makeup, .reverb, .decay, .predelay, .tone, .delay, .delayTime, .feedback, .modulation, .modRate, .flanger, .doubler]
        for (p, value) in zip(parameters, controls) { s[p] = value }
        for p in [Parameter.input, .output, .recordGain, .mute] { s[p] = current[p] }
        s[.bypass] = 0; s[.intensity] = 1
        if s[.reverb] == 0 { s.disabledEffects.insert(.reverb) }
        if s[.delay] == 0 { s.disabledEffects.insert(.delay) }
        if s[.modulation] == 0 { s.disabledEffects.insert(.motion) }
        if s[.doubler] == 0 { s.disabledEffects.insert(.doubler) }
        if s[.compression] == 0 { s.disabledEffects.insert(.compressor) }
        if s[.low] == 0 && s[.mid] == 0 && s[.high] == 0 { s.disabledEffects.insert(.eq) }
        return s
    }
    static let all: [RecordingPreset] = [
        RecordingPreset(id: 0, name: "بدون مؤثرات", description: "صوت المايك دون مؤثرات أو فلاتر التطبيق؛ تبقى مستويات الصوت وحماية القمم. معالجة السماعة نفسها يحددها الجهاز.", controls: [0, 0, 0, 0, 0, 0, 0.4, 0, 0.5, 0, 220, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 1, name: "الأصالة", description: "دفء قديم واضح: نبرة داكنة ورجعة قصيرة وحركة بطيئة", controls: [3, -3, -7, 0.28, 1, 0.48, 2.1, 15, 0.12, 0.3, 125, 0.1, 0.18, 0.22, 0, 0]),
        RecordingPreset(id: 2, name: "ريشة حادّة", description: "ريشة حادة وجافة: حضور مرتفع وقرار أخف", controls: [-5, 6, 6, 0.1, 0, 0.04, 0.45, 8, 0.85, 0, 180, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 3, name: "نقاء", description: "نقاء مركّز: حضور محسوب وضغط متوسط دون صدى أو حركة", controls: [-3, 3, 2, 0.45, 2, 0, 0.4, 0, 0.5, 0, 220, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 4, name: "عمق القاعة", description: "قاعة عميقة جدًا بذيل داكن وفاصل واضح قبل الصدى", controls: [1, -2, -2, 0.1, 0, 0.88, 6.4, 75, 0.1, 0.16, 540, 0.28, 0, 0.7, 0, 0]),
        RecordingPreset(id: 5, name: "مجلس خشبي", description: "جسم خشبي بارز مع انعكاسات غرفة قصيرة", controls: [1, 5, -4, 0.15, 0.5, 0.62, 0.7, 4, 0.3, 0, 200, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 6, name: "وتر حريري", description: "ريشة مخملية خفيفة الجسم مع رنين ناعم وتخفيف واضح للحضور", controls: [-5, -8, -10, 0.45, 2, 0.45, 1.8, 30, 0.08, 0, 240, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 7, name: "قرار عميق", description: "قرار ممتلئ بارز وجسم عميق مع صدى محدود", controls: [7, -4, -2, 0.18, 0.5, 0.08, 0.6, 18, 0.2, 0, 280, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 8, name: "بريق زجاجي", description: "رنين لامع زجاجي طويل وقرار خفيف", controls: [-6, -2, 7, 0.05, 0, 0.6, 3.6, 55, 1, 0, 320, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 9, name: "رجع خاطف", description: "رجعة خاطفة واضحة بعد الريشة بلا سلسلة تكرارات", controls: [0, 1, 0, 0.1, 0, 0.03, 0.4, 0, 0.5, 0.7, 85, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 10, name: "نبض متكرر", description: "تكرارات متوسطة منتظمة وواضحة بين الضربات", controls: [-2, 0, 1, 0.12, 0.3, 0.08, 1.1, 20, 0.5, 0.62, 285, 0.46, 0, 0.7, 0, 0]),
        RecordingPreset(id: 11, name: "حوار الوادي", description: "رد بعيد بعد الجملة مع تكرار داكن طويل", controls: [0, 2, -3, 0.08, 0, 0.18, 2.2, 40, 0.18, 0.72, 720, 0.32, 0, 0.7, 0, 0]),
        RecordingPreset(id: 12, name: "وتران", description: "عود مضاعف: طبقتان قصيرتان تمنحان عرضًا واضحًا", controls: [0, -1, 2, 0.1, 0.3, 0.05, 0.5, 8, 0.6, 0, 250, 0, 0, 0.7, 0, 0.68]),
        RecordingPreset(id: 13, name: "موج ناعم", description: "كورس واسع بتموّج بطيء وواضح", controls: [-1, 0, -1, 0.1, 0, 0.12, 1.5, 25, 0.4, 0, 360, 0, 0.68, 0.45, 0, 0]),
        RecordingPreset(id: 14, name: "طيف معدني", description: "فلانجر معدني متحرك بطابع تجريبي واضح", controls: [-2, 2, 1, 0.08, 0, 0.05, 0.5, 8, 0.6, 0, 260, 0, 0.78, 1.1, 1, 0]),
        RecordingPreset(id: 15, name: "أفق سينمائي", description: "أفق طويل مشرق: صدى بعيد وطبقات بطيئة", controls: [-3, -1, 3, 0.1, 0, 0.82, 7, 95, 0.72, 0.36, 1050, 0.5, 0.3, 0.14, 0, 0.15]),
        RecordingPreset(id: 16, name: "راديو قديم", description: "نبرة وسطية ضيقة وخشنة نسبيًا؛ قرار ولمعان أقل مع ضغط متوسط", controls: [-10, 8, -10, 0.45, 3, 0.08, 0.5, 0, 0.2, 0, 200, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 17, name: "صندوق جهير", description: "جسم جهير مضغوط ورجعة دافئة قصيرة؛ طابع ثقيل قريب", controls: [10, 3, -9, 0.5, 3, 0.3, 1.1, 8, 0.15, 0.28, 160, 0.08, 0, 0.7, 0, 0]),
        RecordingPreset(id: 18, name: "نقش الريشة", description: "وسط نافذ ورجعة قوية عند 55 مللي ثانية تنقش بداية الريشة", controls: [-10, 10, -5, 0.4, 1, 0.08, 0.4, 0, 0.4, 0.65, 55, 0.2, 0, 0.7, 0, 0]),
        RecordingPreset(id: 19, name: "مخمل مضغوط", description: "ضغط قوي وطبقة مخملية مضاعفة؛ وسط ولمعان ناعمان", controls: [2, -8, -5, 0.86, 7, 0.06, 0.5, 15, 0.1, 0, 200, 0, 0, 0.7, 0, 0.5]),
        RecordingPreset(id: 20, name: "إيقاع جاف", description: "ضغط قوي ووسط منحوت وريشة لامعة للعزف الإيقاعي دون صدى", controls: [-8, -5, 8, 1, 6, 0, 0.4, 0, 0.5, 0, 200, 0, 0, 0.7, 0, 0]),
        RecordingPreset(id: 21, name: "حجرة حجرية", description: "انعكاسات كثيفة قصيرة ومشرقة مع رجعة شبه فورية", controls: [-2, 2, 5, 0.13, 0, 0.9, 1, 0, 0.9, 0.26, 48, 0.12, 0, 0.7, 0, 0]),
        RecordingPreset(id: 22, name: "بئر مظلم", description: "رنين جهير طويل وتكرار بعيد داكن؛ مناسب لجمل متباعدة", controls: [5, -6, -10, 0.18, 1, 0.92, 7, 0, 0.06, 0.5, 930, 0.62, 0, 0.7, 0, 0]),
        RecordingPreset(id: 23, name: "قبة مضيئة", description: "مساحة لامعة كثيفة مع فاصل طويل يحفظ بداية الريشة", controls: [-4, 4, 8, 0.22, 0, 0.92, 5, 100, 0.95, 0.12, 175, 0.05, 0, 0.7, 0, 0]),
        RecordingPreset(id: 24, name: "رواق بعيد", description: "وسط مجوّف ورد متأخر بعد الجملة مع مساحة دافئة", controls: [3, -8, -1, 0.16, 0, 0.7, 3.3, 90, 0.28, 0.65, 1180, 0.2, 0, 0.7, 0, 0]),
        RecordingPreset(id: 25, name: "ظل قريب", description: "نسخة ملاصقة للريشة تعطي لونًا مجوفًا قصيرًا", controls: [-4, 4, -5, 0.3, 1, 0.1, 0.4, 0, 0.25, 0.9, 42, 0.18, 0, 0.7, 0, 0]),
        RecordingPreset(id: 26, name: "ثلاثيات", description: "تكرار كل 333 مللي ثانية؛ إحساس ثلاثي عند نحو 120 نبضة", controls: [-2, 1, 3, 0.2, 0.5, 0.16, 1.1, 20, 0.6, 0.8, 333, 0.57, 0.1, 0.7, 0, 0]),
        RecordingPreset(id: 27, name: "خطوة متباعدة", description: "رجعات ممتلئة طويلة العمر وبينها فراغ واضح", controls: [4, 0, -4, 0.32, 1, 0.06, 0.7, 10, 0.2, 0.82, 470, 0.65, 0, 0.7, 0, 0]),
        RecordingPreset(id: 28, name: "قطرات سريعة", description: "تكرارات متلاحقة لامعة بعد الريشة؛ طابع إيقاعي كثيف", controls: [-6, 1, 6, 0.25, 0.5, 0.2, 0.7, 5, 0.85, 0.78, 145, 0.7, 0, 0.7, 0, 0]),
        RecordingPreset(id: 29, name: "مرايا بطيئة", description: "كورس عميق بطيء جدًا مع رنين متوسط ورد خفيف", controls: [0, -4, 4, 0.25, 1, 0.35, 2.2, 35, 0.65, 0.23, 650, 0.2, 0.95, 0.12, 0, 0]),
        RecordingPreset(id: 30, name: "دوّامة", description: "كورس سريع واضح الحركة مع مساحة قصيرة جدًا", controls: [-3, 3, -3, 0.22, 0.5, 0.06, 0.6, 0, 0.4, 0, 200, 0, 0.95, 2.8, 0, 0]),
        RecordingPreset(id: 31, name: "معدن بطيء", description: "فلانجر بطيء وعميق يغيّر اللون المعدني تدريجيًا", controls: [3, -5, 4, 0.3, 1, 0.22, 1.8, 25, 0.6, 0.2, 390, 0.2, 0.95, 0.15, 1, 0]),
        RecordingPreset(id: 32, name: "وتر نحاسي", description: "فلانجر سريع مع وسط بارز ورنين محدود", controls: [-4, 6, -3, 0.3, 1, 0.18, 0.8, 10, 0.35, 0, 200, 0, 0.95, 2.5, 1, 0]),
        RecordingPreset(id: 33, name: "ثلاث طبقات", description: "مضاعفة قوية وكورس متوسط يمنحان العود جسمًا واسعًا", controls: [4, -3, 1, 0.3, 1, 0.14, 0.8, 18, 0.4, 0, 200, 0, 0.5, 0.8, 0, 1]),
        RecordingPreset(id: 34, name: "هالة زرقاء", description: "مزيج تجريبي مشرق من صدى طويل وتكرار وحركة ومضاعفة", controls: [-6, 0, 8, 0.3, 0.5, 0.95, 6, 95, 0.8, 0.8, 850, 0.58, 0.65, 0.35, 0.45, 0.5])
    ]
}


struct SoundBank: Codable {
    var slots: [NamedSound?] = Array(repeating: nil, count: 8)
    var valid: Bool { slots.count == 8 && slots.compactMap { $0 }.allSatisfy { $0.settings.valid } }
    mutating func save(_ sound: NamedSound, at index: Int) {
        guard slots.indices.contains(index), sound.settings.valid else { return }
        slots[index] = sound
    }
    mutating func clear(_ index: Int) {
        guard slots.indices.contains(index) else { return }; slots[index] = nil
    }
}
