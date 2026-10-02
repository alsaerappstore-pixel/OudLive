import SwiftUI
import AVKit

@MainActor
struct RecordingView: View {
    @ObservedObject var audio: AudioModel
    @Environment(\.oudTheme) private var theme
    @State private var video = false
    @State private var front = false
    @State private var playing: RecordingItem?
    @State private var saving: RecordingItem?
    @State private var deleting: URL?
    @State private var confirmDelete = false
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing || audio.savingToPhotos != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("سجّل عزفك").font(.title2.bold())
            Text("يسجّل بالمؤثرات ويحفظ على الجوال حتى بدون سماعة. مستوى السماعة وكتمها لا يؤثران في الملف.")
                .font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("مستوى التسجيل").font(.headline)
                    Spacer()
                    Text(String(format: "%.0f dB", audio.value(.recordGain))).monospacedDigit()
                }
                Slider(value: Binding(get: { audio.value(.recordGain) }, set: { audio.set(.recordGain, $0) }), in: Parameter.recordGain.range)
                ProgressView(value: Double(min(1, max(0, (20 * log10(max(audio.recordingLevel, 0.00001)) + 60) / 60))))
                    .tint(audio.recordingLimiting > 3 ? .orange : .green)
                Text(audio.recordingLimiting > 3 ? "حماية التسجيل تعمل بقوة؛ خفّض مستوى التسجيل أو الالتقاط لتبقى نبرة الأوتار طبيعية." : "ارفع المستوى تدريجيًا. إذا كان الالتقاط ضعيفًا، قرّب الميكروفون من العود أولًا.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("عود صافي • نبرة طبيعية وصدى خفيف") { audio.choosePreset("عود صافي") }.buttonStyle(.bordered)
                Text("يوقف الحركة والمضاعفة والضغط وتعديل النبرة؛ تبقى مساحة خفيفة يمكنك إطفاؤها من المؤثرات.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("نوع التسجيل", selection: $video) {
                Text("صوت WAV").tag(false); Text("فيديو مع الصوت").tag(true)
            }.pickerStyle(.segmented).disabled(busy)
            if video {
                Toggle("الكاميرا الأمامية", isOn: $front).disabled(busy)
                Text("فيديو عمودي 720p بصوت التأثيرات. أبقِ التطبيق مفتوحًا؛ قفل الهاتف أو مغادرته ينهي التسجيل. تُحفظ نسخة صوتية أيضًا.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let session = audio.cameraSession {
                CameraPreview(session: session).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 18))
            }
            if audio.recording {
                Label(String(format: "%02d:%02d", audio.recordingSeconds / 60, audio.recordingSeconds % 60), systemImage: "record.circle")
                    .font(.title.monospacedDigit()).foregroundStyle(.red)
            }
            Button {
                if audio.recording || audio.recordingPreparing { audio.finishRecording() }
                else { audio.beginRecording(video: video, front: front) }
            } label: {
                Label(audio.recording ? "إيقاف وحفظ التسجيل" : (audio.recordingPreparing ? "إلغاء التجهيز" : "ابدأ التسجيل"),
                      systemImage: audio.recording ? "stop.circle.fill" : "record.circle")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            }.buttonStyle(.borderedProminent).tint(.red)
                .disabled(audio.recordingFinishing || audio.starting)
            if !audio.monitoring { Text("لا تحتاج سماعة للتسجيل. مكبر الآيفون صامت أثناء المعالجة لمنع الصفير؛ يمكنك سماع الملف بعد الحفظ.").font(.caption) }
            if audio.recordingFinishing { ProgressView("جارٍ حفظ التسجيل…") }
            Text("تسجيلاتي").font(.headline)
            if audio.recordings.isEmpty {
                Text("تظهر تسجيلاتك هنا بعد إيقاف التسجيل. تبقى على الآيفون حتى تشاركها بنفسك.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(audio.recordings, id: \.self) { url in
                VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        audio.stop(); playing = RecordingItem(url: url)
                    } label: {
                        Image(systemName: url.pathExtension == "mp4" ? "play.rectangle.fill" : "play.circle.fill").font(.title2).frame(width: 44, height: 44)
                    }.disabled(busy).accessibilityLabel("تشغيل التسجيل")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(url.pathExtension == "mp4" ? "فيديو بالتأثيرات" : "صوت بالتأثيرات").font(.subheadline.bold())
                        Text(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "OudLive-", with: ""))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 12) {
                    Menu {
                        if url.pathExtension.lowercased() == "mp4" {
                            Button { audio.saveVideoToPhotos(url) } label: { Label("حفظ في الصور", systemImage: "photo.on.rectangle") }
                        }
                        Button { saving = RecordingItem(url: url) } label: { Label("حفظ في الملفات", systemImage: "folder") }
                    } label: { Label("حفظ", systemImage: "square.and.arrow.down") }
                    ShareLink(item: url) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                    Spacer(minLength: 0)
                    Button(role: .destructive) { deleting = url; confirmDelete = true } label: { Label("حذف", systemImage: "trash") }
                }.buttonStyle(.bordered).disabled(busy)
                if url.pathExtension.lowercased() == "mp4" {
                    Button { audio.saveVideoToPhotos(url) } label: {
                        Label(audio.savingToPhotos == url ? "جارٍ الحفظ في الصور…" : "حفظ في الصور", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.borderedProminent).disabled(busy)
                }
                }.padding(12).background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius))
            }
            Text("الفيديو تجريبي: جرّب مقطعًا قصيرًا للتحقق من تزامن الصوت والصورة على جهازك. تأخير سماعة البلوتوث في الاستماع لا يُضاف عمدًا إلى التسجيل.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: $playing) { item in RecordingPlayback(url: item.url) }
        .sheet(item: $saving) { item in RecordingSavePicker(url: item.url) }
        .alert("الحفظ في الصور", isPresented: Binding(get: { audio.photosNotice != nil }, set: { if !$0 { audio.photosNotice = nil } })) {
            Button("تم") { audio.photosNotice = nil }
        } message: { Text(audio.photosNotice ?? "") }
        .alert("حذف التسجيل؟", isPresented: $confirmDelete) {
            Button("حذف", role: .destructive) {
                if let url = deleting { audio.deleteRecording(url) }
                deleting = nil
            }
            Button("إلغاء", role: .cancel) { deleting = nil }
        } message: {
            Text("سيُحذف هذا الملف من تسجيلاتي والجوال. النسخ التي حفظتها في مكان آخر تبقى كما هي.\n" + (deleting?.lastPathComponent ?? ""))
        }
    }
}

private struct RecordingItem: Identifiable { let url: URL; var id: URL { url } }
private struct RecordingSavePicker: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
private struct RecordingPlayback: View {
    @State private var player: AVPlayer
    @Environment(\.dismiss) private var dismiss
    init(url: URL) { _player = State(initialValue: AVPlayer(url: url)) }
    var body: some View {
        NavigationStack {
            VideoPlayer(player: player).onAppear {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
            }.onDisappear { player.pause() }
                .toolbar { Button("تم") { dismiss() } }.navigationTitle("التسجيل")
        }
    }
}

private final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface(); view.preview.session = session; view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PreviewSurface, context: Context) {
        if let connection = view.preview.connection, connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
    }
}
