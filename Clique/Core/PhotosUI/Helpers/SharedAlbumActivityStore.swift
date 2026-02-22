//
//  SharedAlbumActivityStore.swift
//  Clique
//
//  Persists per-album photo count snapshots in UserDefaults (App Group)
//  to detect new photos added to iCloud Shared Albums.
//

import Foundation

// MARK: - Models

struct AlbumActivitySnapshot: Codable {
    var albumLocalIdentifier: String
    var albumTitle: String
    var lastKnownCount: Int
    var snapshotDate: Date
}

struct AlbumActivityChange {
    var albumLocalIdentifier: String
    var albumTitle: String
    var delta: Int
    var lastSeenDate: Date
}

// MARK: - Store

@available(iOS 26, *)
@Observable
class SharedAlbumActivityStore {
    var snapshots: [String: AlbumActivitySnapshot] = [:]

    private static let userDefaultsKey = "SharedAlbumActivitySnapshots"
    private static let appGroupIdentifier = "group.com.cliquellc.clique"

    var hasBaseline: Bool {
        !snapshots.isEmpty
    }

    init() {
        snapshots = Self.load()
    }

    // MARK: - Public API

    /// Updates the snapshot for an album when the user opens it.
    func markAlbumSeen(albumLocalIdentifier: String, title: String, currentCount: Int) {
        let snapshot = AlbumActivitySnapshot(
            albumLocalIdentifier: albumLocalIdentifier,
            albumTitle: title,
            lastKnownCount: currentCount,
            snapshotDate: Date()
        )
        snapshots[albumLocalIdentifier] = snapshot
        save()
    }

    /// Compares current album counts against stored snapshots.
    /// Returns albums with positive count deltas, sorted by delta descending.
    func detectChanges(currentAlbums: [(localIdentifier: String, title: String, count: Int)]) -> [AlbumActivityChange] {
        var changes: [AlbumActivityChange] = []

        for album in currentAlbums {
            guard let snapshot = snapshots[album.localIdentifier] else { continue }
            let delta = album.count - snapshot.lastKnownCount
            if delta > 0 {
                changes.append(AlbumActivityChange(
                    albumLocalIdentifier: album.localIdentifier,
                    albumTitle: album.title,
                    delta: delta,
                    lastSeenDate: snapshot.snapshotDate
                ))
            }
        }

        return changes.sorted { $0.delta > $1.delta }
    }

    // MARK: - Persistence

    private func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    private static func load() -> [String: AlbumActivitySnapshot] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: userDefaultsKey),
              let stored = try? JSONDecoder().decode([String: AlbumActivitySnapshot].self, from: data) else {
            return [:]
        }
        return stored
    }
}
