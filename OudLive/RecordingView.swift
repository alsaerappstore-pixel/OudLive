import SwiftUI
import AVKit

@MainActor
struct RecordingView: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.oudTheme) private var theme
    @Environment(\.oudPalette) private var palette
    @Environment(\.oudEra) private var era
    @State private var video = false
    @State private var playing: PlaybackRequest?
    @State private var selecting = false
    @State private var selected: Set<URL> = []
    @State private var deleting: Set<URL> = []
    @State private var confirmDelete = false
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing || audio.savingToPhotos != nil }
    private var entries: [RecordingEntry] { audio.recordingEntries }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("سجّل عزفك").font(.title2.bold())
            Text("صوت المؤثرات محفوظ حتى بدون سماعة. الكتم ومستوى السماعة لا يغيّران التسجيل.").font(.caption).foregroundStyle(.secondary)
            recordingPresets
            QuickSoundBank(audio: audio)
            VStack(spacing: 12) {
                ThemeParameterControl(audio: audio, parameter: .recordGain)
                SignalLED(level: audio.recordingLevel, tint: audio.recordingLimiting > 3 ? .orange : .green)
                Text(audio.recordingLimiting > 3 ? "خفّض التسجيل أو الالتقاط؛ حماية القمم تعمل بقوة." : "قرّب الميكروفون وارفع المستوى تدريجيًا.").font(.caption).foregroundStyle(.secondary)
            }.modifier(ThemedPanel())
            Picker("نوع التسجيل", selection: $video) {
                Text("صوت").tag(false); Text("فيديو وصوت").tag(true)
            }.pickerStyle(.segmented).disabled(busy)
            if video {
                Label("الأمامية • أوسع مشهد متاح", systemImage: "camera.rotate").font(.subheadline.bold())
                Text("بدون تكبير رقمي أو قص لملء المعاينة. اتساع المشهد تحدده عدسة جهازك. أبقِ التطبيق مفتوحًا والهاتف عموديًا.").font(.caption).foregroundStyle(.secondary)
            }
            if let session = audio.cameraSession {
                CameraPreview(session: session).aspectRatio(9 / 16, contentMode: .fit).frame(maxHeight: 380).background(.black).clipShape(RoundedRectangle(cornerRadius: era.radius(theme)))
            }
            if audio.recording {
                Label(String(format: "%02d:%02d", audio.recordingSeconds / 60, audio.recordingSeconds % 60), systemImage: "record.circle").font(.title.monospacedDigit()).foregroundStyle(.red)
            }
            Button {
                if audio.recording || audio.recordingPreparing { audio.finishRecording() }
                else { audio.beginRecording(video: video, front: true) }
            } label: {
                Label(audio.recording ? "إيقاف وحفظ" : (audio.recordingPreparing ? "إلغاء التجهيز" : "ابدأ التسجيل"), systemImage: audio.recording ? "stop.circle.fill" : "record.circle").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            }.buttonStyle(.borderedProminent).tint(.red).disabled(audio.recordingFinishing || audio.starting || audio.savingToPhotos != nil)
            if audio.recordingFinishing { ProgressView("جارٍ حفظ التسجيل…") }
            library
        }
        .sheet(item: $playing) { RecordingPlayback(request: $0) }
        .alert("الحفظ في الصور", isPresented: Binding(get: { audio.photosNotice != nil }, set: { if !$0 { audio.photosNotice = nil } })) {
            Button("تم") { audio.photosNotice = nil }
        } message: { Text(audio.photosNotice ?? "") }
        .alert("حذف \(deleting.count) تسجيل؟", isPresented: $confirmDelete) {
            Button("حذف المحدد", role: .destructive) {
                audio.deleteRecordings(deleting); selected.subtract(deleting); deleting = []; selecting = false
            }
            Button("إلغاء", role: .cancel) { deleting = [] }
        } message: { Text("سيُحذف الصوت والفيديو المرتبطان بكل تسجيل محدد من التطبيق. النسخ المحفوظة في ألبوم الصور تبقى كما هي.") }
        .onChange(of: audio.recordings) { _ in selected.formIntersection(Set(entries.map(\.id))) }
    }
    private var recordingPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("١٥ طابعًا • اضغط واسمع الفرق").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(RecordingPreset.all) { preset in
                    let active = audio.mode == .oud && audio.settings.preset == preset.name
                    Button { audio.chooseRecordingPreset(preset) } label: {
                        VStack(spacing: 5) {
                            StatusLamp(on: active && audio.value(.bypass) < 0.5)
                            Text(preset.name).font(.caption.bold()).lineLimit(2)
                        }.frame(maxWidth: .infinity, minHeight: 55).padding(5).background { EraSurface() }
                    }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : []).accessibilityHint(preset.description)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("الحالي: \(audio.settings.preset)").font(.subheadline.bold())
                Text(SoundSettings.detail(audio.settings.preset)).font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(era.accent(theme, palette).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            Text("اللمبة تحدد الطابع المختار. تحافظ الأزرار على مستوياتك؛ اترك الصدى يهدأ بين الطوابع. التغيير يؤثر في التسجيل الجاري فقط.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("تسجيلاتي • \(entries.count)").font(.headline)
                Spacer()
                Button(selecting ? "إلغاء التحديد" : "تحديد") { selecting.toggle(); selected = [] }.disabled(busy || entries.isEmpty)
            }
            if selecting {
                HStack {
                    Button(selected.count == entries.count ? "إلغاء الكل" : "تحديد الكل") { selected = selected.count == entries.count ? [] : Set(entries.map(\.id)) }
                    Spacer()
                    Button("حذف المحدد (\(selected.count))", role: .destructive) { deleting = selected; confirmDelete = true }.disabled(selected.isEmpty)
                }.buttonStyle(.bordered).disabled(busy)
            }
            if entries.isEmpty { Text("تظهر تسجيلاتك هنا بعد الحفظ.").font(.caption).foregroundStyle(.secondary) }
            ForEach(entries) { entry in recordingCard(entry) }
            Text("كل تسجيل بطاقة واحدة. تسجيل الصوت وحده يُعرض كفيديو بغلاف ثابت عند اختيار الفيديو أو الحفظ في الصور.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func recordingCard(_ entry: RecordingEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if selecting {
                    Button {
                        if selected.contains(entry.id) { selected.remove(entry.id) } else { selected.insert(entry.id) }
                    } label: { Image(systemName: selected.contains(entry.id) ? "checkmark.circle.fill" : "circle").font(.title2).frame(width: 44, height: 44) }
                        .accessibilityLabel("تحديد " + entry.title).accessibilityValue(selected.contains(entry.id) ? "محدد" : "غير محدد").disabled(busy)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.videoURL == nil ? "تسجيل صوتي" : "تسجيل بالصورة والصوت").font(.subheadline.bold())
                    Text(entry.title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            HStack {
                Button { play(entry, video: false) } label: { Label("تشغيل صوت", systemImage: "speaker.wave.2.fill").frame(maxWidth: .infinity, minHeight: 44) }
                Button { play(entry, video: true) } label: { Label(entry.videoURL == nil ? "فيديو بغلاف" : "تشغيل فيديو", systemImage: "play.rectangle.fill").frame(maxWidth: .infinity, minHeight: 44) }
            }.font(.caption.bold()).buttonStyle(.bordered).disabled(busy)
            HStack {
                Button { audio.saveVideoToPhotos(entry.primaryURL) } label: { Label("حفظ بالصور", systemImage: "photo.on.rectangle") }
                ShareLink(item: entry.primaryURL) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }.accessibilityLabel("مشاركة التسجيل")
                Spacer(minLength: 0)
                Button(role: .destructive) { deleting = [entry.id]; confirmDelete = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("حذف التسجيل")
            }.font(.caption.bold()).buttonStyle(.plain).disabled(busy)
            if audio.savingToPhotos == entry.primaryURL { ProgressView("جارٍ الحفظ في الصور…") }
        }.modifier(ThemedPanel())
    }
    private func play(_ entry: RecordingEntry, video: Bool) {
        audio.stop(); playing = PlaybackRequest(url: entry.primaryURL, video: video)
    }
}

private struct PlaybackRequest: Identifiable { let id = UUID(); let url: URL; let video: Bool }
@MainActor
private struct RecordingPlayback: View {
    let request: PlaybackRequest
    @State private var player = AVPlayer()
    @State private var ready = false
    @State private var failed: String?
    @State private var elapsed = 0.0
    @State private var duration = 0.0
    @State private var isPlaying = false
    @State private var temporary: URL?
    @Environment(\.dismiss) private var dismiss
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let failed { Text(failed).padding() }
                else if !ready { ProgressView("جارٍ تجهيز التشغيل…") }
                else if request.video { VideoPlayer(player: player) }
                else {
                    Image(systemName: "waveform.circle.fill").font(.system(size: 90)).foregroundStyle(.secondary)
                    Text("صوت التسجيل بنفس المؤثرات").font(.headline)
                    Text(String(format: "%02d:%02d / %02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60, Int(duration) / 60, Int(duration) % 60)).monospacedDigit()
                    Slider(value: Binding(get: { elapsed }, set: { elapsed = $0; player.seek(to: CMTime(seconds: $0, preferredTimescale: 600)) }), in: 0...max(0.1, duration)).accessibilityLabel("موضع التشغيل")
                    Button {
                        if isPlaying { player.pause() }
                        else { if elapsed >= duration - 0.1 { player.seek(to: .zero) }; player.play() }
                        isPlaying.toggle()
                    } label: { Label(isPlaying ? "إيقاف مؤقت" : "تشغيل", systemImage: isPlaying ? "pause.fill" : "play.fill").frame(minHeight: 44) }.buttonStyle(.borderedProminent)
                }
            }.padding(request.video ? 0 : 24)
                .toolbar { Button("تم") { dismiss() } }.navigationTitle(request.video ? "تشغيل فيديو" : "تشغيل صوت")
                .safeAreaInset(edge: .bottom) { CopyrightFooter().background(.ultraThinMaterial) }
                .task {
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                        try AVAudioSession.sharedInstance().setActive(true)
                        let item: AVPlayerItem
                        if !request.video {
                            item = AVPlayerItem(asset: try await RecordingExport.audioOnlyAsset(request.url))
                        } else if request.url.pathExtension.lowercased() == "wav" {
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                            temporary = url
                            try await RecordingExport.audioMovie(audio: request.url, destination: url)
                            item = AVPlayerItem(url: url)
                        } else { item = AVPlayerItem(url: request.url) }
                        try Task.checkCancellation()
                        let length = try await item.asset.load(.duration).seconds
                        duration = length.isFinite ? length : 0
                        try Task.checkCancellation()
                        player.replaceCurrentItem(with: item); ready = true; player.play(); isPlaying = true
                    } catch { if !Task.isCancelled { failed = error.localizedDescription }; cleanup() }
                }
                .onReceive(timer) { _ in
                    let time = player.currentTime().seconds
                    elapsed = time.isFinite ? max(0, time) : 0
                    isPlaying = player.rate > 0
                }
                .onDisappear { cleanup() }
        }.environment(\.layoutDirection, .rightToLeft)
    }
    private func cleanup() {
        player.pause(); player.replaceCurrentItem(with: nil)
        if let temporary { try? FileManager.default.removeItem(at: temporary) }
    }
}

private final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface(); view.preview.session = session; view.preview.videoGravity = .resizeAspect
        return view
    }
    func updateUIView(_ view: PreviewSurface, context: Context) {
        if let connection = view.preview.connection, connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
    }
}
