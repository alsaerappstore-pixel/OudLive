import Foundation

enum SoundMode: String, Codable, CaseIterable, Identifiable {
    case oud, voice // voice is decoded only for migration; no active voice processor.
    static var allCases: [SoundMode] { [.oud] }
    var id: String { rawValue }
    var title: String { "العود الطبيعي" }
}
enum Parameter: Int, CaseIterable {
    // ABI v4; slots 10...13 replace removed modulation processors.
    case input, output, low, mid, high, compression, reverb, delay, delayTime, feedback, roomSize, width, early, noise, bypass, mute, decay, predelay, tone, makeup, intensity, recordGain, live, trim
    var range: ClosedRange<Double> {
        switch self {
        case .input: return -24...24
        case .output: return -60...0
        case .low: return -3...3
        case .mid: return -3...3
        case .high: return -3...3
        case .compression: return 0...1
        case .reverb: return 0...0.3
        case .delay: return 0...0.15
        case .delayTime: return 40...5000
        case .feedback: return 0...0.35
        case .roomSize: return 0...1
        case .width: return 0...0.65
        case .early: return 0...0.7
        case .noise: return 0...0.5
        case .bypass: return 0...1
        case .mute: return 0...1
        case .decay: return 0.5...5
        case .predelay: return 10...40
        case .tone: return 0...1
        case .makeup: return 0...2
        case .intensity: return 0...1
        case .recordGain: return -12...18
        case .live: return 0...1
        case .trim: return -3...3
        }
    }
    var label: String {
        switch self {
        case .input: return "تقوية الالتقاط"
        case .output: return "مستوى السماعة"
        case .low: return "الجسم الخشبي • 230 Hz"
        case .mid: return "الريشة • 1.5 kHz"
        case .high: return "نعومة الوتر • 4 kHz"
        case .compression: return "التحكم الديناميكي"
        case .reverb: return "مساحة الغرفة"
        case .delay: return "رجع دافئ"
        case .delayTime: return "زمن الرجع"
        case .feedback: return "استمرار الرجع"
        case .roomSize: return "حجم الغرفة"
        case .width: return "اتساع المكان"
        case .early: return "الانعكاسات المبكرة"
        case .noise: return "تهدئة الضجيج"
        case .bypass: return "مقارنة بالأصل"
        case .mute: return "كتم المراقبة"
        case .decay: return "زمن الرنين"
        case .predelay: return "فاصل قبل الرنين"
        case .tone: return "دفء الرنين"
        case .makeup: return "تعويض خفيف"
        case .intensity: return "كمية المساحة"
        case .recordGain: return "مستوى التسجيل"
        case .live: return "استجابة حية"
        case .trim: return "توازن الوضع"
        }
    }
    var explanation: String {
        switch self {
        case .input: return "يرفع الميكروفون رقميًا مع الضجيج؛ قرّب المايك أولًا."
        case .output: return "مستوى المراقبة فقط، مستقل عن الملف."
        case .low: return "دفء معتدل يحافظ على جسم العود."
        case .mid: return "وضوح ضربة الريشة دون تغيير الطبقة."
        case .high: return "تحكم لطيف بالحدة؛ توجد موازنة تلقائية محدودة عند زيادة الخشونة."
        case .compression: return "ضغط خفيف بنسبة 1.5–2.5:1، وحد أقصى 4 dB للتخفيض قبل حماية القمم."
        case .reverb: return "رنين طبيعي خلف الصوت الأصلي، بحد مزج محافظ."
        case .delay: return "تكرارات خافتة تُرشح في كل دورة لتصبح أدفأ وأغمق."
        case .delayTime: return "زمن التكرار؛ لا يؤخر المسار الأصلي. يدعم داخليًا حتى خمس ثوانٍ."
        case .feedback: return "تكرار محدود لا يتراكم فوق الريشة."
        case .roomSize: return "يضبط انتشار الانعكاسات مع بقاء العود في المقدمة."
        case .width: return "يوسع الرنين فقط؛ أصل العود في الوسط، دون تغيير طبقة أو كورس."
        case .early: return "انعكاسات أولية خافتة تحدد خشبية المكان أو صلابته."
        case .noise: return "تمدد ناعم محدود في المقاطع الهادئة، دون بوابة تقطع ذيل النغمة."
        case .bypass: return "مقارنة مؤقتة بصوت الميكروفون."
        case .mute: return "لا يكتم التسجيل."
        case .decay: return "المدى الطبيعي في الأوضاع 0.6–3.2 ثانية؛ الحد الداخلي خمس ثوانٍ."
        case .predelay: return "يحافظ على ضربة الريشة قبل وصول رنين المكان."
        case .tone: return "ترشيح علوي تقريبي 5–9 kHz للرنين، ومزيد من التخميد عند الدفء."
        case .makeup: return "تعويض محدود بعد الضغط، دون تعظيم للجهارة."
        case .intensity: return "يتحكم في المساحة والتكرار فقط؛ يبقى أصل العود أساس الصوت."
        case .recordGain: return "مستوى الملف المحفوظ مستقل عن السماعة."
        case .live: return "يوقف الرجع المتكرر ويضيق المساحة ويطلب مخزنًا صغيرًا؛ لا يزيل تأخير البلوتوث."
        case .trim: return "تعويض داخلي محافظ لمقاربة مستويات الأوضاع."
        }
    }
    func text(_ value: Double) -> String {
        switch self {
        case .input, .output, .low, .mid, .high, .makeup, .recordGain, .trim: return String(format: "%.1f dB", value)
        case .delayTime, .predelay: return String(format: "%.0f ms", value)
        case .decay: return String(format: "%.1f s", value)
        default: return String(format: "%.0f%%", value * 100)
        }
    }
}
enum Effect: String, Codable, CaseIterable {
    case reverb, delay, space, noise, eq, compressor
    var parameters: [Parameter] {
        switch self {
        case .reverb: return [.reverb, .decay, .predelay, .tone]
        case .delay: return [.delay, .delayTime, .feedback]
        case .space: return [.roomSize, .width, .early]
        case .noise: return [.noise]
        case .eq: return [.low, .mid, .high]
        case .compressor: return [.compression, .makeup]
        }
    }
}
struct SoundSettings: Codable {
    var schema = 4
    var unprocessed = false // retained for decoding, never a main preset
    var disabledEffects: Set<Effect> = []
    var preset = "Wooden Majlis"
    var values: [Double] = [6, -9, 1, -0.2, -0.6, 0.2, 0.13, 0, 250, 0, 0.35, 0.25, 0.4, 0.15, 0, 0, 1.2, 24, 0.25, 0.35, 1, 0, 1, -0.4]
    init() {}
    func enabled(_ effect: Effect) -> Bool { !disabledEffects.contains(effect) }
    func effective(_ p: Parameter) -> Double {
        for effect in disabledEffects where effect.parameters.contains(p) {
            if [.reverb,.delay,.width,.early,.noise,.low,.mid,.high,.compression,.makeup].contains(p) { return 0 }
        }
        return self[p]
    }
    private enum CodingKeys: String, CodingKey { case schema, preset, values, disabledEffects, unprocessed }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let oldName = try c.decode(String.self, forKey: .preset)
        let oldValues = try c.decode([Double].self, forKey: .values)
        let version = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 0
        if version == 4 {
            preset = Self.names.contains(oldName) ? oldName : "Wooden Majlis"
            values = oldValues
            disabledEffects = try c.decodeIfPresent(Set<Effect>.self, forKey: .disabledEffects) ?? []
        } else {
            let mappings = ["معدن بطيء":"Slow Metal", "إيقاع جاف":"Dry Rhythm", "حجرة حجرية":"Stone Chamber", "مجلس خشبي":"Wooden Majlis", "ريشة حادّة":"Sharp Pick"]
            self = Self.preset(mappings[oldName] ?? "Wooden Majlis", mode: .oud)
            guard [16,21,22].contains(oldValues.count), oldValues.allSatisfy({ $0.isFinite }) else { values = []; return }
            // Keep device levels; old pitch/modulation recipes cannot re-enter the engine.
            for p in [Parameter.input,.output] { self[p] = oldValues[p.rawValue] }
            if oldValues.count > 21 { self[.recordGain] = oldValues[21] }
        }
        schema = 4; unprocessed = false
    }
    subscript(_ p: Parameter) -> Double {
        get { values[p.rawValue] }
        set { if newValue.isFinite { values[p.rawValue] = min(p.range.upperBound, max(p.range.lowerBound, newValue)) } }
    }
    var valid: Bool { values.count == Parameter.allCases.count && values.enumerated().allSatisfy { $0.element.isFinite && Parameter(rawValue: $0.offset)!.range.contains($0.element) } }
    static let names = ["Slow Metal", "Dry Rhythm", "Stone Chamber", "Wooden Majlis", "Sharp Pick", "Velvet Bass", "Clear Studio", "Open Courtyard", "Tarab Hall", "Silk Strings"]
    static func preset(_ name: String, mode: SoundMode) -> SoundSettings {
        var s = SoundSettings()
        guard let recipe = RecordingPreset.all.first(where: { $0.name == name }) else { return s }
        s.preset = recipe.name; s.values = recipe.controls
        return s
    }
    static func imageName(_ name: String) -> String { RecordingPreset.all.first(where: { $0.name == name })?.imageName ?? "OudPreset3" }
    static func detail(_ name: String) -> String { RecordingPreset.all.first(where: { $0.name == name })?.description ?? "تخصيص طبيعي للعود" }
}
struct SavedSettings: Codable {
    var oud = SoundSettings()
    var voice = SoundSettings() // compatibility only
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
    let controls: [Double]
    var imageName: String { "OudPreset\(id)" }
    var isUnprocessed: Bool { false }
    func settings(preserving current: SoundSettings) -> SoundSettings {
        var s = SoundSettings.preset(name, mode: .oud)
        for p in [Parameter.input,.output,.recordGain,.mute,.live] { s[p] = current[p] }
        return s
    }
    static let all: [RecordingPreset] = [
        RecordingPreset(id: 0, name: "Slow Metal", description: "عمق دافئ ورنين أوتار داكن في غرفة واسعة، دون تشويه أو طابع كهربائي.", controls: [6, -9, 1.5, 0.3, -1.4, 0.3, 0.2, 0.035, 380, 0.16, 0.65, 0.45, 0.3, 0.15, 0, 0, 2.3, 30, 0.15, 0.5, 1, 0, 1, -0.6]),
        RecordingPreset(id: 1, name: "Dry Rhythm", description: "عود قريب وجاف، يحافظ على سرعة الريشة وتفاصيل العزف الإيقاعي.", controls: [6, -9, -0.5, 1, -0.4, 0.18, 0.025, 0, 180, 0, 0.15, 0.1, 0.12, 0.1, 0, 0, 0.8, 12, 0.45, 0.3, 1, 0, 1, 0]),
        RecordingPreset(id: 2, name: "Stone Chamber", description: "حجرة حجرية متوسطة، بانعكاسات أوضح وصوت عود أصلي في المقدمة.", controls: [6, -9, 0.3, 0.4, -0.4, 0.25, 0.16, 0.015, 220, 0.1, 0.45, 0.35, 0.55, 0.15, 0, 0, 1.45, 20, 0.65, 0.4, 1, 0, 1, -0.3]),
        RecordingPreset(id: 3, name: "Wooden Majlis", description: "مجلس خشبي حميم ودافئ، بجسم غني ورنين قصير ناعم.", controls: [6, -9, 1, -0.2, -0.6, 0.2, 0.13, 0, 250, 0, 0.35, 0.25, 0.4, 0.15, 0, 0, 1.2, 24, 0.25, 0.35, 1, 0, 1, -0.4]),
        RecordingPreset(id: 4, name: "Sharp Pick", description: "حضور دقيق للريشة دون ترقيق الجسم الخشبي أو زيادة خشونة الوتر.", controls: [6, -9, 0.4, 1.7, -0.8, 0.15, 0.045, 0, 160, 0, 0.2, 0.12, 0.15, 0.1, 0, 0, 0.85, 18, 0.5, 0.25, 1, 0, 1, -0.25]),
        RecordingPreset(id: 5, name: "Velvet Bass", description: "جسم عميق مستدير مع رنين قريب، يبرز القرار دون طمس الريشة.", controls: [6, -9, 2.5, -1, -1.8, 0.28, 0.08, 0, 240, 0, 0.25, 0.18, 0.22, 0.12, 0, 0, 1, 25, 0.12, 0.35, 1, 0, 1, -0.8]),
        RecordingPreset(id: 6, name: "Clear Studio", description: "توازن محايد ومساحة شبه جافة، للتفاصيل الدقيقة وصوت الميكروفون الطبيعي.", controls: [6, -9, -0.6, 0.2, 0.7, 0.1, 0.035, 0, 120, 0, 0.1, 0.1, 0.1, 0.1, 0, 0, 0.6, 10, 0.8, 0.2, 1, 0, 1, 0.1]),
        RecordingPreset(id: 7, name: "Open Courtyard", description: "هواء وانعكاسات متباعدة خفيفة مع بقاء العود قريبًا وواضحًا.", controls: [6, -9, -0.8, -0.5, 1.2, 0.16, 0.19, 0.045, 290, 0.12, 0.8, 0.6, 0.65, 0.1, 0, 0, 1.7, 38, 0.85, 0.25, 1, 0, 1, 0.6]),
        RecordingPreset(id: 8, name: "Tarab Hall", description: "رنين ممتد ودافئ للجمل البطيئة والتقاسيم مع حضور واضح للريشة.", controls: [6, -9, 0.7, 0.8, -0.7, 0.22, 0.28, 0.065, 440, 0.22, 0.9, 0.55, 0.42, 0.1, 0, 0, 3.2, 35, 0.3, 0.4, 1, 0, 1, -0.65]),
        RecordingPreset(id: 9, name: "Silk Strings", description: "نعومة للترددات الحادة وقرب حميم، للعزف الهادئ دون تغيير الطبقة.", controls: [6, -9, 0.3, -1.2, -2.5, 0.34, 0.11, 0, 180, 0, 0.2, 0.2, 0.3, 0.15, 0, 0, 0.9, 16, 0.1, 0.55, 1, 0, 1, 0.15]),
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

