import SwiftUI
import SwiftData

@main
struct backtoApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let url = storeURL
        let config = ModelConfiguration(url: url)
        do {
            return try ModelContainer(for: SavedPlace.self, configurations: config)
        } catch {
            // Schema incompatible with stored data — wipe and recreate.
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
            }
            do {
                return try ModelContainer(for: SavedPlace.self, configurations: config)
            } catch {
                fatalError("ModelContainer init failed after store wipe: \(error)")
            }
        }
    }

    private static var storeURL: URL {
        let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.cwdigital.backto")?
            .appendingPathComponent("Library/Application Support")
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("default.store")
    }
}
