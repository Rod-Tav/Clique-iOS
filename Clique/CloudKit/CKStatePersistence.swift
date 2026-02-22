import Foundation

/// Persists SyncedDatabase state to the App Group container for cross-process access.
struct CKStatePersistence {
    private static let fileName = "SyncedDatabaseState.json"

    /// Saves the database state to the App Group container.
    static func save(_ data: SyncedAppData) {
        guard let url = fileURL else { return }
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            print("[CKStatePersistence] Failed to save state: \(error)")
        }
    }

    /// Loads the database state from the App Group container.
    static func load() -> SyncedAppData? {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SyncedAppData.self, from: data)
        } catch {
            print("[CKStatePersistence] Failed to load state: \(error)")
            return nil
        }
    }

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SyncConfiguration.appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}
