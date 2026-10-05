import SwiftUI

@main
@MainActor
struct OudLiveApp: App {
    @StateObject private var audio = AudioModel()
    @AppStorage("OudLive.console") private var console = true
    private var useConsole: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--legacy") { return false }
        #endif
        return console
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if useConsole { ConsoleView(audio: audio) }
                else { ContentView(audio: audio) }
            }
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        }
    }
}
