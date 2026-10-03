import SwiftUI
import AVKit

@MainActor
struct ContentView: View {
    @ObservedObject var audio: AudioModel
    @State private var page = 0
    @State private var showHelp = false
    @State private var showSave = false
    @State private var soundName = ""
    @AppStorage("OudLive.theme") private var themeRaw = AppTheme.studio.rawValue
    @AppStorage("OudLive.reactiveLights") private var reactiveLights = true
    @AppStorage("OudLive.showExplanations") private var explanations = true
    @AppStorage("OudLive.palette") private var paletteRaw = AppPalette.original.rawValue
    private var palette: AppPalette { AppPalette(rawValue: paletteRaw) ?? .original }
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .studio }
    private var gold: Color { palette.accent(theme) }
    private var mint: Color { theme == .simple || palette != .original ? palette.accent(theme) : Color(red: 0.2, green: 0.85, blue: 0.72) }
    private var surface: Color { palette.panel(theme) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                monitor
                Picker("صفحة التحكم", selection: $page) {
                    Text("العزف").tag(0); Text("المؤثرات").tag(1); Text("التوصيل").tag(2); Text("التسجيل").tag(3)
                }.pickerStyle(.segmented)
                if page == 0 { performance }
                if page == 1 { effects }
                if page == 2 { connection }
                if page == 3 { RecordingView(audio: audio) }
                Text("ياسر الغامدي 2026")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 740).frame(maxWidth: .infinity)
        }
        .background(palette.background(theme))
        .foregroundStyle(theme.ink)
        .preferredColorScheme(theme == .simple ? .light : .dark)
        .tint(gold)
        .safeAreaInset(edge: .bottom) { transport }
        .sheet(isPresented: $showHelp) { help }
        .alert("حفظ صوت جديد", isPresented: $showSave) {
            TextField("اسم الصوت", text: $soundName)
            Button("حفظ") { audio.saveSound(soundName); soundName = "" }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("يحفظ المؤثرات ومفاتيح تشغيلها لوضع العود أو الصوت البشري.") }
        .environment(\.oudTheme, theme)
        .environment(\.oudPalette, palette)
        .onAppear {
            #if DEBUG
            for option in AppPalette.allCases where ProcessInfo.processInfo.arguments.contains("--palette-" + option.rawValue) { paletteRaw = option.rawValue }
            for option in AppTheme.allCases where ProcessInfo.processInfo.arguments.contains("--theme-" + option.rawValue) { themeRaw = option.rawValue }
            if ProcessInfo.processInfo.arguments.contains("--preview-effects") { page = 1 }
            if ProcessInfo.processInfo.arguments.contains("--preview-connection") { page = 2 }
            if ProcessInfo.processInfo.arguments.contains("--preview-recording") { page = 3 }
            #endif
        }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("عود لايف").font(.largeTitle.bold()).foregroundStyle(gold)
            }
            Spacer()
            Menu {
                Picker("شكل التطبيق", selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { option in Label(option.title, systemImage: option.icon).tag(option.rawValue) }
                }
                Picker("ألوان التطبيق", selection: $paletteRaw) {
                    ForEach(AppPalette.allCases) { option in Text(option.title).tag(option.rawValue) }
                }
                Toggle("إضاءة تتفاعل مع الصوت", isOn: $reactiveLights)
                Toggle("شرح الخيارات", isOn: $explanations)
            } label: { Label(theme.title, systemImage: theme.icon).font(.subheadline.bold()).frame(minHeight: 44) }
            .accessibilityLabel("شكل التطبيق: " + theme.title)
            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle").font(.title2).frame(width: 44, height: 44)
            }.accessibilityLabel("دليل العزف")
        }
    }
    private var monitor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(audio.running ? "على الهواء" : "جاهز للعزف", systemImage: audio.running ? "waveform" : "waveform.circle")
                    .font(.headline).foregroundStyle(audio.running ? mint : gold)
                Spacer()
                Text(audio.bluetoothOutput ? "BLUETOOTH" : "AUDIO").font(.caption.bold()).foregroundStyle(.secondary)
                AudioOutputPicker().frame(width: 44, height: 44).accessibilityLabel("اختيار السماعة")
            }
            meter("التقاط", value: audio.inputLevel)
            if theme != .simple && page != 0 {
                meter("تسجيل", value: audio.recordingLevel)
                meter("سماعة", value: audio.outputLevel)
            }
            if audio.recording { Label("يسجّل • \(audio.recordingSeconds) ث", systemImage: "record.circle.fill").foregroundStyle(.red).font(.caption.bold()) }
            if audio.running && !audio.monitoring { Text("التسجيل متاح بدون سماعة • الاستماع المباشر متوقف").font(.caption).foregroundStyle(gold) }
            if audio.limitingDB > 2 {
                Label("حماية القمم تعمل • خفّض الالتقاط أو تعويض المستوى إذا أصبح الصوت مضغوطًا.", systemImage: "waveform.badge.minus")
                    .font(.caption).foregroundStyle(gold)
            }
            if page != 0 || audio.running || audio.starting || audio.message != "يمكنك التسجيل دون سماعة، أو توصيل سماعة للاستماع المباشر." {
                Text(audio.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.card()
    }
    private var performance: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.settings.preset).font(.title2.bold())
                    Text(SoundSettings.detail(audio.settings.preset)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("مصدر الأداء", selection: Binding(get: { audio.mode }, set: { audio.chooseMode($0) })) {
                        ForEach(SoundMode.allCases) { Text($0.title).tag($0) }
                    }
                } label: { Text(audio.mode.title).font(.caption.bold()).frame(minHeight: 44) }
                Button { showSave = true } label: { Label("حفظ", systemImage: "bookmark") }.buttonStyle(.bordered)
                if audio.savedFavorite {
                    Button { audio.loadFavorite() } label: { Image(systemName: "bookmark.fill") }.buttonStyle(.bordered).accessibilityLabel("استعادة مفضلتي")
                }
            }
            if !audio.namedSounds.isEmpty {
                Menu {
                    ForEach(audio.namedSounds) { sound in
                        Button("\(sound.name) • \(sound.mode.title)") { audio.loadSound(sound) }
                    }
                    Menu("حذف صوت محفوظ") {
                        ForEach(audio.namedSounds) { sound in
                            Button(sound.name, role: .destructive) { audio.deleteSound(sound.id) }
                        }
                    }
                } label: { Label("أصواتي المحفوظة", systemImage: "bookmark.fill").frame(minHeight: 44) }
            }
            PerformanceModes(audio: audio, openEffects: { page = 1 }, openRecording: { page = 3 })
        }
    }
    private var effects: some View {
        VStack(spacing: 18) {
            VStack(spacing: 18) {
                effectHeading("صدى المكان", icon: "building.columns", effect: .reverb)
                Text("اترك فراغًا قبل الصدى لتبقى ضربة الريشة واضحة، ثم أطِل الذيل للمساحة الكبيرة.").font(.caption).foregroundStyle(.secondary)
                control(.reverb); control(.decay); control(.predelay); control(.tone)
            }.card()
            VStack(spacing: 18) {
                effectHeading("صدى الإيقاع", icon: "repeat", effect: .delay)
                control(.delay); control(.delayTime); control(.feedback)
                Button { audio.tapTempo() } label: {
                    Label("اضغط مرتين على إيقاعك", systemImage: "hand.tap").frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered)
            }.card()
            VStack(spacing: 18) {
                effectHeading("الحركة", icon: "waveform.path", effect: .motion)
                Picker("طابع الحركة", selection: Binding(get: { audio.value(.flanger) > 0.5 ? 1 : 0 }, set: { audio.set(.flanger, Double($0)) })) {
                    Text("Chorus • امتلاء").tag(0); Text("Flanger • تموّج").tag(1)
                }.pickerStyle(.segmented)
                Text("الكورس يضيف طبقات متقاربة للامتلاء؛ الفلانجر يعطي تموّجًا بنبرة معدنية. الطابعان بديلان في هذه الوحدة.").font(.caption).foregroundStyle(.secondary)
                control(.modulation); control(.modRate)
            }.card()
            VStack(spacing: 18) {
                effectHeading("مضاعفة الصوت • Doubler", icon: "square.on.square", effect: .doubler)
                control(.doubler)
            }.card()
            VStack(spacing: 18) {
                effectHeading("موازنة النغمة • EQ", icon: "slider.horizontal.3", effect: .eq)
                Text("يضبط عمق النغمة وحضورها ولمعانها دون تغيير النوتة.").font(.caption).foregroundStyle(.secondary)
                control(.low); control(.mid); control(.high)
            }.card()
            VStack(spacing: 18) {
                effectHeading("توازن القوة • Compressor", icon: "waveform", effect: .compressor)
                control(.compression); control(.makeup)
                Text("التعويض يرفع مستوى الصوت بعد الضغط. إذا عملت حماية القمم باستمرار، خفّضه.").font(.caption).foregroundStyle(.secondary)
            }.card()
            if audio.mode == .voice {
                Text("إعدادات الصوت البشري مستقلة. Auto‑Tune غير متاح في هذه النسخة.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("السماعة والميكروفون", icon: "headphones")
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(audio.route.isEmpty ? "اختر سماعتك" : audio.route).font(.headline)
                    Text(audio.inputRoute.isEmpty ? "الميكروفون يظهر بعد البدء" : "الالتقاط: \(audio.inputRoute)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(); AudioOutputPicker().frame(width: 52, height: 52)
            }
            Text("البلوتوث يعمل مع ميكروفون الآيفون. اختر سماعتك من مركز التحكم قبل البدء. تأخير البلوتوث لا تزيله إعدادات المؤثرات.").font(.footnote).foregroundStyle(gold)
            Picker("الميكروفون", selection: $audio.selectedInput) {
                Text("تلقائي").tag("")
                ForEach(audio.inputs, id: \.uid) { Text($0.portName).tag($0.uid) }
            }
            Toggle("استقرار أعلى عند التقطيع", isOn: $audio.stableBuffer)
            if audio.sampleRate > 0 {
                Text(String(format: "معدل العينة %.0f Hz • المخزن %.1f ms", audio.sampleRate, audio.bufferMS)).font(.caption.monospacedDigit())
                Text(String(format: "تأخير الجهاز المبلّغ عنه %.1f ms", audio.hardwareMS)).font(.caption.monospacedDigit())
                Text("ليس قياسًا كاملًا للتأخير من الميكروفون إلى الأذن.").font(.caption).foregroundStyle(.secondary)
            }
        }.card()
    }
    private var transport: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button { audio.toggle() } label: {
                    Label(audio.starting ? "إلغاء" : (audio.running ? "إيقاف" : "ابدأ المعالجة"), systemImage: audio.running ? "stop.fill" : "play.fill")
                        .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(theme.onAccent).background(gold, in: RoundedRectangle(cornerRadius: theme.radius))
                }.buttonStyle(.plain)
                Button { audio.set(.mute, audio.value(.mute) > 0.5 ? 0 : 1) } label: {
                    Label(audio.value(.mute) > 0.5 ? "السماعة مكتومة" : "كتم السماعة", systemImage: "speaker.slash.fill")
                        .font(.headline).frame(minWidth: 92, minHeight: 56)
                        .background(audio.value(.mute) > 0.5 ? Color.red.opacity(0.45) : surface, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
            Toggle("مقارنة بالصوت الأصلي", isOn: Binding(get: { audio.value(.bypass) > 0.5 }, set: { audio.set(.bypass, $0 ? 1 : 0) })).font(.footnote)
            CopyrightFooter()
        }.padding(.horizontal, 20).padding(.vertical, 8).background(.ultraThinMaterial)
    }
    private func heading(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundStyle(gold).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func effectHeading(_ title: String, icon: String, effect: Effect) -> some View {
        Toggle(isOn: Binding(get: { audio.settings.enabled(effect) }, set: { audio.setEnabled(effect, $0) })) {
            VStack(alignment: .leading, spacing: 4) {
                heading(title, icon: icon)
                Text(audio.settings.enabled(effect) ? "مفعّل" : "متوقف • الإعدادات محفوظة").font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityLabel("تفعيل \(title)")
    }
    private func control(_ p: Parameter) -> some View {
        ThemeParameterControl(audio: audio, parameter: p)
    }
    private func meter(_ label: String, value: Float) -> some View {
        let decibels = 20 * log10(max(value, 0.00001))
        let normalized = Double(max(0, min(1, (decibels + 60) / 60)))
        return HStack(spacing: 10) {
            Text(label).font(.caption).frame(width: 42, alignment: .leading)
            if theme == .simple { ProgressView(value: normalized).tint(value > 0.9 ? .orange : mint) }
            else { SignalLED(level: value, tint: mint, lights: reactiveLights) }
            Text(value < 0.0001 ? "—" : String(format: "%.0f dB", decibels)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 58).environment(\.layoutDirection, .leftToRight)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityValue(String(format: "%.0f ديسيبل", decibels))
    }
    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("اصنع مساحتك الصوتية").font(.title.bold())
                    Text("من زر الشكل أعلى الشاشة اختر استوديو للمقابض الدقيقة، بسيط للأصوات بضغطة، أو مسرح للمفاتيح الكبيرة. كل الأشكال تصل إلى المؤثرات والتسجيل والتوصيل. تغيير الشكل لا يغيّر الصوت.")
                    Text("إضاءة المسرح تتبع مستوى الصوت المعالج مع حالة المؤثر؛ ليست مقياسًا منفصلًا لكل وحدة. يمكنك إطفاء الوهج وإخفاء الشروح من قائمة الشكل. المقابض تُضبط بالسحب لأعلى وأسفل أو عبر شريط التحكم في صفحة المؤثرات.")
                    Text("١. يمكنك التسجيل مباشرة بدون سماعة من صفحة التسجيل. للاستماع المباشر وصّل سماعة، ثم ابدأ المعالجة واسمح بالميكروفون.")
                    Text("٢. جرّب قاعة كبيرة للصدى القوي، أو فخم / ثقيل للامتلاء. ارفع تقوية الالتقاط تدريجيًا بزر +6 dB إذا كان الصوت ضعيفًا.")
                    Text("٣. قوة المؤثرات تغيّر كمية الصدى والحركة معًا. من صفحة المؤثرات اضبط طول الذيل وفاصل البداية، واضغط مرتين لضبط الصدى على إيقاعك.")
                    Text("مؤشر الالتقاط يقيس الصوت بعد التقوية الرقمية. التقوية ترفع الضجيج أيضًا ولا تصلح تشوّهًا حدث في الميكروفون. قرّب الهاتف واستخدم مستوى مناسبًا.")
                    Text("حماية القمم تخفض المستوى عند الحاجة. ابدأ بخروج منخفض، وأبعد الميكروفون عن أي مكبر صوت خارجي لتجنب الصفير.")
                    Text("بعد مكالمة أو تغيير السماعة، اضغط ابدأ مجددًا. Bluetooth A2DP يضيف تأخيرًا، والسلك أسرع للعزف المتزامن. ميكروفون سماعة البلوتوث غير مستخدم.")
                    Text("تحفظ الإعدادات لكل وضع، ويمكن حفظ لونك المفضل. Auto‑Tune غير متاح. زر المقارنة يتجاوز المؤثرات مع بقاء كسب الإدخال والخروج والكتم وحماية القمم.")
                }.padding(24)
            }.toolbar { Button("تم") { showHelp = false } }.navigationTitle("دليل العزف")
            .safeAreaInset(edge: .bottom) { CopyrightFooter().background(.ultraThinMaterial) }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}

private struct AudioOutputPicker: UIViewRepresentable {
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.prioritizesVideoDevices = false
        view.tintColor = UIColor(palette.accent(theme))
        view.activeTintColor = UIColor(red: 0.39, green: 0.83, blue: 0.74, alpha: 1)
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) { uiView.tintColor = UIColor(palette.accent(theme)) }
}

private extension View {
    func card() -> some View { modifier(ThemedPanel()) }
}
