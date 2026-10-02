import SwiftUI

@main
@MainActor
struct OudLiveApp: App {
    @StateObject private var audio = AudioModel()
    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        }
    }
}
