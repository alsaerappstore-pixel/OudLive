import SwiftUI

@MainActor
struct PerformanceModes: View {
    @ObservedObject var audio: AudioModel
    let openEffects: () -> Void
    let openRecording: () -> Void
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @Environment(\.oudEra) private var era
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("OudLive.reactiveLights") private var lights = true
    @AppStorage("OudLive.showExplanations") private var explanations = true
    @State private var allSounds = false
    private let effects: [Effect] = [.reverb, .delay, .space, .noise, .eq, .compressor]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if theme == .studio { studio }
            if theme == .simple { simple }
            if theme == .stage { stage }
            comparisonControls
            HStack {
                Button(action: openEffects) { Label("كل المؤثرات", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, minHeight: 48) }
                Button(action: openRecording) { Label("تسجيلاتي", systemImage: "folder").frame(maxWidth: .infinity, minHeight: 48) }
            }.buttonStyle(.bordered)
        }
    }
    private var studio: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("لوحة الاستوديو", systemImage: "dial.high.fill").font(.headline); Spacer(); presetMenu }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                dial(.input); dial(.recordGain); dial(.reverb); dial(.intensity)
            }
            Divider()
            Text("وحدات المعالجة").font(.caption.bold()).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(effects, id: \.self) { effect in effectSwitch(effect, compact: true) }
            }
            ThemeParameterControl(audio: audio, parameter: .output)
        }.modifier(ThemedPanel())
    }
    private func dial(_ parameter: Parameter) -> some View {
        VStack(spacing: 8) {
            RotaryControl(audio: audio, parameter: parameter, diameter: 84)
            Text(parameter.label).font(.subheadline.bold())
            Text(parameter.text(audio.value(parameter))).font(.title3.monospacedDigit()).foregroundStyle(era.accent(theme, palette))
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }
    private var simple: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("اختر طابع عزفك").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SoundSettings.names, id: \.self) { preset($0, icon: "leaf") }
            }
            VStack(spacing: 18) {
                ThemeParameterControl(audio: audio, parameter: .intensity)
                ThemeParameterControl(audio: audio, parameter: .input)
                ThemeParameterControl(audio: audio, parameter: .output)
            }.modifier(ThemedPanel())
            quickRecord
        }
    }
    private var stage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("لوحة المسرح").font(.title2.bold()); Spacer(); presetMenu }
            HStack(spacing: 8) {
                ForEach(SoundSettings.names, id: \.self) { name in
                    Button(name) { audio.choosePreset(name) }.font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 48)
                        .background(era.accent(theme, palette).opacity(audio.settings.preset == name ? 0.27 : 0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }.buttonStyle(.plain)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(effects, id: \.self) { effect in effectSwitch(effect, compact: false) }
            }
            if explanations { Text("الإضاءة تتبع مستوى الصوت المعالج للوحدات المفعّلة، وليست قياسًا منفصلًا لكل مؤثر.").font(.caption).foregroundStyle(.secondary) }
            Button { audio.tapTempo() } label: {
                HStack { Label("اضغط مرتين على إيقاعك", systemImage: "hand.tap"); Spacer(); Text(Parameter.delayTime.text(audio.value(.delayTime))).monospacedDigit() }.frame(minHeight: 52)
            }.buttonStyle(.bordered)
            ThemeParameterControl(audio: audio, parameter: .intensity)
            ThemeParameterControl(audio: audio, parameter: .input)
            ThemeParameterControl(audio: audio, parameter: .output)
            quickRecord
        }
    }
    private var presetMenu: some View {
        Menu { ForEach(SoundSettings.names, id: \.self) { name in Button(name) { audio.choosePreset(name) } } }
        label: { Label("الأصوات", systemImage: "music.note.list").frame(minHeight: 44) }
    }
    private func preset(_ name: String, icon: String) -> some View {
        let selected = audio.settings.preset == name
        return Button { audio.choosePreset(name) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: icon).font(.title2); Spacer(); if selected { Image(systemName: "checkmark.circle.fill") } }
                Text(name).font(.headline)
                if explanations { Text(SoundSettings.detail(name)).font(.caption).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, minHeight: 106, alignment: .leading).padding(16)
                .foregroundStyle(selected ? era.onAccent(theme) : era.ink(theme))
                .background(selected ? era.accent(theme, palette) : era.panel(theme, palette), in: RoundedRectangle(cornerRadius: era.radius(theme)))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func effectSwitch(_ effect: Effect, compact: Bool) -> some View {
        EffectPowerLight(audio: audio, effect: effect)
    }

    private var quickRecord: some View {
        Button {
            if audio.recording || audio.recordingPreparing { audio.finishRecording() }
            else { audio.beginRecording(video: false, front: false) }
        } label: {
            Label(audio.recording ? "إيقاف وحفظ • \(audio.recordingSeconds) ث" : (audio.recordingPreparing ? "إلغاء التجهيز" : "سجّل صوتك بالتأثيرات"), systemImage: audio.recording ? "stop.circle.fill" : "record.circle")
                .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
        }.buttonStyle(.borderedProminent).tint(.red).disabled(audio.recordingFinishing || audio.starting)
    }
    private var comparisonControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(audio.comparison == nil ? "احفظ A مؤقتًا" : "حدّث المقارنة") {
                    audio.captureComparison()
                }.frame(minHeight: 44)
                Spacer()
                Button(audio.comparingA ? "اسمع B" : "اسمع A") {
                    audio.swapComparison()
                }.buttonStyle(.bordered).disabled(audio.comparison == nil)
            }.font(.subheadline.bold())
            if explanations { Text("احفظ A، عدّل الصوت، ثم بدّل لسماع الفرق. المقارنة مؤقتة؛ احفظ صوتك للاحتفاظ به.").font(.caption).foregroundStyle(.secondary) }
        }.modifier(ThemedPanel())
    }
}
