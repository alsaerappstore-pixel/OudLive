import AVFoundation
import CoreGraphics
import CoreText
import CoreImage

// All capture and writer state belongs to this serial queue, never the audio callback.
final class VideoRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "OudLive.camera")
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var firstPTS: CMTime?
    private var firstHost = 0.0
    private var failure: Error?
    private var accepting = false
    private var latestFrame: CVPixelBuffer?

    func prepare(url: URL, front: Bool, orientation: AVCaptureVideoOrientation = .portrait, completion: @escaping (Error?) -> Void) {
        queue.async {
            var configuring = false
            do {
                self.session.beginConfiguration()
                configuring = true
                #if os(iOS)
                self.session.automaticallyConfiguresApplicationAudioSession = false
                #endif
                #if os(iOS)
                self.session.sessionPreset = .inputPriority
                #else
                self.session.sessionPreset = .hd1280x720
                #endif
                var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
                #if os(iOS)
                types += [.builtInUltraWideCamera, .builtInTrueDepthCamera]
                #endif
                let cameras = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: front ? .front : .back).devices
                // Select field of view, not digital magnification. Prefer fewer pixels
                // when equally wide to leave processing headroom for live audio.
                let candidates = cameras.flatMap { device in
                    device.formats.filter { format in
                        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                        return d.width >= 640 && d.width <= 4096 && d.height >= 480 && d.height <= 3072 &&
                            format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
                    }.map { (device: device, format: $0) }
                }.sorted { a, b in
                    #if os(iOS)
                    if a.format.videoFieldOfView != b.format.videoFieldOfView { return a.format.videoFieldOfView > b.format.videoFieldOfView }
                    #endif
                    let x = CMVideoFormatDescriptionGetDimensions(a.format.formatDescription)
                    let y = CMVideoFormatDescriptionGetDimensions(b.format.formatDescription)
                    // With the same horizontal FOV, a taller sensor area shows more.
                    let ax = Double(x.height) / Double(x.width), ay = Double(y.height) / Double(y.width)
                    if ax != ay { return ax > ay }
                    return abs(Int(x.width) * Int(x.height) - 1920 * 1080) < abs(Int(y.width) * Int(y.height) - 1920 * 1080)
                }
                guard let chosen = candidates.first else { throw Self.error("الكاميرا غير متاحة.") }
                let camera = chosen.device
                let cameraInput = try AVCaptureDeviceInput(device: camera)
                guard self.session.canAddInput(cameraInput) else { throw Self.error("تعذّر توصيل الكاميرا.") }
                self.session.addInput(cameraInput)
                try camera.lockForConfiguration()
                camera.activeFormat = chosen.format
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                #if os(iOS)
                camera.videoZoomFactor = camera.minAvailableVideoZoomFactor
                #endif
                camera.unlockForConfiguration()
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                output.setSampleBufferDelegate(self, queue: self.queue)
                guard self.session.canAddOutput(output) else { throw Self.error("تعذّر تشغيل تصوير الفيديو.") }
                self.session.addOutput(output)
                if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = orientation
                    #if os(iOS)
                    if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
                    #endif
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = front
                    }
                }
                self.session.commitConfiguration()
                configuring = false
                let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: (orientation == .portrait || orientation == .portraitUpsideDown) ? 720 : 1280, AVVideoHeightKey: (orientation == .portrait || orientation == .portraitUpsideDown) ? 1280 : 720, AVVideoScalingModeKey: AVVideoScalingModeResizeAspect
                ])
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else { throw Self.error("تعذّر تجهيز ملف الفيديو.") }
                writer.add(input)
                self.writer = writer; self.input = input
                self.session.startRunning()
                guard self.session.isRunning else { throw Self.error("لم تبدأ الكاميرا. جرّب إغلاق تطبيقات الكاميرا الأخرى.") }
                DispatchQueue.main.async { completion(nil) }
            } catch {
                // It is safe to end an unfinished configuration before releasing this session.
                if configuring { self.session.commitConfiguration() }
                if self.session.isRunning { self.session.stopRunning() }
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    func begin() { queue.async { self.accepting = true } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestFrame = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard accepting, failure == nil, let writer, let input else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstPTS == nil {
            guard writer.startWriting() else { failure = writer.error ?? Self.error("تعذّر كتابة الفيديو."); return }
            writer.startSession(atSourceTime: pts)
            firstPTS = pts
            if let clock = session.masterClock {
                firstHost = CMTimeGetSeconds(CMSyncConvertTime(pts, from: clock, to: CMClockGetHostTimeClock()))
            } else {
                failure = Self.error("تعذّر مزامنة الكاميرا والصوت."); return
            }
        }
        if input.isReadyForMoreMediaData && !input.append(sampleBuffer) {
            failure = writer.error ?? Self.error("تعذّر استكمال الفيديو.")
        }
    }
    func finish(completion: @escaping (Result<Double, Error>) -> Void) {
        queue.async {
            self.accepting = false
            self.session.stopRunning()
            guard let writer = self.writer, let input = self.input, self.firstPTS != nil else {
                self.writer?.cancelWriting()
                DispatchQueue.main.async { completion(.failure(Self.error("التسجيل أقصر من أن يحتوي على صورة. حُفظ الصوت إن كان متاحًا."))) }
                return
            }
            if let failure = self.failure {
                writer.cancelWriting(); DispatchQueue.main.async { completion(.failure(failure)) }; return
            }
            input.markAsFinished()
            writer.finishWriting {
                let result: Result<Double, Error> = writer.status == .completed
                    ? .success(self.firstHost) : .failure(writer.error ?? Self.error("تعذّر حفظ الفيديو."))
                DispatchQueue.main.async { completion(result) }
            }
        }
    }
    static func jpeg(_ buffer: CVPixelBuffer) throws -> Data {
        let image = CIImage(cvPixelBuffer: buffer)
        guard let data = CIContext().jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw error("تعذّر تجهيز الصورة.")
        }
        return data
    }
    func snapshot(completion: @escaping (Result<Data, Error>) -> Void) {
        queue.async {
            let result = Result<Data, Error> {
                guard let frame = self.latestFrame else { throw Self.error("انتظر ظهور صورة الكاميرا أولًا.") }
                return try Self.jpeg(frame)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
    static func error(_ text: String) -> NSError {
        NSError(domain: "OudLive.Recording", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

enum RecordingExport {
    static func validateMovie(_ url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let video = try await asset.loadTracks(withMediaType: .video)
        guard duration.seconds.isFinite, duration.seconds > 0, !audio.isEmpty, !video.isEmpty else {
            throw VideoRecorder.error("ملف الفيديو غير مكتمل؛ احتُفظ بالصوت الأصلي.")
        }
    }
    static func audioOnlyAsset(_ url: URL) async throws -> AVMutableComposition {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw VideoRecorder.error("لم يوجد صوت في هذا التسجيل.") }
        let composition = AVMutableComposition()
        guard let output = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw VideoRecorder.error("تعذّر تشغيل الصوت.") }
        let range = try await track.load(.timeRange)
        try output.insertTimeRange(range, of: track, at: .zero)
        return composition
    }

    // A single reusable portrait cover; the original wet audio is never processed again.
    static func audioMovie(audio: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: audio)
        let duration = try await asset.load(.duration)
        guard duration.seconds.isFinite, duration.seconds > 0,
              !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw VideoRecorder.error("التسجيل الصوتي فارغ أو غير صالح.")
        }
        let cover = destination.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mov")
        defer { try? FileManager.default.removeItem(at: cover) }
        let writer = try AVAssetWriter(outputURL: cover, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 720, AVVideoHeightKey: 1280])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 720, kCVPixelBufferHeightKey as String: 1280])
        guard writer.canAdd(input) else { throw VideoRecorder.error("تعذّر تجهيز خلفية التسجيل.") }
        writer.add(input)
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 720, 1280, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else {
            throw VideoRecorder.error("تعذّر إنشاء صورة التسجيل.")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 720, height: 1280, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(buffer, []); throw VideoRecorder.error("تعذّر رسم خلفية التسجيل.")
        }
        context.setFillColor(CGColor(red: 0.04, green: 0.07, blue: 0.08, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 720, height: 1280))
        let ink = CGColor(red: 1, green: 0.72, blue: 0.4, alpha: 1)
        context.setStrokeColor(ink); context.setLineWidth(3); context.strokeEllipse(in: CGRect(x: 260, y: 790, width: 200, height: 240))
        for x in stride(from: 330, through: 390, by: 12) { context.move(to: CGPoint(x: CGFloat(x), y: 770)); context.addLine(to: CGPoint(x: CGFloat(x), y: 1110)); context.strokePath() }
        func title(_ text: String, size: CGFloat, y: CGFloat) {
            let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            context.textPosition = CGPoint(x: (720 - width) / 2, y: y); CTLineDraw(line, context)
        }
        title("عود لايف", size: 62, y: 650); title("تسجيل صوتي", size: 30, y: 570)
        title("ياسر الغامدي", size: 38, y: 480)
        title("جميع الحقوق محفوظة © ياسر الغامدي", size: 22, y: 120)
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard writer.startWriting() else { throw writer.error ?? VideoRecorder.error("تعذّر بدء التحويل.") }
        writer.startSession(atSourceTime: .zero)
        do {
            var frame: Int64 = 0
            while Double(frame) / 2 < duration.seconds {
                try Task.checkCancellation()
                let deadline = Date().addingTimeInterval(60)
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing, Date() < deadline else { throw writer.error ?? VideoRecorder.error("توقف تجهيز الفيديو. حاول مجددًا.") }
                    try await Task.sleep(nanoseconds: 5_000_000)
                }
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: frame, timescale: 2)) else { throw writer.error ?? VideoRecorder.error("تعذّر كتابة خلفية الفيديو.") }
                frame += 1
            }
            writer.endSession(atSourceTime: duration); input.markAsFinished(); await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? VideoRecorder.error("لم يكتمل التحويل.") }
            try Task.checkCancellation()
            // Equal positive synthetic origins preserve alignment while keeping
            // the real camera path's missing-host-clock validation intact.
            try await combine(audio: audio, video: cover, audioStart: 1, videoStart: 1, destination: destination)
        } catch { writer.cancelWriting(); throw error }
    }
    // Camera and RemoteIO timestamps use the host clock. Trim to their overlap;
    // do not add Bluetooth playback delay to the media file.
    static func combine(audio: URL, video: URL, audioStart: Double, videoStart: Double, destination: URL) async throws {
        let sound = AVURLAsset(url: audio), picture = AVURLAsset(url: video)
        guard let audioTrack = try await sound.loadTracks(withMediaType: .audio).first,
              let videoTrack = try await picture.loadTracks(withMediaType: .video).first else {
            throw VideoRecorder.error("لم يتوفر صوت وصورة صالحان للدمج. التسجيل الصوتي محفوظ.")
        }
        let soundDuration = try await sound.load(.duration)
        let videoDuration = try await picture.load(.duration)
        guard let timing = RecordingTiming(audioStart: audioStart, videoStart: videoStart,
                                           audioDuration: soundDuration.seconds, videoDuration: videoDuration.seconds) else {
            throw VideoRecorder.error("لم تتوفر مدة مشتركة صالحة للصوت والصورة. جرّب تسجيلًا أطول.")
        }
        let composition = AVMutableComposition()
        guard let a = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let v = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoRecorder.error("تعذّر تجهيز الفيديو النهائي.")
        }
        let length = CMTime(seconds: timing.duration, preferredTimescale: 60000)
        try a.insertTimeRange(CMTimeRange(start: CMTime(seconds: timing.audioTrim, preferredTimescale: 60000), duration: length), of: audioTrack, at: .zero)
        try v.insertTimeRange(CMTimeRange(start: CMTime(seconds: timing.videoTrim, preferredTimescale: 60000), duration: length), of: videoTrack, at: .zero)
        v.preferredTransform = try await videoTrack.load(.preferredTransform)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) else {
            throw VideoRecorder.error("تعذّر تشغيل دمج الفيديو.")
        }
        exporter.outputURL = destination; exporter.outputFileType = .mp4
        let credit = AVMutableMetadataItem()
        credit.identifier = .commonIdentifierCopyrights; credit.value = "جميع الحقوق محفوظة © ياسر الغامدي" as NSString
        exporter.metadata = [credit]
        exporter.shouldOptimizeForNetworkUse = true
        await exporter.export()
        guard exporter.status == .completed else { throw exporter.error ?? VideoRecorder.error("لم يكتمل دمج الفيديو. الصوت محفوظ.") }
    }
}
