import SwiftUI

@MainActor
struct QuickPresetGrid: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudEra) private var era
    @Environment(\.oudPalette) private var palette
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 5)
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("الضبط السريع").font(.headline)
                Spacer()
                Text("خمسة أوضاع طبيعية").font(.caption2).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(RecordingPreset.all) { preset in
                    let active = preset.isUnprocessed ? audio.settings.unprocessed :
                        (audio.mode == .oud && audio.settings.preset == preset.name && audio.value(.bypass) < 0.5)
                    let accent = preset.isUnprocessed ? Color.red : era.accent(theme, palette)
                    Button { audio.chooseRecordingPreset(preset) } label: {
                        VStack(spacing: 5) {
                            StatusLamp(on: active)
                            Text(preset.name).font(.caption2.bold()).multilineTextAlignment(.center)
                                .lineLimit(3).fixedSize(horizontal: false, vertical: true).frame(minHeight: 31)
                        }.padding(.horizontal, 3).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 66)
                            .background {
                                ZStack {
                                    EraSurface()
                                    RoundedRectangle(cornerRadius: era.radius(theme)).fill(active ? accent.opacity(0.2) : .clear)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: era.radius(theme)).strokeBorder(preset.isUnprocessed || active ? accent : accent.opacity(0.15), lineWidth: preset.isUnprocessed ? 2 : 1))
                    }.buttonStyle(.plain).foregroundStyle(era.ink(theme))
                        .accessibilityIdentifier("quick-preset-\(preset.id)")
                        .accessibilityLabel(preset.name).accessibilityHint(preset.description)
                        .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            Text("الحالي: \(audio.settings.preset)").font(.subheadline.bold())
            Text(SoundSettings.detail(audio.settings.preset)).font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("الأوضاع تحافظ على طبقة العود وأرباع الصوت. الانتقال متدرج ويحافظ على مستوياتك.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.environment(\.layoutDirection, .rightToLeft)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case studio, simple, stage
    var id: String { rawValue }
    var title: String { switch self { case .studio: return "استوديو"; case .simple: return "بسيط"; case .stage: return "مسرح" } }
    var icon: String { switch self { case .studio: return "dial.high.fill"; case .simple: return "square.grid.2x2.fill"; case .stage: return "switch.2" } }
    var subtitle: String { switch self { case .studio: return "مقابض دقيقة وتفاصيل الصوت"; case .simple: return "صوتك بضغطة واحدة"; case .stage: return "مفاتيح كبيرة للعزف الحي" } }
    var accent: Color { switch self { case .studio: return Color(red: 1, green: 0.68, blue: 0.35); case .simple: return Color(red: 0.04, green: 0.32, blue: 0.22); case .stage: return Color(red: 0.08, green: 0.94, blue: 0.76) } }
    var background: Color { self == .simple ? Color(red: 0.98, green: 0.96, blue: 0.91) : (self == .studio ? Color(red: 0.055, green: 0.065, blue: 0.075) : Color(red: 0.015, green: 0.04, blue: 0.065)) }
    var panel: Color { self == .simple ? Color(red: 0.94, green: 0.92, blue: 0.86) : (self == .studio ? Color(red: 0.10, green: 0.115, blue: 0.125) : Color(red: 0.045, green: 0.095, blue: 0.12)) }
    var ink: Color { self == .simple ? Color(red: 0.13, green: 0.105, blue: 0.07) : .white }
    var onAccent: Color { self == .simple ? .white : .black }
    var radius: CGFloat { self == .simple ? 26 : (self == .studio ? 12 : 16) }
}
enum AppPalette: String, CaseIterable, Identifiable {
    case original, gold, emerald, sapphire, violet, ruby, rose, ice, copper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "ألوان الشكل الأصلية"
        case .gold: return "ذهبي ملكي"
        case .emerald: return "أخضر زمردي"
        case .sapphire: return "أزرق ياقوتي"
        case .violet: return "بنفسجي"
        case .ruby: return "أحمر ياقوتي"
        case .rose: return "وردي"
        case .ice: return "فيروزي"
        case .copper: return "نحاسي"
        }
    }
    private var hue: Double {
        switch self { case .original, .gold: return 0.12; case .emerald: return 0.40; case .sapphire: return 0.60; case .violet: return 0.75; case .ruby: return 0.98; case .rose: return 0.91; case .ice: return 0.51; case .copper: return 0.065 }
    }
    func accent(_ theme: AppTheme) -> Color {
        if self == .original { return theme.accent }
        return Color(hue: hue, saturation: theme == .simple ? 0.82 : 0.52, brightness: theme == .simple ? 0.43 : 1)
    }
    func background(_ theme: AppTheme) -> Color {
        self == .original ? theme.background : Color(hue: hue, saturation: theme == .simple ? 0.035 : 0.32, brightness: theme == .simple ? 0.99 : 0.075)
    }
    func panel(_ theme: AppTheme) -> Color {
        self == .original ? theme.panel : Color(hue: hue, saturation: theme == .simple ? 0.08 : 0.30, brightness: theme == .simple ? 0.95 : 0.14)
    }
}
private struct OudPaletteKey: EnvironmentKey { static let defaultValue = AppPalette.original }
extension EnvironmentValues {
    var oudPalette: AppPalette { get { self[OudPaletteKey.self] } set { self[OudPaletteKey.self] = newValue } }
}
struct CopyrightFooter: View {
    var body: some View {
        Text("ياسر الغامدي 2026")
            .font(.caption2).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 4)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct OudThemeKey: EnvironmentKey { static let defaultValue = AppTheme.studio }
extension EnvironmentValues {
    var oudTheme: AppTheme { get { self[OudThemeKey.self] } set { self[OudThemeKey.self] = newValue } }
}

struct ThemedPanel: ViewModifier {
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @Environment(\.oudEra) private var era
    func body(content: Content) -> some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background { EraSurface() }
            .overlay(alignment: .topLeading) { if era == .eighties { ScrewHead().padding(5) } }
            .overlay(alignment: .bottomTrailing) { if era == .eighties { ScrewHead().padding(5) } }

    }
}

struct SignalLED: View {
    let level: Float
    let tint: Color
    var lights = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double { Double(max(0, min(1, (20 * log10(max(level, 0.00001)) + 60) / 60))) }
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<22, id: \.self) { index in
                let active = Double(index) / 22 < fraction
                let color: Color = index > 19 ? .red : (index > 16 ? .orange : tint)
                RoundedRectangle(cornerRadius: 2)
                    .fill(active ? color : tint.opacity(0.10))
                    .shadow(color: lights && !reduceMotion && active ? color.opacity(0.5) : .clear, radius: 3)
            }
        }.frame(height: 16).environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel("مؤشر الصوت").accessibilityValue(String(format: "%.0f ديسيبل", 20 * log10(max(level, 0.00001))))
    }
}

struct RotaryControl: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    var diameter: CGFloat = 78
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @Environment(\.oudEra) private var era
    @State private var dragStart: Double?
    private var normalized: Double { (audio.value(parameter) - parameter.range.lowerBound) / (parameter.range.upperBound - parameter.range.lowerBound) }
    private func nudge(_ direction: Double) {
        let step = (parameter.range.upperBound - parameter.range.lowerBound) / 100
        audio.set(parameter, audio.value(parameter) + direction * step)
    }
    var body: some View {
        ZStack {
            Circle().trim(from: 0.12, to: 0.88).stroke(era.accent(theme, palette).opacity(0.14), style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
            Circle().trim(from: 0.12, to: 0.12 + 0.76 * normalized).stroke(era.accent(theme, palette), style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
            KnobFace().padding(9)
                .overlay(Circle().strokeBorder(era.ink(theme).opacity(0.17), lineWidth: 1).padding(9))
            Capsule().fill(era.accent(theme, palette)).frame(width: 4, height: diameter * 0.22)
                .offset(y: -diameter * 0.22).rotationEffect(.degrees(-137 + normalized * 274))
        }.frame(width: diameter, height: diameter)
            .environment(\.layoutDirection, .leftToRight)
            .gesture(DragGesture(minimumDistance: 8).onChanged { drag in
                if dragStart == nil { dragStart = audio.value(parameter) }
                let change = -Double(drag.translation.height) / 180 * (parameter.range.upperBound - parameter.range.lowerBound)
                audio.set(parameter, (dragStart ?? audio.value(parameter)) + change)
            }.onEnded { _ in dragStart = nil })
            .accessibilityElement(children: .ignore).accessibilityLabel(parameter.label)
            .accessibilityValue(parameter.text(audio.value(parameter)))
            .accessibilityHint("اسحب لأعلى للزيادة ولأسفل للتقليل")
            .accessibilityAdjustableAction { direction in nudge(direction == .increment ? 1 : -1) }
    }
}

struct ThemeParameterControl: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @Environment(\.oudEra) private var era
    @AppStorage("OudLive.showExplanations") private var explanations = true
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                RotaryControl(audio: audio, parameter: parameter, diameter: 82)
                HStack(spacing: 12) {
                    adjustButton("minus", direction: -1)
                    adjustButton("plus", direction: 1)
                }.environment(\.layoutDirection, .leftToRight)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(parameter.label).font(.subheadline.bold())
                Text(parameter.text(audio.value(parameter))).font(.title3.monospacedDigit()).foregroundStyle(era.accent(theme, palette))
                if explanations { Text(parameter.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func adjustButton(_ icon: String, direction: Double) -> some View {
        Button { audio.set(parameter, audio.value(parameter) + direction * (parameter.range.upperBound - parameter.range.lowerBound) / 100) } label: {
            Image(systemName: icon).font(.caption.bold()).frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel((direction > 0 ? "زيادة " : "تقليل ") + parameter.label)
    }
}

extension Effect {
    var title: String { switch self { case .reverb: return "مساحة"; case .delay: return "تكرار"; case .space: return "مكان"; case .noise: return "هدوء"; case .eq: return "نبرة"; case .compressor: return "ضغط" } }
    var symbol: String { switch self { case .reverb: return "building.columns"; case .delay: return "repeat"; case .space: return "waveform.path"; case .noise: return "square.on.square"; case .eq: return "slider.horizontal.3"; case .compressor: return "waveform" } }
    var summary: String { switch self { case .reverb: return "رنين المكان"; case .delay: return "نسخ متكررة"; case .space: return "انعكاسات واتساع"; case .noise: return "ضجيج خافت"; case .eq: return "دفء ولمعان"; case .compressor: return "توازن القوة" } }
}


enum AppEra: String, CaseIterable, Identifiable {
    case eighties, nineties, modern
    var id: String { rawValue }
    var title: String { switch self { case .eighties: return "الثمانينات • نيكل"; case .nineties: return "التسعينات • رقمي"; case .modern: return "الألفينات • زجاج" } }
    var badge: String { switch self { case .eighties: return "1980 / ANALOG"; case .nineties: return "1990 / DIGITAL"; case .modern: return "2000 / STUDIO" } }
    func ink(_ theme: AppTheme) -> Color { self == .eighties ? Color(white: 0.13) : (self == .nineties ? Color(white: 0.94) : theme.ink) }
    func onAccent(_ theme: AppTheme) -> Color { self == .eighties ? .white : (self == .nineties ? .black : theme.onAccent) }
    func accent(_ theme: AppTheme, _ palette: AppPalette) -> Color {
        if self == .modern { return palette.accent(theme) }
        if palette != .original { return palette.accent(self == .eighties ? .simple : .stage) }
        return self == .eighties ? Color(red: 0.48, green: 0.19, blue: 0.07) : Color(red: 0.55, green: 0.98, blue: 0.28)
    }
    func background(_ theme: AppTheme, _ palette: AppPalette) -> Color { self == .eighties ? Color(white: 0.72) : (self == .nineties ? Color(red: 0.045, green: 0.055, blue: 0.075) : palette.background(theme)) }
    func panel(_ theme: AppTheme, _ palette: AppPalette) -> Color { self == .eighties ? Color(white: 0.84) : (self == .nineties ? Color(red: 0.10, green: 0.12, blue: 0.15) : palette.panel(theme)) }
    func radius(_ theme: AppTheme) -> CGFloat { self == .eighties ? 5 : (self == .nineties ? 9 : theme.radius) }
}
private struct OudEraKey: EnvironmentKey { static let defaultValue = AppEra.eighties }
extension EnvironmentValues {
    var oudEra: AppEra { get { self[OudEraKey.self] } set { self[OudEraKey.self] = newValue } }
}

struct EraSurface: View {
    @Environment(\.oudEra) private var era
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    var body: some View {
        ZStack {
            if era == .eighties {
                LinearGradient(colors: [Color(white: 0.96), Color(white: 0.72), Color(white: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for y in stride(from: 0.0, to: size.height, by: 3) {
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(.black.opacity(0.035)), lineWidth: 0.5)
                    }
                }
            } else { era.panel(theme, palette) }
        }.clipShape(RoundedRectangle(cornerRadius: era.radius(theme)))
            .overlay(RoundedRectangle(cornerRadius: era.radius(theme)).strokeBorder(era == .eighties ? Color.white.opacity(0.8) : era.accent(theme, palette).opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(era == .eighties ? 0.2 : 0.1), radius: 3, y: 2)
            .allowsHitTesting(false)
    }
}
struct ScrewHead: View {
    var body: some View {
        Circle().fill(LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Rectangle().fill(Color.black.opacity(0.5)).frame(width: 5, height: 1).rotationEffect(.degrees(-30)))
            .frame(width: 8, height: 8).accessibilityHidden(true)
    }
}
struct KnobFace: View {
    @Environment(\.oudEra) private var era
    var body: some View {
        ZStack {
            Circle().fill(AngularGradient(colors: era == .eighties ? [Color(white: 0.96), Color(white: 0.44), .white, Color(white: 0.60), Color(white: 0.96)] : [Color(white: 0.30), .black, Color(white: 0.25), .black, Color(white: 0.30)], center: .center))
            ForEach(0..<36, id: \.self) { n in
                Rectangle().fill(era == .eighties ? .black.opacity(0.14) : .white.opacity(0.16)).frame(width: 1, height: 4).offset(y: -28).rotationEffect(.degrees(Double(n) * 10))
            }
            Circle().strokeBorder(.white.opacity(0.36), lineWidth: 1).padding(4)
        }.shadow(color: .black.opacity(0.5), radius: 3, y: 3)
    }
}
struct StatusLamp: View {
    let on: Bool
    var activity: Float = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("OudLive.reactiveLights") private var reactiveLights = true
    private var glow: Double { reactiveLights && !reduceMotion ? Double(min(1, max(0, activity * 4))) : 0 }
    var body: some View {
        Circle().fill(RadialGradient(colors: on ? [Color(red: 0.95, green: 1, blue: 0.7), .green, Color(red: 0.01, green: 0.3, blue: 0.03)] : [Color(white: 0.20), Color(white: 0.08)], center: .topLeading, startRadius: 0, endRadius: 12))
            .frame(width: 12, height: 12).overlay(Circle().strokeBorder(.black.opacity(0.65), lineWidth: 1))
            .shadow(color: on ? .green.opacity(0.35 + glow * 0.45) : .clear, radius: 4 + glow * 8).accessibilityHidden(true)
    }
}
struct EffectPowerLight: View {
    @ObservedObject var audio: AudioModel
    let effect: Effect
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudEra) private var era
    var body: some View {
        Button { audio.setEnabled(effect, !audio.settings.enabled(effect)) } label: {
            HStack(spacing: 8) {
                StatusLamp(on: audio.settings.enabled(effect) && audio.value(.bypass) < 0.5, activity: audio.recordingLevel)
                Text(effect.title).font(.caption.bold())
            }.frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 5).background { EraSurface() }
        }.buttonStyle(.plain).foregroundStyle(era.ink(theme))
            .accessibilityLabel(effect.title).accessibilityValue(audio.settings.enabled(effect) ? "مفعّل" : "متوقف")
            .accessibilityHint("اضغط لتشغيل أو إيقاف التأثير")
    }
}
struct EraMeter: View {
    let level: Float
    @Environment(\.oudEra) private var era
    private var fraction: Double { Double(max(0, min(1, (20 * log10(max(level, 0.00001)) + 60) / 60))) }
    var body: some View {
        if era == .eighties {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.94, green: 0.88, blue: 0.68))
                HStack { Text("−60"); Spacer(); Text("−30"); Spacer(); Text("0").foregroundStyle(.red) }.font(.system(size: 9, design: .monospaced)).padding(6).frame(maxHeight: .infinity, alignment: .top).environment(\.layoutDirection, .leftToRight)
                Canvas { context, size in
                    let base = CGPoint(x: size.width / 2, y: size.height - 3)
                    let angle = (-150 + 120 * fraction) * .pi / 180
                    var needle = Path(); needle.move(to: base)
                    needle.addLine(to: CGPoint(x: base.x + cos(angle) * min(size.width * 0.45, 70), y: base.y + sin(angle) * 30))
                    context.stroke(needle, with: .color(Color(red: 0.6, green: 0.05, blue: 0.03)), lineWidth: 2)
                }
                Text("VU").font(.system(size: 8, weight: .bold, design: .serif)).foregroundStyle(.black).padding(.bottom, 2)
            }.frame(height: 48).overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black.opacity(0.6), lineWidth: 2)).foregroundStyle(.black)
        } else {
            SignalLED(level: level, tint: .green).padding(7).background(.black, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}


@MainActor
struct QuickSoundBank: View {
    @ObservedObject var audio: AudioModel
    @State private var editing = 0
    @State private var name = ""
    @State private var showSave = false
    @State private var clearing = 0
    @State private var showClear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("خاناتي • ٨ أصوات").font(.headline)
                Spacer()
                Menu("حفظ الحالي") {
                    ForEach(0..<8, id: \.self) { index in
                        Button("\(index + 1) • " + (audio.soundBank.slots[index]?.name ?? "فارغة")) { edit(index) }
                    }
                }.font(.caption.bold()).frame(minHeight: 44)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    let sound = audio.soundBank.slots[index]
                    Button {
                        if let sound { audio.loadSound(sound) } else { edit(index) }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 5) {
                                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                                StatusLamp(on: sound != nil && audio.settings.preset == sound?.name && audio.mode == sound?.mode)
                            }
                            Text(sound?.name ?? "＋ حفظ").font(.caption2.bold()).lineLimit(2).frame(minHeight: 26)
                        }.frame(maxWidth: .infinity, minHeight: 62).padding(5).background { EraSurface() }
                    }.buttonStyle(.plain).accessibilityLabel("الخانة \(index + 1): " + (sound?.name ?? "حفظ الصوت الحالي"))
                        .contextMenu {
                            Button("حفظ الحالي هنا") { edit(index) }
                            if sound != nil { Button("إفراغ الخانة", role: .destructive) { clearing = index; showClear = true } }
                        }
                }
            }
            Text("اضغط الفارغة للحفظ والممتلئة للاستعادة. اضغط مطولًا للاستبدال أو الإفراغ. تحفظ المؤثرات ومفاتيحها ووضع العود أو الصوت؛ تبقى مستوياتك الحالية عند الاستعادة.").font(.caption2).foregroundStyle(.secondary)
        }
        .alert(audio.soundBank.slots[editing] == nil ? "حفظ في الخانة \(editing + 1)" : "استبدال الخانة \(editing + 1)؟", isPresented: $showSave) {
            TextField("اسم تخصيصك", text: $name)
            Button("حفظ") { audio.saveSlot(editing, name: name) }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("يحفظ إعدادات الصوت الحالية؛ استبدال الخانة يمحو إعدادها السابق.") }
        .alert("إفراغ الخانة؟", isPresented: $showClear) {
            Button("إفراغ", role: .destructive) { audio.clearSlot(clearing) }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("يحذف التخصيص المحفوظ في هذه الخانة فقط.") }
    }
    private func edit(_ index: Int) { editing = index; name = audio.soundBank.slots[index]?.name ?? ""; showSave = true }
}
