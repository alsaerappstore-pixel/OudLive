import Foundation
import AVFoundation
struct Entry: Decodable { let file: String; let playable: Bool }
let root = URL(fileURLWithPath: "OudLive/UserLoops", isDirectory: true)
let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
var count = 0
for entry in entries where entry.playable {
    let file = try AVAudioFile(forReading: root.appendingPathComponent(entry.file), commonFormat: .pcmFormatFloat32, interleaved: false)
    precondition(file.length > 0 && file.length < Int64(file.processingFormat.sampleRate * 120))
    precondition((1...2).contains(file.processingFormat.channelCount))
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    precondition(buffer.frameLength == AVAudioFrameCount(file.length))
    for c in 0..<Int(buffer.format.channelCount) {
        for i in 0..<Int(buffer.frameLength) { precondition(buffer.floatChannelData![c][i].isFinite) }
    }
    count += 1
}
precondition(count == 292)
print("PASS: Apple's audio decoder opened every one of the 292 supplied WAV originals")
