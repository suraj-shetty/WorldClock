import SwiftUI
import SwiftData

@main
struct WorldClockApp: App {
    var body: some Scene {
        WindowGroup {
            ClockListView()
        }
        .modelContainer(for: ClockEntry.self)
    }
}
