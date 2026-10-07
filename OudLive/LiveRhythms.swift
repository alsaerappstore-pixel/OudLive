import SwiftUI

struct LiveRhythm: Decodable, Identifiable {
    let id: Int
    let region, name, meter, description, source: String
    let bpm, numerator, denominator: Int
    static let all: [LiveRhythm] = {
        guard let url = Bundle.main.url(forResource: "catalogue", withExtension: "json", subdirectory: "RhythmBank"),
              let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([LiveRhythm].self, from: data),
              rows.enumerated().allSatisfy({ $0.offset == $0.element.id && (40...220).contains($0.element.bpm) }) else { return [] }
        return rows
    }()
    static var regions: [String] { all.reduce(into: []) { if !$0.contains($1.region) { $0.append($1.region) } } }
}

@MainActor
struct RhythmLauncher: View {
    @ObservedObject var audio: AudioModel
    @State private var showingLibrary = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path").font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("الإيقاعات الحية").font(.headline)
                    Text(audio.selectedRhythm?.name ?? "مكتبة الإيقاعات").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { audio.toggleRhythm() } label: {
                    Image(systemName: audio.rhythmPlaying ? "stop.fill" : "play.fill")
                        .frame(width: 48, height: 48).background(.orange.opacity(0.18), in: Circle())
                }.disabled(audio.starting).accessibilityLabel(audio.rhythmPlaying ? "إيقاف الإيقاع" : "تشغيل الإيقاع دون تسجيل")
                Button { showingLibrary = true } label: {
                    Image(systemName: "list.bullet.rectangle").frame(width: 44, height: 48)
                }.accessibilityLabel("اختيار الإيقاع والسرعة")
            }
            HStack {
                Text("\(Int(audio.rhythmTempo)) نبضة/دقيقة").font(.caption.monospacedDigit())
                Spacer()
                Button("اختيار الإيقاع والسرعة") { showingLibrary = true }.font(.caption.bold()).frame(minHeight: 32)
            }
            if audio.rhythmPlaying {
                RhythmPulse(audio: audio)
                Text(audio.monitoring ? "تسمعه الآن • يدخل في التسجيل تلقائيًا" : "الإيقاع يعمل ويدخل في التسجيل • وصّل سماعة لسماعه")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(14).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.orange.opacity(0.32)))
            .sheet(isPresented: $showingLibrary) { RhythmLibrary(audio: audio) }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--console-rhythms") { showingLibrary = true }
                #endif
            }
    }
}

@MainActor
private struct RhythmPulse: View {
    @ObservedObject var audio: AudioModel
    var body: some View {
        let count = min(16, audio.selectedRhythm?.numerator ?? 4)
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule().fill(audio.rhythmPlaying && index == min(count - 1, Int(audio.rhythmPosition * Float(count))) ? Color.orange : Color.gray.opacity(0.2))
                    .frame(height: 6)
            }
        }.environment(\.layoutDirection, .leftToRight).accessibilityHidden(true)
    }
}

@MainActor
struct RhythmLibrary: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var region = LiveRhythm.regions.first ?? ""
    @State private var search = ""
    private var filtered: [LiveRhythm] {
        LiveRhythm.all.filter { search.isEmpty ? $0.region == region : ($0.name.contains(search) || $0.region.contains(search)) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    controls
                    Text("أصوات آلات مسجّلة حقيقية • \(LiveRhythm.all.count) توزيعًا للعزف")
                        .font(.subheadline.bold())
                    Text("توزيعات مبسطة ومستوحاة من هذه الألوان. المناطق للتصفح حسب التداول، وبعض الإيقاعات مشتركة ولها صيغ محلية متعددة.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("ابحث باسم الإيقاع أو المنطقة", text: $search).textFieldStyle(.roundedBorder)
                    if search.isEmpty {
                        Picker("المنطقة", selection: $region) {
                            ForEach(LiveRhythm.regions, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { rhythm in rhythmRow(rhythm) }
                    }
                    if filtered.isEmpty { Text("لا توجد إيقاعات مطابقة.").foregroundStyle(.secondary) }
                    DisclosureGroup("عن الأصوات والمراجع") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("دربكة: دُم، تَك وصفعة؛ رق، تصفيق وشيكر. لكل ضربة ثلاث تسجيلات تتناوب لتقليل التكرار الآلي. لا تتغير طبقة الآلة عند تغيير السرعة.")
                            Text("التسجيلات من FreePats World Percussion بترخيص CC0، بأداء Xavimart وتسجيل Gonzalo وRoberto. البرمجة والتوزيعات: عود لايف.")
                            Link("مكتبة الأصوات وترخيصها", destination: URL(string: "https://freepats.zenvoid.org/Percussion/world-and-rare-percussion.html")!)
                            Link("مرجع المقامات والإيقاعات", destination: URL(string: "https://www.maqamworld.com/en/iqaa.php")!)
                            Link("السامري — سعوديبيديا", destination: URL(string: "https://saudipedia.com/en/samri-dance")!)
                            Text("المكتبة لا تدّعي حصر كل الإيقاعات الشرقية أو محاكاة جميع آلاتها الأصلية.")
                        }.font(.caption).padding(.top, 10)
                    }
                    CopyrightFooter()
                }.padding(20)
            }
            .navigationTitle("الإيقاعات الحية").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("تم") { dismiss() } }
            .onAppear { region = audio.selectedRhythm?.region ?? region }
        }.environment(\.layoutDirection, .rightToLeft).tint(.orange)
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.selectedRhythm?.name ?? "اختر إيقاعًا").font(.title3.bold())
                    Text("\(audio.selectedRhythm?.meter ?? "") • \(audio.selectedRhythm?.region ?? "")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { audio.toggleRhythm() } label: {
                    Label(audio.rhythmPlaying ? "إيقاف" : "تشغيل", systemImage: audio.rhythmPlaying ? "stop.fill" : "play.fill")
                        .font(.headline).padding(12).background(.orange.opacity(0.18), in: Capsule())
                }.disabled(audio.starting)
            }
            RhythmPulse(audio: audio)
            HStack(spacing: 16) {
                RhythmKnob(value: Binding(get: { audio.rhythmTempo }, set: { audio.setRhythmTempo($0) }), range: 40...220,
                           label: "السرعة", formatted: "\(Int(audio.rhythmTempo))", color: .orange)
                VStack(spacing: 8) {
                    Text("نبضة في الدقيقة").font(.caption)
                    HStack(spacing: 18) {
                        Button { audio.setRhythmTempo(audio.rhythmTempo - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }.accessibilityLabel("أبطأ بنبضة")
                        Button { audio.setRhythmTempo(audio.rhythmTempo + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("أسرع بنبضة")
                    }.buttonStyle(.bordered)
                    Button("اضغط على سرعتك") { audio.tapRhythmTempo() }.font(.caption.bold()).frame(minHeight: 44)
                }.frame(maxWidth: .infinity)
                RhythmKnob(value: Binding(get: { audio.rhythmVolume }, set: { audio.setRhythmVolume($0) }), range: 0...1,
                           label: "المستوى", formatted: "\(Int(audio.rhythmVolume * 100))٪", color: .cyan)
            }
            Text("اسحب القرص لأعلى للزيادة أو لأسفل للتقليل. السرعة محسوبة على النوتة السوداء (ربع)، من ٤٠ إلى ٢٢٠.")
                .font(.caption2).foregroundStyle(.secondary)
            Text("يُدمج الإيقاع مع العود بعد المؤثرات، ويُحفظ تلقائيًا مع تسجيل الصوت أو الفيديو. للاستماع المباشر وصّل سماعة.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(14).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
    private func rhythmRow(_ rhythm: LiveRhythm) -> some View {
        Button { audio.chooseRhythm(rhythm) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: audio.rhythmID == rhythm.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(audio.rhythmID == rhythm.id ? Color.orange : Color.secondary).padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(rhythm.name).font(.headline); Spacer(); Text(rhythm.meter).font(.caption.monospacedDigit()) }
                    Text(rhythm.description).font(.caption).foregroundStyle(.secondary)
                    Text("\(rhythm.bpm) نبضة/دقيقة افتراضيًا • \(rhythm.region)").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(audio.rhythmID == rhythm.id ? Color.orange.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(audio.rhythmID == rhythm.id ? Color.orange : Color.clear))
        }.buttonStyle(.plain).accessibilityAddTraits(audio.rhythmID == rhythm.id ? .isSelected : [])
    }
}

private struct RhythmKnob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label, formatted: String
    let color: Color
    @State private var origin: Double?
    private var fraction: Double { (value - range.lowerBound) / (range.upperBound - range.lowerBound) }
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.gray.opacity(0.25), lineWidth: 5)
                Circle().trim(from: 0, to: 0.75 * fraction).stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(135))
                Circle().fill(LinearGradient(colors: [.gray.opacity(0.7), .black], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(7)
                Capsule().fill(.white).frame(width: 3, height: 16).offset(y: -19).rotationEffect(.degrees(-135 + fraction * 270))
            }.frame(width: 66, height: 66).padding(5).contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                    if origin == nil { origin = value }
                    value = min(range.upperBound, max(range.lowerBound, (origin ?? value) - Double(gesture.translation.height) / 180 * (range.upperBound - range.lowerBound)))
                }.onEnded { _ in origin = nil })
                .accessibilityElement().accessibilityLabel(label).accessibilityValue(formatted)
                .accessibilityAdjustableAction { direction in
                    let step = range.upperBound > 1 ? 1.0 : 0.05
                    value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? step : -step)))
                }
            Text(formatted).font(.headline.monospacedDigit())
            Text(label).font(.caption)
        }
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
