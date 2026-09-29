import AVFoundation
import Combine
import UIKit

@MainActor
final class AudioModel: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var starting = false
    @Published private(set) var settings = SoundSettings()
    @Published private(set) var mode = SoundMode.oud
    @Published var message = "وصّل سماعة سلكية أو واجهة USB، ثم ابدأ."
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var outputLevel: Float = 0
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

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(SavedSettings.self, from: data), stored.valid {
            saved = stored
        }
        mode = saved.mode; settings = mode == .oud ? saved.oud : saved.voice
        // Do not restore mute/bypass implicitly; the engine is always stopped on launch.
        settings[.mute] = 0; settings[.bypass] = 0; stableBuffer = saved.stableBuffer
        apply()
        Timer.publish(every: 0.07, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.running else { return }
            self.inputLevel = self.bridge.inputPeak; self.outputLevel = self.bridge.outputPeak
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
            [AVAudioSession.Port.headphones, .usbAudio, .lineOut].contains($0.portType)
        }
    }
    private var routeKey: String {
        (session.currentRoute.inputs + session.currentRoute.outputs).map(\.uid).joined(separator: "|") + "|\(session.sampleRate)"
    }
    func value(_ parameter: Parameter) -> Double { settings[parameter] }
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
            try session.setCategory(.playAndRecord, mode: .measurement, options: [])
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration((stableBuffer ? 256.0 : 128.0) / 48000.0)
            try session.setActive(true)
            if !selectedInput.isEmpty, let port = session.availableInputs?.first(where: { $0.uid == selectedInput }) {
                try session.setPreferredInput(port)
            } else if selectedInput.isEmpty { try session.setPreferredInput(nil) }
            refreshRoute()
            guard safeOutput else {
                stop(); message = "وصّل سماعة سلكية أو واجهة USB. مكبر الآيفون وBluetooth غير مفعّلين للمراقبة المباشرة لتجنب الصفير والتأخير."
                return
            }
            guard session.isInputAvailable else { stop(); message = "لا يوجد ميكروفون متاح."; return }
            // NSError convention imports the Objective-C method as a throwing Swift method.
            try bridge.start(withSampleRate: session.sampleRate)
            activeRouteKey = routeKey
            running = true; UIApplication.shared.isIdleTimerDisabled = true
            message = "الصوت مباشر • ابدأ بمستوى منخفض وارفعه تدريجيًا."
        } catch {
            stop(); message = error.localizedDescription
        }
    }
    func stop() {
        generation += 1; starting = false; bridge.stop(); running = false
        inputLevel = 0; outputLevel = 0; UIApplication.shared.isIdleTimerDisabled = false
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func refreshRoute() {
        inputs = session.availableInputs ?? []
        route = session.currentRoute.outputs.map(\.portName).joined(separator: "، ")
        sampleRate = session.sampleRate; bufferMS = session.ioBufferDuration * 1000
        hardwareMS = (session.inputLatency + session.outputLatency) * 1000
    }
}
