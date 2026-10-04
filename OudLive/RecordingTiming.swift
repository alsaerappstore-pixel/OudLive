import Foundation

// One logical take. Legacy WAV/MP4 siblings remain recoverable but share a card.
struct RecordingEntry: Identifiable {
    let id: URL
    let files: [URL]
    var videoURL: URL? { files.first { $0.pathExtension.lowercased() == "mp4" } }
    var primaryURL: URL { videoURL ?? files[0] }
    var title: String { id.lastPathComponent.replacingOccurrences(of: "OudLive-", with: "") }
    static func grouped(_ urls: [URL]) -> [RecordingEntry] {
        let supported = urls.filter { $0.isFileURL && ["wav", "mp4"].contains($0.pathExtension.lowercased()) }
        return Dictionary(grouping: Set(supported), by: { $0.deletingPathExtension() })
            .map { RecordingEntry(id: $0.key, files: $0.value.sorted { $0.path < $1.path }) }
            .sorted { $0.id.lastPathComponent > $1.id.lastPathComponent }
    }
    static func deletionURLs(_ entries: [RecordingEntry], selected: Set<URL>, directory: URL) -> [URL] {
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        return entries.filter { selected.contains($0.id) }.flatMap(\.files).filter {
            $0.isFileURL && ["wav", "mp4"].contains($0.pathExtension.lowercased()) &&
            $0.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent() == root
        }
    }
}

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
