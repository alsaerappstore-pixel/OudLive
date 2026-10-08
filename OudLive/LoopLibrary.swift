import SwiftUI

struct UserLoop: Codable, Identifiable {
    let id: String
    let name: String
    let group: String
    let file: String
    let playable: Bool
    let duration: Double
}

struct LoopLibrary {
    let items: [UserLoop]
    private var names: [String: String]
    init() {
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "UserLoops")
        items = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([UserLoop].self, from: $0) }?.filter { $0.playable || $0.file.hasSuffix(".rx2") } ?? []
        names = UserDefaults.standard.dictionary(forKey: "OudLive.userLoopNames.v1") as? [String: String] ?? [:]
    }
    func title(_ item: UserLoop) -> String { names[item.id] ?? item.name }
    func url(_ item: UserLoop) -> URL? { Bundle.main.url(forResource: item.file, withExtension: nil, subdirectory: "UserLoops") }
    mutating func rename(_ item: UserLoop, name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        if clean.isEmpty { names.removeValue(forKey: item.id) } else { names[item.id] = clean }
        UserDefaults.standard.set(names, forKey: "OudLive.userLoopNames.v1")
    }
}

@MainActor
struct LoopLibraryPanel: View {
    @ObservedObject var audio: AudioModel
    @State private var showLibrary = false
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showLibrary = true } label: {
                HStack {
                    Image(systemName: "music.note.list").font(.title2)
                    VStack(alignment: .leading) {
                        Text("مكتبة إيقاعاتي").font(.headline)
                        Text(audio.selectedLoop.map { audio.loopLibrary.title($0) } ?? "اختر من إيقاعاتك الأصلية")
                            .font(.caption).lineLimit(1)
                    }
                    Spacer()
                    Text("\(audio.loopLibrary.items.filter(\.playable).count)").monospacedDigit()
                    Image(systemName: "chevron.down")
                }.frame(minHeight: 44)
            }.buttonStyle(.plain)
            HStack {
                Button { audio.toggleLoop() } label: {
                    Label(audio.loopPlaying ? "إيقاف الإيقاع" : "تشغيل الإيقاع", systemImage: audio.loopPlaying ? "pause.fill" : "play.fill")
                }.buttonStyle(.borderedProminent).disabled(audio.selectedLoop == nil)
                Spacer()
                Text(audio.loopPlaying ? "يُسمع الآن" : "متوقف").font(.caption).foregroundStyle(audio.loopPlaying ? .green : .secondary)
            }
            HStack {
                Text("السرعة")
                Slider(value: $audio.loopSpeed, in: 0.5...2, step: 0.05).accessibilityLabel("سرعة الإيقاع")
                Text("\(Int((audio.loopSpeed * 100).rounded()))٪").monospacedDigit().frame(width: 46)
                Button("الأصل") { audio.loopSpeed = 1 }.font(.caption).frame(minHeight: 44)
            }
            HStack {
                Text("صوت الإيقاع")
                Slider(value: $audio.loopVolume, in: 0...1).accessibilityLabel("مستوى صوت الإيقاع")
                Text("\(Int(audio.loopVolume * 100))٪").monospacedDigit().frame(width: 46)
            }
            Picker("الإيقاع في التسجيل", selection: $audio.recordLoop) {
                Text("حفظ مع التسجيل").tag(true)
                Text("استماع فقط").tag(false)
            }.pickerStyle(.segmented).disabled(busy)
            Text(audio.recordLoop ? "يدخل الإيقاع مع العود في تسجيل الصوت والفيديو." : "يُسمع الإيقاع مباشرًا ويُسجّل العود وحده. استخدم سماعة حتى لا يلتقط المايك صوت الإيقاع من مكبر الهاتف.")
                .font(.caption).foregroundStyle(.secondary)
            Text("100٪ هي السرعة الأصلية. تغيير السرعة يغيّر الحدة أيضًا؛ لا يغيّر ملفاتك. مؤثرات العود لا تُطبّق على الإيقاع.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showLibrary) { UserLoopBrowser(audio: audio) }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--loops") { showLibrary = true }
            #endif
        }
    }
}

@MainActor
private struct UserLoopBrowser: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var group = "الكل"
    @State private var editing: UserLoop?
    @State private var newName = ""
    private var filtered: [UserLoop] {
        audio.loopLibrary.items.filter {
            (group == "الكل" || $0.group == group) && (search.isEmpty || audio.loopLibrary.title($0).localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("المجموعة", selection: $group) {
                        Text("الكل").tag("الكل")
                        Text("شرقية 2025").tag("شرقية 2025")
                        Text("دفوف 128").tag("دفوف 128")
                    }.pickerStyle(.segmented)
                    Text("292 إيقاع WAV أصليًا. حُفظت ملفات RX2 العشرون كما هي، لكنها تحتاج مشغّل REX ولا تعمل هنا. تعديل الاسم يغيّر اسم العرض فقط.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(filtered) { item in
                    HStack(spacing: 12) {
                        Button { audio.selectLoop(item) } label: {
                            HStack {
                                Image(systemName: audio.selectedLoop?.id == item.id ? "checkmark.circle.fill" : (item.playable ? "play.circle" : "exclamationmark.circle"))
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(audio.loopLibrary.title(item)).foregroundStyle(.primary)
                                    Text(item.playable ? "\(item.group) • \(item.duration, specifier: "%.1f") ث" : "RX2 • غير مدعوم للتشغيل")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 48)
                        }.buttonStyle(.plain).disabled(!item.playable)
                        Button { editing = item; newName = audio.loopLibrary.title(item) } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("تعديل اسم \(audio.loopLibrary.title(item))")
                    }
                }
                if filtered.isEmpty { Text("لا توجد إيقاعات مطابقة") }
                Text("ياسر الغامدي 2026").font(.caption).frame(maxWidth: .infinity)
            }.searchable(text: $search, prompt: "ابحث بالاسم")
            .navigationTitle("إيقاعاتي الأصلية")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
            .alert("تعديل اسم العرض", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("اسم الإيقاع", text: $newName)
                Button("حفظ") { if let editing { audio.renameLoop(editing, name: newName) }; editing = nil }
                Button("إلغاء", role: .cancel) { editing = nil }
            } message: { Text("اترك الاسم فارغًا لاستعادة الاسم الأصلي.") }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
