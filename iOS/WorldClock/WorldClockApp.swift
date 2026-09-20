import SwiftUI
import SwiftData

@main
struct WorldClockApp: App {
    // `.modelContainer(for:)` force-creates the on-disk store and crashes if it
    // can't (a corrupted store, a failed migration, a disk issue) — same class of
    // bug as ClockRepository's JSON parsing used to have on the Android port.
    // Falling back to an in-memory container means a corrupt store loses that
    // session's saved cities instead of crash-looping the app on every launch.
    private static let container: ModelContainer = {
        let schema = Schema([ClockEntry.self])
        if let onDisk = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)]) {
            return onDisk
        }
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }()

    var body: some Scene {
        WindowGroup {
            ClockListView()
        }
        .modelContainer(Self.container)
    }
}
