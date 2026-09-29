import AVFoundation
import Combine
import UIKit

@MainActor
final class AudioModel: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var starting = false
    @Published private(set) var settings = SoundSettings()
    @Published private(set) var mode = SoundMode.oud
    @Published var message = "وصّل سماعتك بالبلوتوث أو بالسلك، ثم ابدأ."
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
        mode = saved.mode; settings = mode == .oud ? saved.oud : saved.voice
        // Do not restore mute/bypass implicitly; the engine is always stopped on launch.
        settings[.mute] = 0; settings[.bypass] = 0; stableBuffer = saved.stableBuffer
        apply()
        savedFavorite = UserDefaults.standard.data(forKey: "OudLive.favorite.v2") != nil
        Timer.publish(every: 0.07, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.running else { return }
            self.inputLevel = self.bridge.inputPeak; self.outputLevel = self.bridge.outputPeak
            self.limitingDB = self.bridge.gainReduction
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
            if self.running && (self.routeKey != self.activeRouteKey || !self.safeOutput) {
                self.stop(); self.message = "تغيّر توصيل الصوت. تحقق من السماعة ثم اضغط ابدأ."
            }
            self.refreshRoute()
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
        favorite[.input] = settings[.input]; favorite[.output] = settings[.output]; favorite[.mute] = settings[.mute]
        settings = favorite; apply(); save()
    }
    func set(_ parameter: Parameter, _ value: Double) {
        settings[parameter] = value
        if parameter != .mute && parameter != .bypass && parameter != .output && parameter != .input { settings.preset = "مخصص" }
        bridge.setParameter(parameter.rawValue, value: Float(settings[parameter])); save()
    }
    func choosePreset(_ name: String) {
        let input = settings[.input], output = settings[.output], mute = settings[.mute]
        settings = .preset(name, mode: mode)
        settings[.input] = input; settings[.output] = output; settings[.mute] = mute
        apply(); save()
    }
    func chooseMode(_ newMode: SoundMode) {
        guard newMode != mode else { return }
        let mute = settings[.mute], input = settings[.input], output = settings[.output]
        save(); mode = newMode; settings = mode == .oud ? saved.oud : saved.voice
        settings[.mute] = mute; settings[.input] = input; settings[.output] = output
        apply(); save()
    }
    private func apply() {
        for p in Parameter.allCases { bridge.setParameter(p.rawValue, value: Float(settings[p])) }
    }
    private func save() {
        if mode == .oud { saved.oud = settings } else { saved.voice = settings }
        saved.mode = mode; saved.stableBuffer = stableBuffer
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: storageKey) }
    }
    func toggle() {
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
                let usingBluetooth = session.currentRoute.outputs.contains { $0.portType == .bluetoothA2DP }
                let phoneMic = session.availableInputs?.first { $0.portType == .builtInMic }
                try session.setPreferredInput(usingBluetooth ? phoneMic : nil)
            }
            refreshRoute()
            guard safeOutput else {
                stop(); message = "اختر سماعة Bluetooth من مركز التحكم، أو وصّل سماعة سلكية أو USB، ثم اضغط ابدأ. مكبر الآيفون غير مفعّل لتجنب الصفير."
                return
            }
            guard session.isInputAvailable else { stop(); message = "لا يوجد ميكروفون متاح."; return }
            // NSError convention imports the Objective-C method as a throwing Swift method.
            try bridge.start(withSampleRate: session.sampleRate)
            activeRouteKey = routeKey
            running = true; UIApplication.shared.isIdleTimerDisabled = true
            message = bluetoothOutput
                ? "الصوت إلى سماعة البلوتوث • الالتقاط من \(inputRoute). يوجد تأخير من البلوتوث؛ السلك أسرع للعزف."
                : "الصوت مباشر • ابدأ بمستوى منخفض وارفعه تدريجيًا."
        } catch {
            stop(); message = error.localizedDescription
        }
    }
    func stop() {
        generation += 1; starting = false; bridge.stop(); running = false
        inputLevel = 0; outputLevel = 0; limitingDB = 0; UIApplication.shared.isIdleTimerDisabled = false
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
