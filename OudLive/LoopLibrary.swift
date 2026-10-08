import Foundation
#if canImport(UIKit)
import SwiftUI
#endif

struct UserLoop: Codable, Identifiable {
    let id: String
    let name: String
    let group: String
    let file: String
    let playable: Bool
    let duration: Double
}

struct LoopLibrary {
    private let originals: [UserLoop]
    private let defaults: UserDefaults
    private var removed: Set<String>
    private(set) var slots: [String]
    var items: [UserLoop] { originals.filter { !removed.contains($0.id) } }
    var removedCount: Int { originals.filter { removed.contains($0.id) }.count }
    private var names: [String: String]
    init(data: Data? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "UserLoops")
        originals = (data ?? url.flatMap { try? Data(contentsOf: $0) }).flatMap { try? JSONDecoder().decode([UserLoop].self, from: $0) }?.filter { $0.playable || $0.file.hasSuffix(".rx2") } ?? []
        names = defaults.dictionary(forKey: "OudLive.userLoopNames.v1") as? [String: String] ?? [:]
        removed = Set(defaults.stringArray(forKey: "OudLive.removedLoops.v1") ?? [])
        let stored = defaults.stringArray(forKey: "OudLive.loopSlots.v1") ?? []
        let blocked = removed
        let usable = Set(originals.filter { $0.playable && !blocked.contains($0.id) }.map(\.id))
        slots = (0..<5).map { $0 < stored.count && usable.contains(stored[$0]) ? stored[$0] : "" }
    }
    func slot(_ index: Int) -> UserLoop? {
        guard slots.indices.contains(index) else { return nil }
        return items.first { $0.id == slots[index] && $0.playable }
    }
    mutating func assign(_ item: UserLoop?, to index: Int) {
        guard slots.indices.contains(index) else { return }
        guard item == nil || items.contains(where: { $0.id == item?.id && $0.playable }) else { return }
        slots[index] = item?.id ?? ""; saveSlots()
    }
    private func saveSlots() { defaults.set(slots, forKey: "OudLive.loopSlots.v1") }
    mutating func delete(_ item: UserLoop) {
        removed.insert(item.id)
        slots = slots.map { $0 == item.id ? "" : $0 }; saveSlots()
        defaults.set(Array(removed), forKey: "OudLive.removedLoops.v1")
    }
    mutating func restoreDeleted() {
        removed.removeAll(); defaults.removeObject(forKey: "OudLive.removedLoops.v1")
    }
    func title(_ item: UserLoop) -> String { names[item.id] ?? item.name }
    func url(_ item: UserLoop) -> URL? { Bundle.main.url(forResource: item.file, withExtension: nil, subdirectory: "UserLoops") }
    mutating func rename(_ item: UserLoop, name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        if clean.isEmpty { names.removeValue(forKey: item.id) } else { names[item.id] = clean }
        defaults.set(names, forKey: "OudLive.userLoopNames.v1")
    }
}

#if canImport(UIKit)
@MainActor
struct LoopLibraryPanel: View {
    @ObservedObject var audio: AudioModel
    @State private var showLibrary = false
    @State private var assigningSlot: Int?
    private var savedSlots: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("إيقاعاتي السريعة").font(.headline)
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<5) { index in
                    let item = audio.loopLibrary.slot(index)
                    VStack(spacing: 0) {
                        Button {
                            if let item { audio.selectLoop(item) }
                            else { assigningSlot = index; showLibrary = true }
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(index + 1)").font(.caption.bold())
                                Image(systemName: item == nil ? "plus" : "play.fill")
                                Text(item.map { audio.loopLibrary.title($0) } ?? "فارغة")
                                    .font(.caption2).lineLimit(2).frame(height: 30)
                            }.frame(maxWidth: .infinity).frame(height: 76)
                                .background(item != nil && item?.id == audio.selectedLoop?.id ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                        Menu {
                            Button("اختيار / تغيير الإيقاع") { assigningSlot = index; showLibrary = true }
                            if let current = audio.selectedLoop { Button("حفظ الإيقاع الحالي") { audio.assignLoop(current, to: index) } }
                            Button("تفريغ الخانة", role: .destructive) { audio.assignLoop(nil, to: index) }.disabled(item == nil)
                        } label: { Image(systemName: "ellipsis").frame(maxWidth: .infinity).frame(height: 44) }
                            .accessibilityLabel("تعديل خانة الإيقاع \(index + 1)")
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            savedSlots
            Button { assigningSlot = nil; showLibrary = true } label: {
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
            HStack {
                Text("صوت العود")
                Slider(value: $audio.oudVolume, in: 0...2).accessibilityLabel("مستوى صوت العود في التسجيل")
                Text("\(Int(audio.oudVolume * 100))٪").monospacedDigit().frame(width: 46)
            }
            Text("المنزلقان يوازنان الصوت في السماعة والتسجيل. صفر يكتم القناة؛ 100٪ للعود هو مستواه الأصلي.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("الإيقاع في التسجيل", selection: $audio.recordLoop) {
                Text("حفظ مع التسجيل").tag(true)
                Text("استماع فقط").tag(false)
            }.pickerStyle(.segmented).disabled(busy)
            Text(audio.recordLoop ? "يدخل الإيقاع مع العود في تسجيل الصوت والفيديو." : "يُسمع الإيقاع مباشرًا ويُسجّل العود وحده. استخدم سماعة حتى لا يلتقط المايك صوت الإيقاع من مكبر الهاتف.")
                .font(.caption).foregroundStyle(.secondary)
            Text("100٪ هي السرعة الأصلية. تغيير السرعة يغيّر الحدة أيضًا؛ لا يغيّر ملفاتك. مؤثرات العود لا تُطبّق على الإيقاع.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showLibrary) { UserLoopBrowser(audio: audio, assigningSlot: assigningSlot) }
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
    let assigningSlot: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var deleting: UserLoop?
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
                    Text("\(audio.loopLibrary.items.filter(\.playable).count) إيقاع WAV متاحًا. حُفظت ملفات RX2 العشرون كما هي، لكنها تحتاج مشغّل REX ولا تعمل هنا. تعديل الاسم يغيّر اسم العرض فقط.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(filtered) { item in
                    HStack(spacing: 12) {
                        Button {
                            if let assigningSlot { audio.assignLoop(item, to: assigningSlot); dismiss() }
                            else { audio.selectLoop(item) }
                        } label: {
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
                        Button(role: .destructive) { deleting = item } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("حذف \(audio.loopLibrary.title(item))")
                    }
                }
                if filtered.isEmpty { Text("لا توجد إيقاعات مطابقة") }
                if audio.loopLibrary.removedCount > 0 {
                    Button("استعادة المحذوفة (\(audio.loopLibrary.removedCount))") { audio.restoreLoops() }
                }
                Text("ياسر الغامدي 2026").font(.caption).frame(maxWidth: .infinity)
            }.searchable(text: $search, prompt: "ابحث بالاسم")
            .navigationTitle(assigningSlot.map { "اختر لخانة \($0 + 1)" } ?? "إيقاعاتي الأصلية")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
            .confirmationDialog("حذف الإيقاع من المكتبة؟", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("حذف الإيقاع", role: .destructive) { if let deleting { audio.deleteLoop(deleting) }; deleting = nil }
                Button("إلغاء", role: .cancel) { deleting = nil }
            } message: { Text("يُزال من القائمة وخانات الحفظ، ويتوقف إذا كان يعمل. يمكنك استعادته لاحقًا من المكتبة.") }
            .alert("تعديل اسم العرض", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("اسم الإيقاع", text: $newName)
                Button("حفظ") { if let editing { audio.renameLoop(editing, name: newName) }; editing = nil }
                Button("إلغاء", role: .cancel) { editing = nil }
            } message: { Text("اترك الاسم فارغًا لاستعادة الاسم الأصلي.") }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}

#endif
