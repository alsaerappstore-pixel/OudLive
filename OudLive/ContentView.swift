import SwiftUI

private let gold = Color(red: 0.89, green: 0.72, blue: 0.43)
private let surface = Color(red: 0.10, green: 0.13, blue: 0.14)

@MainActor
struct ContentView: View {
    @ObservedObject var audio: AudioModel
    @State private var performance = false
    @State private var showHelp = false
    private let presets = ["طبيعي", "كلاسيكي", "فخم / ثقيل", "حاد", "مشكل"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Picker("نوع الصوت", selection: Binding(get: { audio.mode }, set: { audio.chooseMode($0) })) {
                    ForEach(SoundMode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityLabel("نوع الصوت")
                status
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("لون العزف", subtitle: audio.settings.preset)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                        ForEach(presets, id: \.self) { name in
                            Button { audio.choosePreset(name) } label: {
                                HStack {
                                    Text(name).font(.headline)
                                    Spacer(minLength: 4)
                                    if audio.settings.preset == name { Image(systemName: "checkmark.circle.fill") }
                                }.frame(minHeight: performance ? 66 : 48).padding(.horizontal, 14)
                                    .foregroundStyle(audio.settings.preset == name ? Color.black : Color.white)
                                    .background(audio.settings.preset == name ? gold : surface, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).accessibilityAddTraits(audio.settings.preset == name ? .isSelected : [])
                        }
                    }
                }
                control(.output)
                if !performance {
                    control(.input)
                    VStack(spacing: 18) {
                        sectionTitle("المساحة والصدى", subtitle: "SPACE")
                        control(.reverb); control(.delay)
                        if audio.value(.delay) > 0 { control(.delayTime); control(.feedback) }
                    }.card()
                    VStack(spacing: 18) {
                        sectionTitle("نبرة العود", subtitle: "EQ + DYNAMICS")
                        control(.low); control(.mid); control(.high); control(.compression)
                    }.card()
                    VStack(spacing: 18) {
                        sectionTitle("الحركة والعرض", subtitle: "MODULATION")
                        Picker("نوع الحركة", selection: Binding(get: { audio.value(.flanger) > 0.5 ? 1 : 0 }, set: { audio.set(.flanger, Double($0)) })) {
                            Text("Chorus").tag(0); Text("Flanger").tag(1)
                        }.pickerStyle(.segmented)
                        control(.modulation); control(.modRate); control(.doubler)
                    }.card()
                    if audio.mode == .voice {
                        Label("وضع مستقل للصوت البشري مع إعدادات محفوظة. تصحيح النغمة التلقائي Auto‑Tune غير متاح في هذه النسخة.", systemImage: "mic.fill")
                            .font(.footnote).foregroundStyle(.secondary).card()
                    }
                    connection
                }
                Text("معالجة على الجهاز • لا تسجيل ولا رفع للصوت")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.045, green: 0.065, blue: 0.07))
        .tint(gold)
        .safeAreaInset(edge: .bottom) { transport }
        .sheet(isPresented: $showHelp) { help }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("عود لايف").font(.largeTitle.bold()).foregroundStyle(gold)
                Text("صوتك، كما تحب تسمعه").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("طريقة الاستخدام")
        }
    }
    private var status: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Circle().fill(audio.running ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(audio.running ? "مباشر الآن" : "متوقف").font(.headline)
                Spacer()
                Button(performance ? "إظهار المؤثرات" : "واجهة العزف") { performance.toggle() }
                    .font(.subheadline).frame(minHeight: 44)
            }
            meter("الميكروفون", value: audio.inputLevel)
            meter("الخروج", value: audio.outputLevel)
            Text(audio.message).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.card()
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("توصيل الصوت", subtitle: "AUDIO")
            Text(audio.route.isEmpty ? "لا يوجد خرج متصل" : audio.route).font(.subheadline)
            Picker("الميكروفون", selection: $audio.selectedInput) {
                Text("تلقائي حسب التوصيل").tag("")
                ForEach(audio.inputs, id: \.uid) { Text($0.portName).tag($0.uid) }
            }
            Toggle("استقرار أعلى • مخزن أكبر", isOn: $audio.stableBuffer)
            if audio.sampleRate > 0 {
                Text(String(format: "%.0f Hz  ·  المخزن الفعلي %.1f ms", audio.sampleRate, audio.bufferMS))
                    .font(.caption.monospacedDigit())
                Text(String(format: "تأخير الإدخال + الإخراج المبلّغ عنه: %.1f ms", audio.hardwareMS)).font(.caption)
                Text("هذه قيم الجهاز، وليست قياسًا كاملًا للتأخير من الميكروفون إلى الأذن.").font(.caption).foregroundStyle(.secondary)
            }
        }.card()
    }
    private var transport: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { audio.toggle() } label: {
                    Label(audio.starting ? "إلغاء" : (audio.running ? "إيقاف" : "ابدأ العزف"), systemImage: audio.running ? "stop.fill" : "play.fill")
                        .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 58)
                        .foregroundStyle(Color.black).background(gold, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
                Button { audio.set(.mute, audio.value(.mute) > 0.5 ? 0 : 1) } label: {
                    Label(audio.value(.mute) > 0.5 ? "مكتوم" : "كتم", systemImage: "speaker.slash.fill")
                        .font(.headline).frame(minWidth: 92, minHeight: 58)
                        .background(audio.value(.mute) > 0.5 ? Color.red.opacity(0.5) : surface, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
            Toggle("تجاوز المؤثرات • استمع للصوت الأصلي", isOn: Binding(get: { audio.value(.bypass) > 0.5 }, set: { audio.set(.bypass, $0 ? 1 : 0) }))
                .font(.footnote)
        }.padding(.horizontal, 20).padding(.vertical, 12).background(.ultraThinMaterial)
    }
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Text(subtitle).font(.caption).foregroundStyle(gold) }
    }
    private func control(_ p: Parameter) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(p.label).font(.subheadline)
                Spacer()
                Text(p.text(audio.value(p))).font(.subheadline.monospacedDigit()).foregroundStyle(gold).environment(\.layoutDirection, .leftToRight)
            }
            Slider(value: Binding(get: { audio.value(p) }, set: { audio.set(p, $0) }), in: p.range)
                .frame(minHeight: 44).accessibilityLabel(p.label).accessibilityValue(p.text(audio.value(p)))
        }
    }
    private func meter(_ label: String, value: Float) -> some View {
        let normalized = Double(max(0, min(1, (20 * log10(max(value, 0.00001)) + 60) / 60)))
        return HStack {
            Text(label).font(.caption).frame(width: 70, alignment: .leading)
            ProgressView(value: normalized).tint(value > 0.9 ? .red : gold)
            Text(value > 0.9 ? "عالٍ" : "").font(.caption).foregroundStyle(.red).frame(width: 30)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityValue(String(format: "%.0f ديسيبل", 20 * log10(max(value, 0.00001))))
    }
    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("جاهز للعزف في ثلاث خطوات").font(.title.bold())
                    Text("١. وصّل سماعة سلكية أو واجهة صوت USB إلى الآيفون. لا تُستخدم سماعة Bluetooth للمراقبة المباشرة في هذا الإصدار.")
                    Text("٢. اضغط ابدأ واسمح بالميكروفون. اختر الميكروفون من قسم التوصيل إذا كانت سماعتك تحتوي على ميكروفون بعيد عن العود.")
                    Text("٣. اختر لون الصوت، واضبط مستوى الخروج تدريجيًا. استخدم واجهة العزف للوصول السريع للألوان والكتم.")
                    Text("إذا سمعت تقطيعًا، أوقف الصوت وفعّل استقرار أعلى ثم ابدأ مجددًا. بعد مكالمة أو تغيير توصيل السماعة، أعد التشغيل يدويًا.")
                    Text("الإعدادات تُحفظ لكل من العود والصوت البشري. مشكل هو مزيج صدى وحركة وتوسيع. Doubler يضيف نسختين متحركتين زمنيًا؛ ليس تصحيحًا للنغمة.")
                    Text("عند استخدام واجهة صوت متصلة بمكبر خارجي، أبعد الميكروفون عن المكبر لتجنب الصفير. ابدأ بصوت منخفض.")
                }.padding(24)
            }.toolbar { Button("تم") { showHelp = false } }.navigationTitle("طريقة الاستخدام")
        }.environment(\.layoutDirection, .rightToLeft)
    }
}

private extension View {
    func card() -> some View { padding(18).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 22)) }
}
