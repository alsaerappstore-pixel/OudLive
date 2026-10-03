import AVFoundation
import Combine
import UIKit
import Photos

@MainActor
final class AudioModel: ObservableObject {
    @Published private(set) var savingToPhotos: URL?
    @Published var photosNotice: String?
    private var photoExportTask: Task<Void, Never>?
    func saveVideoToPhotos(_ url: URL) {
        guard savingToPhotos == nil, !recording, !recordingPreparing, !recordingFinishing,
              recordings.contains(url), ["mp4", "wav"].contains(url.pathExtension.lowercased()),
              FileManager.default.fileExists(atPath: url.path) else { return }
        savingToPhotos = url
        photoExportTask = Task {
            let background = UIApplication.shared.beginBackgroundTask(withName: "Save recording to Photos") { [weak self] in self?.photoExportTask?.cancel() }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("OudLive-Photos-" + UUID().uuidString, isDirectory: true)
            defer {
                try? FileManager.default.removeItem(at: temporary)
                if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
                savingToPhotos = nil; photoExportTask = nil
            }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                photosNotice = "لم يُسمح بالحفظ في الصور. من إعدادات الآيفون افتح عود لايف ثم الصور واسمح بإضافة الصور. الفيديو ما زال محفوظًا في تسجيلاتي."
                return
            }
            do {
                try Task.checkCancellation()
                var movie = url
                if url.pathExtension.lowercased() == "wav" {
                    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
                    movie = temporary.appendingPathComponent("OudLive.mp4")
                    try await RecordingExport.audioMovie(audio: url, destination: movie)
                }
                try Task.checkCancellation()
                let finishedMovie = movie
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: finishedMovie, options: nil)
                }
                photosNotice = "تم حفظ الفيديو بصوت التأثيرات في تطبيق الصور. النسخة الأصلية ما زالت في تسجيلاتي."
            } catch {
                photosNotice = "تعذّر الحفظ في الصور: \(error.localizedDescription). الأصل ما زال في تسجيلاتي؛ أبقِ التطبيق مفتوحًا وأعد المحاولة."
            }
        }
    }
    @Published private(set) var comparison: NamedSound?
    @Published private(set) var comparingA = false
    func captureComparison() {
        comparison = NamedSound(name: settings.preset, mode: mode, settings: settings)
        comparingA = false
    }
    func swapComparison() {
        guard let target = comparison else { return }
        let current = NamedSound(name: settings.preset, mode: mode, settings: settings)
        loadSound(target); comparison = current; comparingA.toggle()
    }
    @Published private(set) var monitoring = false
    @Published private(set) var recordingLevel: Float = 0
    @Published private(set) var recordingLimiting: Float = 0
    @Published private(set) var recording = false
    @Published private(set) var recordingPreparing = false
    @Published private(set) var recordingFinishing = false
    @Published private(set) var recordingSeconds = 0
    @Published private(set) var recordings: [URL] = []
    @Published private(set) var cameraSession: AVCaptureSession?
    private var camera: VideoRecorder?
    private var recordingURL: URL?
    private var cameraURL: URL?
    private var recordingDate: Date?
    private var recordingGeneration = 0
    private var exportBackground = UIBackgroundTaskIdentifier.invalid
    @Published private(set) var namedSounds: [NamedSound] = []
    @Published private(set) var running = false
    @Published private(set) var starting = false
    @Published private(set) var settings = SoundSettings()
    @Published private(set) var mode = SoundMode.oud
    @Published var message = "يمكنك التسجيل دون سماعة، أو توصيل سماعة للاستماع المباشر."
    @Published private(set) var bluetoothOutput = false
    @Published private(set) var inputRoute = ""
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var outputLevel: Float = 0
    @Published private(set) var limitingDB: Float = 0
    @Published private(set) var savedFavorite = false
    @Published private(set) var route = "لم يبدأ الصوت"
    @Published private(set) var bufferMS = 0.0
    @Published private(set) var hardwareMS = 0.0
    @Published private(set) var sampleRate = 0.0
    @Published private(set) var inputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput = "" {
        didSet { if oldValue != selectedInput && running { stop(); message = "تغيّر الميكروفون. اضغط ابدأ لتطبيقه." } }
    }
    @Published var stableBuffer = false { didSet { save(); if running { stop(); message = "اضغط ابدأ لتطبيق زمن المخزن الجديد." } } }
    private var saved = SavedSettings()
    private let bridge = AudioBridge()
    private let session = AVAudioSession.sharedInstance()
    private var subscriptions = Set<AnyCancellable>()
    private let storageKey = "OudLive.settings.v1"
    private var generation = 0
    private var activeRouteKey = ""
    private var lastTap: Date?

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(SavedSettings.self, from: data), stored.valid {
            saved = stored
        }
        if let data = UserDefaults.standard.data(forKey: "OudLive.namedSounds.v1"),
           let sounds = try? JSONDecoder().decode([NamedSound].self, from: data) {
            namedSounds = sounds.filter { $0.settings.valid }
        }
        mode = saved.mode; settings = mode == .oud ? saved.oud : saved.voice
        // Do not restore mute/bypass implicitly; the engine is always stopped on launch.
        settings[.mute] = 0; settings[.bypass] = 0; stableBuffer = saved.stableBuffer
        apply(); refreshRecordings()
        savedFavorite = UserDefaults.standard.data(forKey: "OudLive.favorite.v2") != nil
        Timer.publish(every: 0.07, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.running else { return }
            self.inputLevel = self.bridge.inputPeak; self.outputLevel = self.monitoring ? self.bridge.outputPeak : 0
            self.recordingLevel = self.bridge.recordingPeak; self.recordingLimiting = self.bridge.recordingReduction
            self.limitingDB = self.bridge.gainReduction
            if self.recording, let start = self.recordingDate {
                self.recordingSeconds = Int(Date().timeIntervalSince(start))
                if self.bridge.recordingError != 0 { self.finishRecording() }
            }
            if self.bridge.renderError != 0 {
                let code = self.bridge.renderError
                self.stop(); self.message = "توقّف الصوت بسبب الملحق (\(code)). جرّب وضع الاستقرار ثم أعد التشغيل."
            }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main).sink { [weak self] note in
            guard let self, let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            self.stop(); self.message = "توقّف الصوت للمكالمة أو المقاطعة. اضغط ابدأ بعد انتهائها."
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            // Ignore queued notifications caused by our own start configuration.
            // Stop only when the route actually differs from the one we started.
            if !self.safeOutput { self.bridge.setMonitoringEnabled(false); self.monitoring = false }
            if self.running && self.routeKey != self.activeRouteKey {
                self.stop(); self.message = "تغيّر التوصيل. حُفظ التسجيل إن كان جاريًا؛ يمكنك البدء مجددًا مع السماعة أو بدونها."
            }
            if self.running {
                self.monitoring = self.safeOutput
                self.bridge.setMonitoringEnabled(self.monitoring)
            }
            self.refreshRoute()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            if self.recording || self.recordingPreparing { self.finishRecording() }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.stop(); self?.message = "أُعيد تشغيل خدمة الصوت. اضغط ابدأ مجددًا."
        }.store(in: &subscriptions)
    }
    private var safeOutput: Bool {
        !session.currentRoute.outputs.isEmpty && session.currentRoute.outputs.allSatisfy {
            [AVAudioSession.Port.headphones, .usbAudio, .lineOut, .bluetoothA2DP].contains($0.portType)
        }
    }
    private var routeKey: String {
        (session.currentRoute.inputs + session.currentRoute.outputs).map(\.uid).joined(separator: "|") + "|\(session.sampleRate)"
    }
    func value(_ parameter: Parameter) -> Double { settings[parameter] }
    func boostInput() { set(.input, min(30, value(.input) + 6)) }
    func tapTempo() {
        let now = Date()
        if let previous = lastTap {
            let milliseconds = now.timeIntervalSince(previous) * 1000
            if (80...1200).contains(milliseconds) { set(.delayTime, milliseconds) }
        }
        lastTap = now
    }
    func saveFavorite() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "OudLive.favorite.v2"); savedFavorite = true
            message = "حُفظ لونك المفضل. استعده من زر مفضلتي."
        }
    }
    func loadFavorite() {
        guard let data = UserDefaults.standard.data(forKey: "OudLive.favorite.v2"),
              var favorite = try? JSONDecoder().decode(SoundSettings.self, from: data), favorite.valid else { return }
        favorite[.recordGain] = settings[.recordGain]
        favorite[.input] = settings[.input]; favorite[.output] = settings[.output]; favorite[.mute] = settings[.mute]
        settings = favorite; apply(); save()
    }
    func set(_ parameter: Parameter, _ value: Double) {
        settings[parameter] = value
        if parameter != .mute && parameter != .bypass && parameter != .output && parameter != .input && parameter != .recordGain { settings.preset = "مخصص" }
        bridge.setParameter(parameter.rawValue, value: Float(settings.effective(parameter))); save()
    }
    func setEnabled(_ effect: Effect, _ enabled: Bool) {
        if enabled { settings.disabledEffects.remove(effect) }
        else { settings.disabledEffects.insert(effect) }
        settings.preset = "مخصص"; apply(); save()
    }
    func saveSound(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else { return }
        namedSounds.append(NamedSound(name: trimmed, mode: mode, settings: settings))
        persistSounds(); message = "حُفظ الصوت باسم \(trimmed)."
    }
    func loadSound(_ sound: NamedSound) {
        let input = settings[.input], output = settings[.output], mute = settings[.mute], recordGain = settings[.recordGain]
        save(); mode = sound.mode; settings = sound.settings; settings.preset = sound.name
        settings[.input] = input; settings[.output] = output; settings[.mute] = mute; settings[.bypass] = 0
        settings[.recordGain] = recordGain
        apply(); save()
    }
    func deleteSound(_ id: UUID) { namedSounds.removeAll { $0.id == id }; persistSounds() }
    private func persistSounds() {
        if let data = try? JSONEncoder().encode(namedSounds) { UserDefaults.standard.set(data, forKey: "OudLive.namedSounds.v1") }
    }
    func choosePreset(_ name: String) {
        let input = settings[.input], output = settings[.output], mute = settings[.mute], recordGain = settings[.recordGain]
        settings = .preset(name, mode: mode)
        settings[.input] = input; settings[.output] = output; settings[.mute] = mute
        settings[.recordGain] = recordGain
        apply(); save()
    }
    func chooseMode(_ newMode: SoundMode) {
        guard newMode != mode else { return }
        let mute = settings[.mute], input = settings[.input], output = settings[.output], recordGain = settings[.recordGain]
        save(); mode = newMode; settings = mode == .oud ? saved.oud : saved.voice
        settings[.mute] = mute; settings[.input] = input; settings[.output] = output
        settings[.recordGain] = recordGain
        apply(); save()
    }
    private func apply() {
        for p in Parameter.allCases { bridge.setParameter(p.rawValue, value: Float(settings.effective(p))) }
    }
    private func save() {
        if mode == .oud { saved.oud = settings } else { saved.voice = settings }
        saved.mode = mode; saved.stableBuffer = stableBuffer
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: storageKey) }
    }
    func toggle() {
        if recordingPreparing { finishRecording(); return }
        if running || starting { stop(); return }
        starting = true; generation += 1; let request = generation
        session.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, self.generation == request else { return }
                self.starting = false
                guard granted else { self.message = "اسمح بالميكروفون من إعدادات iPhone ← عود لايف ← الميكروفون."; return }
                self.start()
            }
        }
    }
    private func start() {
        do {
            // A2DP preserves music-quality output while recording the phone/USB mic.
            // Do not enable HFP: that would switch headphones to call-quality audio.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothA2DP])
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration((stableBuffer ? 256.0 : 128.0) / 48000.0)
            try session.setActive(true)
            if !selectedInput.isEmpty, let port = session.availableInputs?.first(where: { $0.uid == selectedInput }) {
                try session.setPreferredInput(port)
            } else {
                let phoneMic = session.availableInputs?.first { $0.portType == .builtInMic }
                let usbMic = session.availableInputs?.first { $0.portType == .usbAudio }
                try session.setPreferredInput(usbMic ?? phoneMic)
            }
            refreshRoute()
            monitoring = safeOutput
            bridge.setMonitoringEnabled(monitoring)
            guard session.isInputAvailable else { stop(); message = "لا يوجد ميكروفون متاح."; return }
            // NSError convention imports the Objective-C method as a throwing Swift method.
            try bridge.start(withSampleRate: session.sampleRate)
            activeRouteKey = routeKey
            running = true; UIApplication.shared.isIdleTimerDisabled = true
            message = !monitoring ? "جاهز للتسجيل دون سماعة • مكبر الآيفون صامت، والمؤثرات محفوظة في التسجيل." : bluetoothOutput
                ? "الصوت إلى سماعة البلوتوث • الالتقاط من \(inputRoute). يوجد تأخير من البلوتوث؛ السلك أسرع للعزف."
                : "الصوت مباشر • ابدأ بمستوى منخفض وارفعه تدريجيًا."
        } catch {
            stop(); message = error.localizedDescription
        }
    }
    func stop() {
        if recording || recordingPreparing { finishRecording() }
        generation += 1; starting = false; bridge.stop(); running = false
        inputLevel = 0; outputLevel = 0; limitingDB = 0; recordingLevel = 0; recordingLimiting = 0; monitoring = false; bridge.setMonitoringEnabled(false); UIApplication.shared.isIdleTimerDisabled = false
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func refreshRoute() {
        inputs = session.availableInputs ?? []
        route = session.currentRoute.outputs.map(\.portName).joined(separator: "، ")
        inputRoute = session.currentRoute.inputs.map(\.portName).joined(separator: "، ")
        bluetoothOutput = session.currentRoute.outputs.contains { $0.portType == .bluetoothA2DP }
        sampleRate = session.sampleRate; bufferMS = session.ioBufferDuration * 1000
        hardwareMS = (session.inputLatency + session.outputLatency) * 1000
    }
}

extension AudioModel {
    private var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings", isDirectory: true)
    }
    func refreshRecordings() {
        recordings = ((try? FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["wav", "mp4"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    func deleteRecording(_ url: URL) {
        guard !recording, !recordingPreparing, !recordingFinishing,
              recordings.contains(url), url.isFileURL,
              url.resolvingSymlinksInPath().deletingLastPathComponent() == recordingsDirectory.resolvingSymlinksInPath() else { return }
        do {
            try FileManager.default.removeItem(at: url)
            refreshRecordings(); message = "حُذف التسجيل المحدد."
        } catch { message = "تعذّر حذف التسجيل: \(error.localizedDescription)" }
    }
    func beginRecording(video: Bool, front: Bool) {
        guard !starting, !recording, !recordingPreparing, !recordingFinishing else {
            message = "انتظر انتهاء التجهيز أو حفظ التسجيل السابق."; return
        }
        recordingPreparing = true; recordingGeneration += 1; let token = recordingGeneration
        Task {
            if !running {
                let allowed: Bool = await withCheckedContinuation { continuation in
                    session.requestRecordPermission { continuation.resume(returning: $0) }
                }
                guard recordingGeneration == token, recordingPreparing else { return }
                guard allowed else { recordingPreparing = false; message = "اسمح بالميكروفون من إعدادات الآيفون."; return }
                start()
                guard running else { recordingPreparing = false; return }
            }
            if video {
                let allowed = await AVCaptureDevice.requestAccess(for: .video)
                guard recordingGeneration == token, recordingPreparing else { return }
                guard allowed else { recordingPreparing = false; message = "اسمح بالكاميرا من إعدادات الآيفون؛ التسجيل الصوتي متاح دونها."; return }
            }
            guard running, recordingGeneration == token, recordingPreparing else {
                if recordingGeneration == token { recordingPreparing = false }; return
            }
            do {
                try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
                let date = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let name = "OudLive-" + date + "-" + UUID().uuidString.prefix(6)
                let audioURL = recordingsDirectory.appendingPathComponent(name + ".wav")
                if video {
                    let camera = VideoRecorder()
                    let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".mov")
                    self.camera = camera; cameraSession = camera.session
                    camera.prepare(url: videoURL, front: front) { [weak self] error in
                        guard let self else { return }
                        guard self.running, self.recordingPreparing, self.recordingGeneration == token else {
                            camera.finish { _ in try? FileManager.default.removeItem(at: videoURL) }; return
                        }
                        if let error {
                            self.recordingPreparing = false; self.camera = nil; self.cameraSession = nil
                            try? FileManager.default.removeItem(at: videoURL)
                            self.message = error.localizedDescription; return
                        }
                        self.startRecordingFile(audioURL, cameraURL: videoURL)
                    }
                } else { startRecordingFile(audioURL, cameraURL: nil) }
            } catch { recordingPreparing = false; message = error.localizedDescription }
        }
    }
    private func startRecordingFile(_ url: URL, cameraURL: URL?) {
        do {
            try bridge.beginRecording(at: url)
            recordingURL = url; self.cameraURL = cameraURL
            recordingDate = Date(); recordingSeconds = 0; recording = true; recordingPreparing = false
            camera?.begin()
            message = cameraURL == nil ? "يسجّل الصوت المعالج الآن. مستوى التسجيل مستقل عن مستوى السماعة وكتمها." : "يسجّل الفيديو والصوت المعالج. أبقِ التطبيق مفتوحًا والهاتف عموديًا."
        } catch {
            recordingPreparing = false; message = error.localizedDescription
            camera?.finish { _ in if let cameraURL { try? FileManager.default.removeItem(at: cameraURL) } }
            camera = nil; cameraSession = nil
            try? FileManager.default.removeItem(at: url)
        }
    }
    func finishRecording() {
        recordingGeneration += 1
        if recordingPreparing {
            recordingPreparing = false; cameraSession = nil; camera = nil; return
        }
        guard recording, let audioURL = recordingURL else { return }
        recording = false; recordingFinishing = true
        var audioError: Error?
        do { try bridge.finishRecording() } catch { audioError = error }
        let audioStart = bridge.recordingStartHostSeconds
        if audioStart == 0 {
            audioError = VideoRecorder.error("التسجيل قصير جدًا. انتظر لحظة قبل إيقافه.")
            try? FileManager.default.removeItem(at: audioURL)
        }
        recordingURL = nil; recordingDate = nil
        let camera = self.camera, videoURL = cameraURL
        self.camera = nil; cameraURL = nil; cameraSession = nil
        refreshRecordings()
        guard let camera, let videoURL else {
            recordingFinishing = false
            message = audioError?.localizedDescription ?? "حُفظ التسجيل الصوتي بنفس المؤثرات. افتح التسجيل أو شاركه من قائمة تسجيلاتي."
            return
        }
        exportBackground = UIApplication.shared.beginBackgroundTask(withName: "FinishRecording") { [weak self] in
            guard let self else { return }
            if self.exportBackground != .invalid { UIApplication.shared.endBackgroundTask(self.exportBackground); self.exportBackground = .invalid }
            self.message = "افتح التطبيق لإكمال تجهيز الفيديو. النسخة الصوتية محفوظة."
        }
        message = "جارٍ تجهيز الفيديو بالصوت المعالج…"
        camera.finish { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                defer {
                    if self.exportBackground != .invalid { UIApplication.shared.endBackgroundTask(self.exportBackground); self.exportBackground = .invalid }
                    self.recordingFinishing = false; self.refreshRecordings()
                    try? FileManager.default.removeItem(at: videoURL)
                }
                let destination = audioURL.deletingPathExtension().appendingPathExtension("mp4")
                do {
                    if let audioError { throw audioError }
                    let videoStart = try result.get()
                    try await RecordingExport.combine(audio: audioURL, video: videoURL, audioStart: audioStart, videoStart: videoStart, destination: destination)
                    self.message = "حُفظ الفيديو بصوت التأثيرات، ومعه نسخة صوتية منفصلة."
                } catch {
                    try? FileManager.default.removeItem(at: destination)
                    self.message = "تعذّر تجهيز الفيديو: \(error.localizedDescription) راجع النسخة الصوتية في تسجيلاتي."
                }
            }
        }
    }
}
