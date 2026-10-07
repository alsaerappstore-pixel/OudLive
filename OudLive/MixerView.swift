import SwiftUI

@MainActor
struct MixerView: View {
    @ObservedObject var audio: AudioModel
    private let channels: [Parameter] = [.output, .input, .reverb, .noise, .compression]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("مكسر الصوت", systemImage: "slider.vertical.3").font(.headline)
                Spacer()
                Text("اسحب لأعلى أو لأسفل").font(.caption2)
            }.foregroundStyle(Color(white: 0.12))
            GeometryReader { bounds in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(channels, id: \.rawValue) { parameter in
                            MixerStrip(audio: audio, parameter: parameter)
                                .frame(width: max(62, (bounds.size.width - 12) / 5))
                        }
                    }
                }
            }.frame(height: 304)
            Text("لمبات المايك والصوت تقيس الإشارة الحية؛ لمبات المؤثرات تبين مقدارها. الأحمر يعني مستوى مرتفعًا. الصوت يضبط السماعة؛ مستوى التسجيل مستقل في صفحة التسجيل.")
                .font(.caption2).foregroundStyle(Color(white: 0.24)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.76), Color(white: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.55)))
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityIdentifier("audio-mixer")
    }
}

@MainActor
private struct MixerStrip: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    private var effect: Effect? {
        switch parameter { case .reverb: return .reverb; case .noise: return .noise; case .compression: return .compressor; default: return nil }
    }
    private var title: String {
        switch parameter { case .output: return "الصوت"; case .input: return "التقاط\nالمايك"; case .reverb: return "الصدى"; case .noise: return "خفض\nالتشويش"; default: return "ضاغط\nالصوت" }
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
        return max(0, min(1, amount))
    }
    private func adjust(_ value: Double) {
        if let effect, !enabled { audio.setEnabled(effect, true) }
        audio.set(parameter, value)
    }
    var body: some View {
        VStack(spacing: 7) {
            Circle().fill(Color(white: 0.35)).frame(width: 4, height: 4).overlay(Rectangle().fill(.white.opacity(0.5)).frame(width: 3, height: 1)).accessibilityHidden(true)
            Text(title).font(.system(size: 12, weight: .bold)).multilineTextAlignment(.center).frame(height: 32)
            Text(parameter.text(audio.value(parameter))).font(.system(size: 11, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(Color(white: 0.12)).frame(height: 16)
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
                    .accessibilityHint("اسحب عموديًا لتغيير المستوى")
                    .accessibilityAdjustableAction { direction in
                        let step = (parameter.range.upperBound - parameter.range.lowerBound) / 40
                        adjust(audio.value(parameter) + (direction == .increment ? step : -step))
                    }.accessibilityIdentifier("mixer-fader-\(parameter.rawValue)")
                MixerLamps(level: lampLevel).frame(width: 7, height: 174).accessibilityHidden(true)
            }.environment(\.layoutDirection, .leftToRight)
            if let effect {
                Button { audio.setEnabled(effect, !enabled) } label: {
                    Image(systemName: "power").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(enabled ? Color.green.opacity(0.85) : Color.gray)
                        .frame(maxWidth: .infinity, minHeight: 32).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).accessibilityLabel("\(enabled ? "إيقاف" : "تشغيل") \(title.replacingOccurrences(of: "\n", with: " "))")
            } else {
                Text("إشارة حية").font(.system(size: 9)).frame(height: 32)
            }
        }.foregroundStyle(Color(white: 0.1)).padding(.horizontal, 3).padding(.vertical, 6)
            .background(LinearGradient(colors: [.white.opacity(0.65), .gray.opacity(0.12), .white.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
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
