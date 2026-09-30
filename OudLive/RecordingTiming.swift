import Foundation

struct RecordingTiming: Equatable {
    let audioTrim: Double
    let videoTrim: Double
    let duration: Double
    init?(audioStart: Double, videoStart: Double, audioDuration: Double, videoDuration: Double) {
        guard [audioStart, videoStart, audioDuration, videoDuration].allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        audioTrim = max(0, videoStart - audioStart)
        videoTrim = max(0, audioStart - videoStart)
        duration = min(audioDuration - audioTrim, videoDuration - videoTrim)
        guard duration > 0.1 else { return nil }
    }
}
