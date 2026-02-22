//
//  ExtensionCacheManager.swift
//  CliqueMessages
//
//  Caches clique, collection, and flick data in the App Group container.
//

import Foundation

final class ExtensionCacheManager {
    static let shared = ExtensionCacheManager()

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: "group.com.cliquellc.clique")
    }

    // MARK: - Cliques

    func saveCliques(_ cliques: [CachedClique]) {
        guard let data = try? JSONEncoder().encode(cliques) else { return }
        defaults?.set(data, forKey: "cachedCliques")
    }

    func loadCliques() -> [CachedClique] {
        guard let data = defaults?.data(forKey: "cachedCliques"),
              let cliques = try? JSONDecoder().decode([CachedClique].self, from: data) else { return [] }
        return cliques
    }

    // MARK: - Collections

    func saveCollections(_ collections: [CachedCollection], for cliqueId: String) {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults?.set(data, forKey: "cachedCollections_\(cliqueId)")
    }

    func loadCollections(for cliqueId: String) -> [CachedCollection] {
        guard let data = defaults?.data(forKey: "cachedCollections_\(cliqueId)"),
              let collections = try? JSONDecoder().decode([CachedCollection].self, from: data) else { return [] }
        return collections
    }

    // MARK: - Flicks

    func saveFlicks(_ flicks: [CachedFlick], for cliqueId: String) {
        guard let data = try? JSONEncoder().encode(flicks) else { return }
        defaults?.set(data, forKey: "cachedFlicks_\(cliqueId)")
    }

    func loadFlicks(for cliqueId: String) -> [CachedFlick] {
        guard let data = defaults?.data(forKey: "cachedFlicks_\(cliqueId)"),
              let flicks = try? JSONDecoder().decode([CachedFlick].self, from: data) else { return [] }
        return flicks
    }

    // MARK: - Current User

    func loadCurrentUser() -> CachedUser? {
        guard let data = defaults?.data(forKey: "cachedCurrentUser"),
              let user = try? JSONDecoder().decode(CachedUser.self, from: data) else { return nil }
        return user
    }
}
