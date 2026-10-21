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
        // `groupContainer: .none`: with an App Group entitlement (added for the widget),
        // SwiftData's default silently relocates the store into the group container —
        // starting every existing install over with an empty city list. The widget only
        // needs the small SharedCities copy, so the store stays where it always was.
        if let onDisk = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, groupContainer: .none)]) {
            return onDisk
        }
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }()

    #if os(macOS)
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    #endif

    var body: some Scene {
        #if os(macOS)
        WindowGroup(id: "board") {
            MacBoardView()
        }
        .modelContainer(Self.container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1384, height: 844)
        .commands { BoardCommands() }

        Settings {
            MacSettingsView()
        }
        .modelContainer(Self.container)

        // A fixed label on purpose: a live one (TimelineView + @Query) put the status item
        // in a layout loop at 100% CPU, with every title/image change resizing the item,
        // which re-ran the label. The city times live in the popover instead.
        MenuBarExtra("World Clock", systemImage: "globe", isInserted: $showMenuBarExtra) {
            MenuBarView().modelContainer(Self.container)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ClockListView()
        }
        .modelContainer(Self.container)
        #endif
    }
}
