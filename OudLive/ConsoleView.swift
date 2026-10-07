import SwiftUI
import AVKit

private enum ConsoleSheet: Identifiable {
    case library, settings, memories, effect(Effect)
    var id: String {
        switch self { case .library: return "library"; case .settings: return "settings"; case .memories: return "memories"; case .effect(let effect): return effect.rawValue }
    }
}

@MainActor
struct ConsoleView: View {
    @ObservedObject var audio: AudioModel
    @State private var video = true
    @State private var presetsRevealed = false
    @State private var sheet: ConsoleSheet?
    @AppStorage("OudLive.console") private var console = true
    private let blue = Color(red: 0.15, green: 0.61, blue: 1)
    private let surface = Color(red: 0.045, green: 0.073, blue: 0.092)
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing }
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: wide ? 12 : 16) {
                    header(wide: wide)
                    if !wide { recordBar }
                    listeningPanel(wide: wide)
                    LiveLatencyControl(audio: audio)
                    MixerView(audio: audio).id("console-mixer")
                    if wide {
                        HStack(alignment: .top, spacing: 12) {
                            inputPanel(compact: false).frame(width: 108)
                            hero(height: 218).frame(maxWidth: .infinity)
                            cameraPanel(height: 218).frame(width: max(240, geometry.size.width * 0.32))
                        }.environment(\.layoutDirection, .leftToRight)
                    } else {
                        hero(height: 228).id("console-hero")
                        inputPanel(compact: true)
                        cameraPanel(height: 212)
                    }
                    EffectsPresetDrawer(revealed: $presetsRevealed,
                        cover: effectRack(wide: wide), back: QuickPresetGrid(audio: audio))
                        .id("console-rack")
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("خاناتي المحفوظة", systemImage: "square.grid.2x2").font(.headline)
                            Spacer()
                            Button("فتح الخانات") { sheet = .memories }.frame(minHeight: 44)
                        }
                        QuickSoundBank(audio: audio)
                    }.modifier(ConsolePanel())
                    Text(audio.message).font(.caption).foregroundStyle(Color(white: 0.72)).frame(maxWidth: .infinity, alignment: .leading)
                    CopyrightFooter()
                }.padding(wide ? 12 : 16).frame(maxWidth: 1500).frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.015, green: 0.03, blue: 0.038))
            .onChange(of: wide) { _ in
                if audio.cameraSession != nil && !busy && !audio.cameraPreviewPreparing { audio.openCameraPreview(front: audio.frontCamera) }
            }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--console-mixer") {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    scroll.scrollTo("console-mixer", anchor: .top)
                }
                if ProcessInfo.processInfo.arguments.contains("--console-hero") {
                    audio.chooseRecordingPreset(RecordingPreset.all[7])
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    scroll.scrollTo("console-hero", anchor: .top)
                }
                if ProcessInfo.processInfo.arguments.contains("--console-presets") {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    presetsRevealed = true
                    scroll.scrollTo("console-rack", anchor: .top)
                }
                if ProcessInfo.processInfo.arguments.contains("--console-rack") {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    scroll.scrollTo("console-rack", anchor: .top)
                }
                #endif
            }
            }
        }
        .preferredColorScheme(.dark).foregroundStyle(.white).tint(blue)
        .environment(\.oudTheme, .studio).environment(\.oudEra, .modern).environment(\.oudPalette, .ice)
        .sheet(item: $sheet) { panel($0) }
        .alert("الحفظ في الصور", isPresented: Binding(get: { audio.photosNotice != nil }, set: { if !$0 { audio.photosNotice = nil } })) {
            Button("تم") { audio.photosNotice = nil }
        } message: { Text(audio.photosNotice ?? "") }
        .onDisappear { audio.closeCameraPreview() }
        .task {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--console-presets") { audio.chooseRecordingPreset(RecordingPreset.all[8]) }
            do {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: arguments.contains("--console-landscape") ? .landscapeRight : .portrait))
                }
            }
            if arguments.contains("--console-effects") { sheet = .effect(.reverb) }
            if arguments.contains("--console-memories") { sheet = .memories }
            if arguments.contains("--console-library") { sheet = .library }
            #endif
        }
    }
    private var microphoneChoice: some View {
        Picker("مصدر الميكروفون", selection: $audio.usesBluetoothMic) {
            Text("مايك الآيفون / USB").tag(false)
            Text("مايك سماعة البلوتوث").tag(true)
        }.pickerStyle(.segmented).disabled(busy || audio.starting)
    }
    private var listeningButton: some View {
        Button {
            if !audio.running && !audio.starting { audio.set(.mute, 0) }
            audio.toggle()
        } label: {
            Label(audio.starting ? "إلغاء التوصيل" : (audio.running ? "إيقاف الاستماع" : "استماع مباشر"), systemImage: audio.running ? "stop.fill" : "play.fill")
                .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.borderedProminent).disabled(busy)
    }
    private func listeningPanel(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if wide {
                HStack(spacing: 12) {
                    Label("دون تسجيل", systemImage: "ear.badge.waveform").font(.caption.bold())
                    microphoneChoice.frame(maxWidth: 330)
                    listeningButton
                    AudioOutputPicker().frame(width: 44, height: 44)
                }
            } else {
            HStack {
                Label("استماع مباشر • دون تسجيل", systemImage: "ear.badge.waveform").font(.subheadline.bold())
                Spacer()
                AudioOutputPicker().frame(width: 44, height: 44)
            }
            microphoneChoice
            listeningButton
            }
            if audio.running {
                Text("المايك: \(audio.inputRoute) • الخروج: \(audio.route)").font(.caption2).foregroundStyle(Color(white: 0.8))
            }
            if !wide { Text(audio.usesBluetoothMic ? "وصّل UGREEN من إعدادات البلوتوث أولًا. مايك السماعة يعمل بوضع المكالمات وقد يقل وضوح الموسيقى؛ يوجد تأخير لاسلكي." : "يمكنك سماع المؤثرات في السماعة قبل التسجيل. اختر السماعة من زر المخرج؛ مايك الآيفون أو USB يحافظ على تفاصيل العود.")
                .font(.caption2).foregroundStyle(Color(white: 0.7))
            }
        }.modifier(ConsolePanel(padding: 12))
    }
    private func header(wide: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image("OudHero").resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("معالج العود").font(wide ? .title3.bold() : .title2.bold())
                    Text("صوت احترافي مباشر").font(.caption2).foregroundStyle(Color(white: 0.72))
                }
            }.environment(\.layoutDirection, .rightToLeft)
            Spacer(minLength: 4)
            if wide { recordBar.frame(maxWidth: 270); Spacer(minLength: 4) }
            Button { sheet = .library } label: { Image(systemName: "folder").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("الملفات والتسجيلات")
            Button { sheet = .settings } label: { Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("الإعدادات")
        }.foregroundStyle(Color(white: 0.92)).padding(10).background(surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.09)))
            .environment(\.layoutDirection, .leftToRight)
    }
    private var recordBar: some View {
        HStack(spacing: 0) {
            Button(action: record) {
                Label(audio.recording ? "إيقاف وحفظ" : (audio.recordingPreparing ? "إلغاء التجهيز" : (video ? "تسجيل فيديو" : "تسجيل صوت")), systemImage: audio.recording ? "stop.fill" : (video ? "video.fill" : "mic.fill"))
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }.accessibilityIdentifier("console-record")
            Divider().frame(height: 28).overlay(.white.opacity(0.25))
            Menu {
                Picker("نوع التسجيل", selection: $video) {
                    Label("تسجيل فيديو", systemImage: "video.fill").tag(true)
                    Label("تسجيل صوت فقط", systemImage: "mic.fill").tag(false)
                }
            } label: { Image(systemName: "chevron.down").frame(width: 48, height: 50) }.disabled(busy).accessibilityLabel("اختيار صوت أو فيديو")
        }.foregroundStyle(.white).background(Color(red: 0.83, green: 0.045, blue: 0.045), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.red.opacity(0.7)))
            .buttonStyle(.plain).disabled(audio.recordingFinishing || audio.starting || audio.cameraPreviewPreparing || audio.savingToPhotos != nil)
    }
    private func record() {
        if audio.recording || audio.recordingPreparing { audio.finishRecording() }
        else { audio.beginRecording(video: video, front: audio.cameraSession == nil ? true : audio.frontCamera) }
    }
    private func hero(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            GeometryReader { bounds in
                Image(SoundSettings.imageName(audio.settings.preset)).resizable().scaledToFill().frame(width: bounds.size.width, height: height).clipped()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(audio.settings.preset).font(.headline).padding(7).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                Spacer()
                Text(SoundSettings.detail(audio.settings.preset)).font(.caption2).padding(7).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
            }.padding(12).environment(\.layoutDirection, .rightToLeft)
        }.frame(height: height).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.20)))
    }
    private func inputPanel(compact: Bool) -> some View {
        Group {
            if compact {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        microphoneMenu
                        SignalLED(level: audio.inputLevel, tint: .green)
                        Text(audio.inputRoute.isEmpty ? "الميكروفون جاهز عند البدء" : audio.inputRoute).font(.caption2).foregroundStyle(Color(white: 0.7)).lineLimit(1)
                    }
                    ConsoleDial(audio: audio, parameter: .input, palette: .sapphire, diameter: 52)
                    Button { audio.toggle() } label: { Image(systemName: audio.running ? "stop.circle.fill" : "play.circle.fill").font(.title).frame(width: 44, height: 44) }.accessibilityLabel(audio.running ? "إيقاف المعالجة" : "تشغيل المعالجة")
                }
            } else {
                VStack(spacing: 8) {
                    microphoneMenu
                    HStack { VerticalAudioMeter(level: audio.inputLevel).frame(width: 18); Text("0\n−12\n−24\n−60").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary) }.frame(height: 64)
                    ConsoleDial(audio: audio, parameter: .input, palette: .sapphire, diameter: 52)
                    Button(audio.running ? "إيقاف" : "مراقبة مباشرة") { audio.toggle() }.font(.caption2.bold()).frame(minHeight: 36)
                }
            }
        }.modifier(ConsolePanel(padding: 10)).environment(\.layoutDirection, .rightToLeft)
    }
    private var microphoneMenu: some View {
        Menu {
            Picker("الميكروفون", selection: $audio.selectedInput) {
                Text(audio.usesBluetoothMic ? "تلقائي • مايك سماعة البلوتوث" : "تلقائي • مايك الآيفون أو USB").tag("")
                ForEach(audio.inputs.filter { audio.usesBluetoothMic ? $0.portType == .bluetoothHFP : $0.portType != .bluetoothHFP }, id: \.uid) { Text($0.portName).tag($0.uid) }
            }
        } label: { Label("المدخل", systemImage: "mic").font(.caption.bold()).frame(minHeight: 32) }
    }
    private func cameraPanel(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(audio.recording ? String(format: "%02d:%02d", audio.recordingSeconds / 60, audio.recordingSeconds % 60) : "المعاينة", systemImage: audio.recording ? "record.circle.fill" : "video")
                    .foregroundStyle(audio.recording ? .red : .white).monospacedDigit()
                Spacer()
                Button { audio.openCameraPreview(front: !audio.frontCamera) } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").frame(width: 40, height: 36) }.disabled(busy || audio.cameraPreviewPreparing).accessibilityLabel("تبديل الكاميرا")
                if audio.cameraSession != nil || audio.cameraPreviewPreparing {
                    Button { audio.closeCameraPreview() } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }.disabled(busy).accessibilityLabel("إغلاق معاينة الكاميرا")
                }
            }.font(.caption.bold()).padding(.horizontal, 9)
            ZStack {
                Color.black
                if let session = audio.cameraSession {
                    CameraPreview(session: session, orientation: audio.cameraOrientation)
                } else if audio.cameraPreviewPreparing { ProgressView("جارٍ فتح الكاميرا…") }
                else {
                    Button { audio.openCameraPreview() } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "video.badge.plus").font(.system(size: 30))
                            Text("فتح الكاميرا الأمامية").font(.caption.bold())
                            Text("أوسع مشهد متاح • دون تسجيل").font(.caption2).foregroundStyle(Color(white: 0.65))
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.buttonStyle(.plain).disabled(busy)
                }
            }
            HStack {
                Button { audio.set(.mute, audio.value(.mute) > 0.5 ? 0 : 1) } label: { Image(systemName: audio.value(.mute) > 0.5 ? "speaker.slash" : "speaker.wave.2").frame(width: 44, height: 44) }.accessibilityLabel("كتم أو تشغيل المراقبة")
                Spacer()
                Button(action: record) { Image(systemName: audio.recording ? "stop.fill" : "record.circle.fill").font(.title2).frame(width: 54, height: 44).foregroundStyle(.red) }.disabled(audio.recordingFinishing || audio.starting || audio.cameraPreviewPreparing || audio.savingToPhotos != nil).accessibilityLabel(audio.recording ? "إيقاف وحفظ التسجيل" : "بدء التسجيل")
                Spacer()
                Button { audio.takePhoto() } label: { Image(systemName: "camera").frame(width: 44, height: 44) }.disabled(audio.cameraSession == nil || audio.savingSnapshot).accessibilityLabel("حفظ لقطة في الصور")
            }.padding(.horizontal, 10)
        }.frame(height: height).background(surface).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.45)))
            .environment(\.layoutDirection, .rightToLeft)
    }
    private func effectRack(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("المؤثرات").font(.headline)
                Spacer()
                Toggle("مقارنة بالأصل", isOn: Binding(get: { audio.value(.bypass) > 0.5 }, set: { audio.set(.bypass, $0 ? 1 : 0) })).font(.caption).fixedSize()
            }
            if wide {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        equalizer.frame(width: 232)
                        effectCard(.reverb, parameter: .reverb, palette: .violet).frame(width: 145)
                        effectCard(.delay, parameter: .delay, palette: .emerald).frame(width: 145)
                        effectCard(.space, parameter: .width, palette: .sapphire).frame(width: 145)
                        effectCard(.compressor, parameter: .compression, palette: .copper).frame(width: 145)
                        effectCard(.noise, parameter: .noise, palette: .rose).frame(width: 145)
                        outputPanel.frame(width: 155)
                    }.environment(\.layoutDirection, .leftToRight)
                }
            } else {
                equalizer
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    effectCard(.reverb, parameter: .reverb, palette: .violet)
                    effectCard(.delay, parameter: .delay, palette: .emerald)
                    effectCard(.space, parameter: .width, palette: .sapphire)
                    effectCard(.compressor, parameter: .compression, palette: .copper)
                    effectCard(.noise, parameter: .noise, palette: .rose)
                    outputPanel
                }
            }
        }
    }
    private var equalizer: some View {
        VStack(spacing: 12) {
            effectTitle(.eq, title: "موازن الصوت", color: blue)
            HStack {
                ForEach([Parameter.low, .mid, .high], id: \.rawValue) { p in
                    ConsoleDial(audio: audio, parameter: p, palette: .sapphire, diameter: 54).frame(maxWidth: .infinity)
                }
            }
            Button("تفاصيل النبرة") { sheet = .effect(.eq) }.font(.caption).frame(maxWidth: .infinity, minHeight: 36).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }.modifier(ConsolePanel()).environment(\.layoutDirection, .rightToLeft)
    }
    private func effectCard(_ effect: Effect, parameter: Parameter, palette: AppPalette) -> some View {
        VStack(spacing: 10) {
            effectTitle(effect, title: effectLabel(effect), color: palette.accent(.studio))
            ConsoleDial(audio: audio, parameter: parameter, palette: palette, diameter: 70)
            Button { sheet = .effect(effect) } label: {
                HStack { Text(effect.summary).lineLimit(1); Spacer(minLength: 2); Image(systemName: "chevron.down") }.font(.caption2).padding(.horizontal, 8).frame(minHeight: 36).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }.accessibilityLabel("تفاصيل " + effectLabel(effect))
        }.modifier(ConsolePanel(padding: 12)).environment(\.layoutDirection, .rightToLeft)
    }
    private func effectTitle(_ effect: Effect, title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: effect.symbol).foregroundStyle(color)
            Text(title).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 1)
            Button { audio.setEnabled(effect, !audio.settings.enabled(effect)) } label: {
                Capsule().fill(audio.settings.enabled(effect) ? blue : Color.gray.opacity(0.4)).frame(width: 32, height: 19)
                    .overlay(alignment: audio.settings.enabled(effect) ? .trailing : .leading) { Circle().fill(.white).frame(width: 15, height: 15).padding(2) }.frame(width: 36, height: 44)
            }.accessibilityLabel("تشغيل أو إيقاف " + title).accessibilityValue(audio.settings.enabled(effect) ? "مفعّل" : "متوقف")
        }
    }
    private var outputPanel: some View {
        VStack(spacing: 10) {
            HStack { Text("المخرج").font(.caption.bold()); Spacer(); AudioOutputPicker().frame(width: 36, height: 36) }
            ConsoleDial(audio: audio, parameter: .output, palette: .sapphire, diameter: 70)
            SignalLED(level: audio.outputLevel, tint: .green).frame(height: 10)
            Text(audio.bluetoothOutput ? "سماعة بلوتوث" : "سماعات المراقبة").font(.caption2).frame(minHeight: 26)
        }.modifier(ConsolePanel(padding: 12)).environment(\.layoutDirection, .rightToLeft)
    }
    private func effectLabel(_ effect: Effect) -> String {
        switch effect { case .reverb: return "الريفيرب"; case .delay: return "الديلي"; case .space: return "المكان"; case .compressor: return "الكمبريسر"; case .noise: return "الهدوء"; case .eq: return "موازن الصوت" }
    }
    private func panel(_ item: ConsoleSheet) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch item {
                    case .library: RecordingView(audio: audio, libraryOnly: true)
                    case .memories: QuickSoundBank(audio: audio)
                    case .settings: settingsPanel
                    case .effect(let effect):
                        Toggle("تفعيل " + effectLabel(effect), isOn: Binding(get: { audio.settings.enabled(effect) }, set: { audio.setEnabled(effect, $0) }))
                        ForEach(effect.parameters.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { parameter in ThemeParameterControl(audio: audio, parameter: parameter) }
                        if effect == .delay { Button("اضغط مرتين على إيقاعك") { audio.tapTempo() }.buttonStyle(.bordered) }
                    }
                }.padding(20)
            }.background(surface)
                .navigationTitle(sheetTitle(item)).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("تم") { sheet = nil } }
                .safeAreaInset(edge: .bottom) { CopyrightFooter().background(surface) }
        }.preferredColorScheme(.dark).environment(\.layoutDirection, .rightToLeft)
            .environment(\.oudTheme, .studio).environment(\.oudEra, .modern).environment(\.oudPalette, .ice)
    }
    private func sheetTitle(_ item: ConsoleSheet) -> String {
        switch item { case .library: return "الملفات والتسجيلات"; case .settings: return "الإعدادات"; case .memories: return "خانات أصواتي"; case .effect(let e): return effectLabel(e) }
    }
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("مصدر الأداء", selection: Binding(get: { audio.mode }, set: { audio.chooseMode($0) })) { ForEach(SoundMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            ThemeParameterControl(audio: audio, parameter: .recordGain)
            ThemeParameterControl(audio: audio, parameter: .intensity)
            Toggle("استقرار أعلى عند التقطيع", isOn: $audio.stableBuffer)
            Text("تغيير الميكروفون أو الاستقرار يوقف المعالجة. حدّد التوصيل قبل التسجيل.").font(.caption).foregroundStyle(Color(white: 0.72))
            microphoneMenu
            Text(audio.route).font(.caption)
            Text("اختر مايك الآيفون أو مايك سماعة البلوتوث من لوحة الاستماع. البلوتوث له تأخير. الفيديو يحافظ على اتجاه الكاميرا عند فتحها؛ أوقف التسجيل قبل التبديل. التسجيل والحفظ في الصور لا يحتاجان سماعة.").font(.caption).foregroundStyle(Color(white: 0.72))
            Button("فتح الواجهات والثيمات السابقة") { sheet = nil; audio.closeCameraPreview(); console = false }.buttonStyle(.bordered)
            if !audio.namedSounds.isEmpty {
                Text("أصواتي السابقة").font(.headline)
                ForEach(audio.namedSounds) { sound in Button(sound.name) { audio.loadSound(sound) }.frame(minHeight: 44) }
            }
            Text("ياسر الغامدي 2026").font(.caption)
        }
    }
}

private struct ConsolePanel: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content.padding(padding).frame(maxWidth: .infinity).background(Color(red: 0.045, green: 0.073, blue: 0.092), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.11)))
            .shadow(color: .black.opacity(0.5), radius: 5, y: 4)
    }
}
@MainActor
private struct ConsoleDial: View {
    @ObservedObject var audio: AudioModel
    let parameter: Parameter
    let palette: AppPalette
    var diameter: CGFloat = 64
    var body: some View {
        VStack(spacing: 5) {
            RotaryControl(audio: audio, parameter: parameter, diameter: diameter).environment(\.oudPalette, palette)
            Text(parameter.text(audio.value(parameter))).font(.caption.monospacedDigit()).foregroundStyle(.white)
            Text(parameter.label.components(separatedBy: " • ").first ?? parameter.label).font(.system(size: 10)).foregroundStyle(Color(white: 0.7)).lineLimit(1)
        }
    }
}
private struct VerticalAudioMeter: View {
    let level: Float
    private var fraction: Float { max(0, min(1, (20 * log10(max(level, 0.00001)) + 60) / 60)) }
    var body: some View {
        VStack(spacing: 2) {
            ForEach((0..<18).reversed(), id: \.self) { index in
                Rectangle().fill(Float(index) / 18 < fraction ? (index > 15 ? Color.yellow : .green) : Color.green.opacity(0.12))
            }
        }.padding(3).background(.black, in: RoundedRectangle(cornerRadius: 3)).accessibilityHidden(true)
    }
}
