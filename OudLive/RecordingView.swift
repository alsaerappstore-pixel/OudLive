import SwiftUI
import AVKit

@MainActor
struct RecordingView: View {
    @ObservedObject var audio: AudioModel
    @State private var video = false
    @State private var front = false
    @State private var playing: RecordingItem?
    private var busy: Bool { audio.recording || audio.recordingPreparing || audio.recordingFinishing }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("سجّل عزفك").font(.title2.bold())
            Text("يحفظ الصوت بعد المؤثرات، بما فيها التعديلات أثناء العزف. الكتم ومستوى الخروج يدخلان في التسجيل.")
                .font(.subheadline).foregroundStyle(.secondary)
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
                .disabled(audio.recordingFinishing || (!audio.running && !audio.recordingPreparing))
            if !audio.running { Text("اضغط «ابدأ العزف» أولًا ووصل سماعتك، ثم ابدأ التسجيل.").font(.caption) }
            if audio.recordingFinishing { ProgressView("جارٍ حفظ التسجيل…") }
            Text("تسجيلاتي").font(.headline)
            if audio.recordings.isEmpty {
                Text("تظهر تسجيلاتك هنا بعد إيقاف التسجيل. تبقى على الآيفون حتى تشاركها بنفسك.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(audio.recordings, id: \.self) { url in
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
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                        .disabled(busy).accessibilityLabel("مشاركة أو حفظ التسجيل في الملفات")
                }.padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            }
            Text("الفيديو تجريبي: جرّب مقطعًا قصيرًا للتحقق من تزامن الصوت والصورة على جهازك. تأخير سماعة البلوتوث في الاستماع لا يُضاف عمدًا إلى التسجيل.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: $playing) { item in RecordingPlayback(url: item.url) }
    }
}

private struct RecordingItem: Identifiable { let url: URL; var id: URL { url } }
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
