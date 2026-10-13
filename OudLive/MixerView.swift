import SwiftUI

@MainActor
struct PerformanceMixer: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.oudEra) private var era
    var body: some View {
        HStack(spacing: 4) {
            strip("العود", value: Binding(get: { Double(audio.oudVolume) / 2 }, set: { audio.oudVolume = Float($0 * 2) }), percent: Int(audio.oudVolume * 100))
            strip("الإيقاع", value: Binding(get: { Double(audio.loopVolume) }, set: { audio.loopVolume = Float($0) }), percent: Int(audio.loopVolume * 100))
            strip("صدى مبلول", value: binding(.reverbWet), percent: Int(audio.value(.reverbWet) * 100))
            strip("صدى جاف", value: binding(.reverbDry), percent: Int(audio.value(.reverbDry) * 100))
        }.padding(8).background(era == .eighties ? Color(white: 0.72) : Color(red: 0.025, green: 0.06, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    private func binding(_ parameter: Parameter) -> Binding<Double> {
        Binding(get: { audio.value(parameter) }, set: {
            audio.setEnabled(.reverb, true)
            audio.set(parameter, $0)
        })
    }
    private func strip(_ title: String, value: Binding<Double>, percent: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform").font(.title2)
            Text(title).font(.caption.bold()).frame(height: 32)
            HStack(spacing: 6) {
                GeometryReader { geometry in
                    let travel = max(1, geometry.size.height - 44)
                    ZStack(alignment: .top) {
                        Capsule().fill(.black.opacity(0.75)).frame(width: 5).padding(.vertical, 22)
                        VStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { n in
                                Rectangle().fill(n == 2 ? Color.white : Color.gray).frame(height: n == 2 ? 3 : 1)
                            }
                        }.padding(6).frame(width: 44, height: 44)
                            .background(era == .eighties ? Color(white: 0.1) : Color(white: 0.55), in: RoundedRectangle(cornerRadius: 5))
                            .shadow(radius: 3, y: 2).offset(y: (1 - value.wrappedValue) * travel)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged {
                            value.wrappedValue = min(1, max(0, 1 - ($0.location.y - 22) / travel))
                        })
                }.frame(height: 180)
                    .accessibilityElement(children: .ignore).accessibilityLabel(title)
                    .accessibilityValue("\(percent) بالمئة")
                    .accessibilityAdjustableAction { value.wrappedValue = min(1, max(0, value.wrappedValue + ($0 == .increment ? 0.025 : -0.025))) }
                MixerLamps(level: value.wrappedValue).frame(width: 7, height: 180).accessibilityHidden(true)
            }.environment(\.layoutDirection, .leftToRight)
            Text("\(percent)٪").font(.body.monospacedDigit().bold())
            Text("المستوى").font(.caption2)
        }.padding(.vertical, 14).padding(.horizontal, 4).frame(maxWidth: .infinity)
            .foregroundStyle(era == .eighties ? Color.black : Color.white)
            .background {
                if era == .eighties { EraSurface() }
                else { RoundedRectangle(cornerRadius: 9).fill(Color.cyan.opacity(0.045)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.cyan.opacity(0.18))) }
            }
    }
}

@MainActor
struct MixerView: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.oudEra) private var era
    private var ink: Color { era == .eighties ? Color(white: 0.12) : .white }
    private let channels: [Parameter] = [.output, .input, .reverb, .reverbWet, .reverbDry, .noise, .compression, .low]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("مكسر الصوت", systemImage: "slider.vertical.3").font(.headline)
                Spacer()
                Text("٨ قنوات • اسحب للتعديل").font(.caption2)
            }.foregroundStyle(ink)
            GeometryReader { bounds in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(channels, id: \.rawValue) { parameter in
                            MixerStrip(audio: audio, parameter: parameter)
                                .frame(width: max(78, (bounds.size.width - 9) / 4))
                        }
                    }
                }
            }.frame(height: 332)
            Text("الصدى والتشويش: ٠–١٠٠٪. الجهير: ±٩ dB؛ الصفر محايد. اسحب القنوات أفقيًا إذا ضاقت الشاشة.").font(.caption2).foregroundStyle(ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            Text("المبلول: انعكاسات الصدى وذيله. الجاف: العود المباشر قبل الصدى. كلاهما مستقل ٠–١٠٠٪؛ خفض الجاف لا يقلل تغذية الصدى. إيقاف الصدى يعيد الصوت المباشر كاملًا.").font(.caption2).foregroundStyle(ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            Text("لمبات المايك والصوت تقيس الإشارة الحية؛ لمبات المؤثرات تبين مقدارها. الأحمر يعني مستوى مرتفعًا. الصوت يضبط السماعة؛ مستوى التسجيل مستقل في صفحة التسجيل.")
                .font(.caption2).foregroundStyle(ink.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(LinearGradient(colors: era == .eighties ? [Color(white: 0.96), Color(white: 0.76), Color(white: 0.91)] : [Color(red: 0.03, green: 0.08, blue: 0.10), Color(red: 0.02, green: 0.04, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.55)))
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityIdentifier("audio-mixer")
    }
}

@MainActor
private struct MixerStrip: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    @Environment(\.oudEra) private var era
    private var ink: Color { era == .eighties ? Color(white: 0.1) : .white }
    private var effect: Effect? {
        switch parameter { case .reverb, .reverbWet, .reverbDry: return .reverb; case .noise: return .noise; case .compression: return .compressor; case .low: return .eq; default: return nil }
    }
    private var title: String {
        switch parameter { case .output: return "الصوت"; case .input: return "التقاط\nالمايك"; case .reverb: return "الصدى"; case .reverbWet: return "صدى مبلول\nWet"; case .reverbDry: return "صدى جاف\nDry"; case .noise: return "خفض\nالتشويش"; case .low: return "توازن\nالجهير"; default: return "ضاغط\nالصوت" }
    }
    private var amount: Double { (audio.value(parameter) - parameter.range.lowerBound) / (parameter.range.upperBound - parameter.range.lowerBound) }
    private var enabled: Bool {
        if let effect { return audio.settings.enabled(effect) && audio.value(.bypass) < 0.5 }
        return parameter != .output || audio.value(.mute) < 0.5
    }
    private var lampLevel: Double {
        guard enabled else { return 0 }
        if parameter == .input || parameter == .output {
            guard audio.running else { return 0 }
            let peak = Double(parameter == .input ? audio.inputLevel : audio.outputLevel)
            return max(0, min(1, (20 * log10(max(peak, 0.001)) + 60) / 60))
        }
        if parameter == .low { return abs(audio.value(.low)) / 9 }
        return max(0, min(1, amount))
    }
    private func adjust(_ value: Double) {
        if let effect, !enabled { audio.setEnabled(effect, true) }
        if (parameter == .reverb || parameter == .reverbWet) && audio.value(.intensity) < 1 { audio.set(.intensity, 1) }
        audio.set(parameter, value)
    }
    var body: some View {
        VStack(spacing: 7) {
            Circle().fill(Color(white: 0.35)).frame(width: 4, height: 4).overlay(Rectangle().fill(.white.opacity(0.5)).frame(width: 3, height: 1)).accessibilityHidden(true)
            Text(title).font(.system(size: 12, weight: .bold)).multilineTextAlignment(.center).frame(height: 44)
            Text(parameter.text(audio.value(parameter))).font(.system(size: 11, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(ink).frame(height: 16)
            HStack(spacing: 4) {
                GeometryReader { track in
                    let travel = max(1, track.size.height - 38)
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            ForEach(0..<25, id: \.self) { n in
                                Rectangle().fill(Color(white: n % 4 == 0 ? 0.42 : 0.64)).frame(width: n % 4 == 0 ? 34 : 26, height: 1)
                                if n < 24 { Spacer(minLength: 0) }
                            }
                        }.padding(.vertical, 19)
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.08)).frame(width: 4).padding(.vertical, 18)
                        VStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { index in
                                Rectangle().fill(index == 2 ? Color(white: 0.86) : Color(white: 0.35)).frame(height: index == 2 ? 2 : 1)
                            }
                        }.padding(.horizontal, 4).frame(width: 36, height: 38)
                            .background(LinearGradient(colors: [Color(white: 0.21), .black, Color(white: 0.19)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(white: 0.36)))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                            .offset(y: (1 - max(0, min(1, amount))) * travel)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { point in
                            let fraction = 1 - max(0, min(1, (point.location.y - 19) / travel))
                            adjust(parameter.range.lowerBound + fraction * (parameter.range.upperBound - parameter.range.lowerBound))
                        })
                }.frame(height: 174)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
                    .accessibilityValue(parameter.text(audio.value(parameter)))
                    .accessibilityHint(parameter.explanation + " اسحب عموديًا لتغيير المستوى")
                    .accessibilityAdjustableAction { direction in
                        let step = (parameter.range.upperBound - parameter.range.lowerBound) / 40
                        adjust(audio.value(parameter) + (direction == .increment ? step : -step))
                    }.accessibilityIdentifier("mixer-fader-\(parameter.rawValue)")
                MixerLamps(level: lampLevel).frame(width: 7, height: 174).accessibilityHidden(true)
            }.environment(\.layoutDirection, .leftToRight)
            if parameter == .low {
                Button("محايد") { adjust(0) }.font(.system(size: 10, weight: .bold)).frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 5)).accessibilityLabel("إعادة توازن الجهير إلى صفر")
            } else if let effect {
                Button { audio.setEnabled(effect, !enabled) } label: {
                    Image(systemName: "power").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(enabled ? Color.green.opacity(0.85) : Color.gray)
                        .frame(maxWidth: .infinity, minHeight: 44).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).accessibilityLabel("\(enabled ? "إيقاف" : "تشغيل") \(title.replacingOccurrences(of: "\n", with: " "))")
            } else {
                Text("إشارة حية").font(.system(size: 9)).frame(height: 44)
            }
        }.foregroundStyle(ink).padding(.horizontal, 3).padding(.vertical, 6)
            .background(LinearGradient(colors: era == .eighties ? [.white.opacity(0.65), .gray.opacity(0.12), .white.opacity(0.5)] : [.cyan.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing))
            .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.15)).frame(width: 1) }
    }
}

private struct MixerLamps: View {
    let level: Double
    var body: some View {
        VStack(spacing: 3) {
            ForEach((0..<18).reversed(), id: \.self) { index in
                let color: Color = index >= 15 ? .red : (index >= 11 ? .yellow : .green)
                let lit = level > Double(index) / 18
                RoundedRectangle(cornerRadius: 1).fill(lit ? color : color.opacity(0.12))
                    .shadow(color: lit ? color.opacity(0.5) : .clear, radius: 2)
            }
        }.padding(2).background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 2))
    }
}

@MainActor
struct LiveLatencyControl: View {
    @ObservedObject var audio: AudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("استجابة حية • Live Low Latency", isOn: Binding(get: { audio.value(.live) > 0.5 }, set: { audio.setLiveLatency($0) }))
                .font(.subheadline.bold()).disabled(audio.recording || audio.recordingPreparing || audio.recordingFinishing || audio.starting)
            Text("مسار أصلي فوري بلا انتظار مسبق؛ يوقف الرجع ويضيق رنين المكان. تأخير البلوتوث تحدده السماعة والنظام.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EffectsPresetDrawer<Cover: View, Back: View>: View {
    @Binding var revealed: Bool
    let cover: Cover
    let back: Back
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func setOpen(_ value: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { revealed = value }
    }
    private var handle: some View {
        Button { setOpen(!revealed) } label: {
            VStack(spacing: 7) {
                Capsule().fill(.white.opacity(0.4)).frame(width: 48, height: 4)
                Label(revealed ? "إرجاع لوحة المؤثرات" : "ارفع المؤثرات لكشف الضبط السريع", systemImage: revealed ? "chevron.down" : "chevron.up").font(.caption.bold())
            }.frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityHint("اضغط أو اسحب المقبض عموديًا")
            .simultaneousGesture(DragGesture(minimumDistance: 15).onEnded { value in
                if value.translation.height < -35 { setOpen(true) }
                else if value.translation.height > 35 { setOpen(false) }
            })
    }
    var body: some View {
        ZStack(alignment: .top) {
            if revealed {
                VStack(spacing: 0) { handle; back.padding(12) }.transition(.opacity)
            } else {
                VStack(spacing: 0) { cover.padding(10); handle }.transition(.move(edge: .top).combined(with: .opacity))
            }
        }.frame(maxWidth: .infinity).background(Color(red: 0.045, green: 0.073, blue: 0.092))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.cyan.opacity(0.22)))
    }
}
