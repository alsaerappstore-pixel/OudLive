import AVFoundation
import Foundation
import ImageIO

@main struct ExportTest {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("sound.wav")
        let video = root.appendingPathComponent("picture.mov")
        let result = root.appendingPathComponent("result.mp4")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        var file: AVAudioFile? = try AVAudioFile(forWriting: audio, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000)!
        buffer.frameLength = 96000
        for channel in 0..<2 {
            for frame in 0..<96000 { buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 48000)) * 0.15 }
        }
        try file!.write(from: buffer); file = nil
        let writer = try AVAssetWriter(outputURL: video, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 720, AVVideoHeightKey: 1280])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 720, kCVPixelBufferHeightKey as String: 1280])
        writer.add(input); precondition(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        precondition(CVPixelBufferCreate(kCFAllocatorDefault, 720, 1280, kCVPixelFormatType_32ARGB, nil, &pixel) == kCVReturnSuccess)
        CVPixelBufferLockBaseAddress(pixel!, [])
        memset(CVPixelBufferGetBaseAddress(pixel!), 64, CVPixelBufferGetDataSize(pixel!))
        CVPixelBufferUnlockBaseAddress(pixel!, [])
        let jpeg = try VideoRecorder.jpeg(pixel!)
        let source = CGImageSourceCreateWithData(jpeg as CFData, nil)!
        let photo = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        precondition(photo.width == 720 && photo.height == 1280)
        print("PASS: camera snapshot encodes a decodable full-size JPEG")
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData {
                precondition(writer.status == .writing)
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            precondition(adaptor.append(pixel!, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished(); await writer.finishWriting()
        precondition(writer.status == .completed)
        try await RecordingExport.combine(audio: audio, video: video, audioStart: 10, videoStart: 10.25, destination: result)
        let asset = AVURLAsset(url: result)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        let videos = try await asset.loadTracks(withMediaType: .video)
        precondition(audios.count == 1 && videos.count == 1)
        let duration = try await asset.load(.duration).seconds
        precondition(abs(duration - 1.75) < 0.1)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: audios[0], outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false])
        reader.add(output); precondition(reader.startReading())
        var energy: Float = 0
        while let sample = output.copyNextSampleBuffer(), let data = CMSampleBufferGetDataBuffer(sample) {
            let count = CMBlockBufferGetDataLength(data) / 4
            var values = [Float](repeating: 0, count: count)
            let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: count * 4, destination: $0.baseAddress!) }
            precondition(status == kCMBlockBufferNoErr)
            for value in values { energy += value * value }
        }
        precondition(reader.status == .completed && energy > 1)
        print("PASS: MP4 exports one video and supplied audio track, trims offset and decodes non-silent audio")
        try await RecordingExport.validateMovie(result)
        let soundOnly = try await RecordingExport.audioOnlyAsset(result)
        let soundOnlyTracks = try await soundOnly.loadTracks(withMediaType: .audio)
        let noVideo = try await soundOnly.loadTracks(withMediaType: .video)
        let soundOnlyDuration = try await soundOnly.load(.duration).seconds
        precondition(soundOnlyTracks.count == 1 && noVideo.isEmpty && abs(soundOnlyDuration - duration) < 0.03)
        do { try await RecordingExport.validateMovie(audio); preconditionFailure("WAV must not permit intermediate deletion") } catch {}
        print("PASS: a single MP4 supports audio-only playback without a video track; incomplete movies fail validation before source cleanup")
        let audioMovie = root.appendingPathComponent("audio-cover.mp4")
        try await RecordingExport.audioMovie(audio: audio, destination: audioMovie)
        let coverAsset = AVURLAsset(url: audioMovie)
        let coverDuration = try await coverAsset.load(.duration).seconds
        let coverAudio = try await coverAsset.loadTracks(withMediaType: .audio)
        let coverVideo = try await coverAsset.loadTracks(withMediaType: .video)
        precondition(abs(coverDuration - 2) < 0.08 && coverAudio.count == 1 && coverVideo.count == 1)
        let size = try await coverVideo[0].load(.naturalSize)
        precondition(size.width == 720 && size.height == 1280)
        let coverReader = try AVAssetReader(asset: coverAsset)
        let samples = AVAssetReaderTrackOutput(track: coverAudio[0], outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false])
        coverReader.add(samples); precondition(coverReader.startReading())
        var power: Double = 0; var sampleCount = 0
        while let sample = samples.copyNextSampleBuffer(), let data = CMSampleBufferGetDataBuffer(sample) {
            var values = [Float](repeating: 0, count: CMBlockBufferGetDataLength(data) / 4)
            let result = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
            precondition(result == noErr)
            power += values.reduce(0) { $0 + Double($1 * $1) }; sampleCount += values.count
        }
        precondition(coverReader.status == .completed && sampleCount > 180000)
        precondition(abs(sqrt(power / Double(sampleCount)) - 0.15 / sqrt(2)) < 0.015)
        let generator = AVAssetImageGenerator(asset: coverAsset)
        let first = try generator.copyCGImage(at: CMTime(seconds: 0.25, preferredTimescale: 600), actualTime: nil)
        let last = try generator.copyCGImage(at: CMTime(seconds: 1.75, preferredTimescale: 600), actualTime: nil)
        precondition(first.width == 720 && last.height == 1280)
        print("PASS: audio-only recording becomes a portrait movie with full duration, audible level and cover frames at both ends")
    }
}
