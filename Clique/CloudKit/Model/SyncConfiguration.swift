import Foundation

/// Configuration controlling which cliques are synced and sync behavior.
struct SyncConfiguration: Codable {
    static let containerIdentifier = "iCloud.com.cliquellc.clique"
    static let zoneNamePrefix = "CloudClique"
    static let appGroupIdentifier = "group.com.cliquellc.clique"

    var enabledCliqueIds: Set<String> = []
    var syncOnCellular: Bool = true

    /// Returns the CloudKit zone name for a given clique ID.
    static func zoneName(for cliqueId: String) -> String {
        "\(zoneNamePrefix)-\(cliqueId)"
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "SyncConfiguration"

    /// Saves the configuration to the shared App Group UserDefaults.
    func save() {
        guard let defaults = UserDefaults(suiteName: SyncConfiguration.appGroupIdentifier) else { return }
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: SyncConfiguration.userDefaultsKey)
        }
    }

    /// Loads the configuration from the shared App Group UserDefaults.
    static func load() -> SyncConfiguration {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(SyncConfiguration.self, from: data) else {
            return SyncConfiguration()
        }
        return config
    }
}
