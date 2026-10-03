import SwiftUI

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
        Text("جميع الحقوق محفوظة © ياسر الغامدي")
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
    func body(content: Content) -> some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.panel(theme), in: RoundedRectangle(cornerRadius: theme.radius))
            .overlay(RoundedRectangle(cornerRadius: theme.radius).strokeBorder(palette.accent(theme).opacity(theme == .stage ? 0.24 : 0.08), lineWidth: 1))
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
    @State private var dragStart: Double?
    private var normalized: Double { (audio.value(parameter) - parameter.range.lowerBound) / (parameter.range.upperBound - parameter.range.lowerBound) }
    private func nudge(_ direction: Double) {
        let step = (parameter.range.upperBound - parameter.range.lowerBound) / 100
        audio.set(parameter, audio.value(parameter) + direction * step)
    }
    var body: some View {
        ZStack {
            Circle().trim(from: 0.12, to: 0.88).stroke(palette.accent(theme).opacity(0.14), style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
            Circle().trim(from: 0.12, to: 0.12 + 0.76 * normalized).stroke(palette.accent(theme), style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
            Circle().fill(palette.background(theme)).padding(9)
                .overlay(Circle().strokeBorder(theme.ink.opacity(0.17), lineWidth: 1).padding(9))
            Capsule().fill(palette.accent(theme)).frame(width: 4, height: diameter * 0.22)
                .offset(y: -diameter * 0.22).rotationEffect(.degrees(-137 + normalized * 274))
        }.frame(width: diameter, height: diameter)
            .environment(\.layoutDirection, .leftToRight)
            .gesture(DragGesture(minimumDistance: 1).onChanged { drag in
                if dragStart == nil { dragStart = audio.value(parameter) }
                let change = -Double(drag.translation.height) / 180 * (parameter.range.upperBound - parameter.range.lowerBound)
                audio.set(parameter, (dragStart ?? audio.value(parameter)) + change)
            }.onEnded { _ in dragStart = nil })
            .accessibilityElement(children: .ignore).accessibilityLabel(parameter.label)
            .accessibilityValue(parameter.text(audio.value(parameter)))
            .accessibilityAdjustableAction { direction in nudge(direction == .increment ? 1 : -1) }
    }
}

struct ThemeParameterControl: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @AppStorage("OudLive.showExplanations") private var explanations = true
    var body: some View {
        if theme == .studio {
            HStack(spacing: 16) {
                RotaryControl(audio: audio, parameter: parameter)
                VStack(alignment: .leading, spacing: 6) {
                    Text(parameter.label).font(.subheadline.bold())
                    Text(parameter.text(audio.value(parameter))).font(.title3.monospacedDigit()).foregroundStyle(palette.accent(theme))
                    if explanations { Text(parameter.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    Slider(value: Binding(get: { audio.value(parameter) }, set: { audio.set(parameter, $0) }), in: parameter.range)
                        .accessibilityLabel(parameter.label)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(parameter.label).font(.headline); Spacer(); Text(parameter.text(audio.value(parameter))).monospacedDigit().foregroundStyle(palette.accent(theme)) }
                if explanations { Text(parameter.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                HStack {
                    adjustButton("minus", direction: -1)
                    Slider(value: Binding(get: { audio.value(parameter) }, set: { audio.set(parameter, $0) }), in: parameter.range).accessibilityLabel(parameter.label)
                    adjustButton("plus", direction: 1)
                }
            }
        }
    }
    private func adjustButton(_ icon: String, direction: Double) -> some View {
        Button { audio.set(parameter, audio.value(parameter) + direction * (parameter.range.upperBound - parameter.range.lowerBound) / 20) } label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44).background(palette.accent(theme).opacity(0.1), in: RoundedRectangle(cornerRadius: theme == .stage ? 8 : 22))
        }.buttonStyle(.plain).accessibilityLabel((direction > 0 ? "زيادة " : "تقليل ") + parameter.label)
    }
}

extension Effect {
    var title: String { switch self { case .reverb: return "مساحة"; case .delay: return "تكرار"; case .motion: return "حركة"; case .doubler: return "مضاعفة"; case .eq: return "نبرة"; case .compressor: return "ضغط" } }
    var symbol: String { switch self { case .reverb: return "building.columns"; case .delay: return "repeat"; case .motion: return "waveform.path"; case .doubler: return "square.on.square"; case .eq: return "slider.horizontal.3"; case .compressor: return "waveform" } }
    var summary: String { switch self { case .reverb: return "رنين المكان"; case .delay: return "نسخ متكررة"; case .motion: return "كورس / فلانجر"; case .doubler: return "طبقة إضافية"; case .eq: return "دفء ولمعان"; case .compressor: return "توازن القوة" } }
}
