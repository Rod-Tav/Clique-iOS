//
//  SharedAlbumAssociationStore.swift
//  Clique
//
//  Persists collection-to-shared-album mappings in UserDefaults (App Group).
//

import Foundation
import Photos

// MARK: - Association Model

struct SharedAlbumAssociation: Codable {
    var collectionId: String
    var sharedAlbumLocalIdentifier: String
    var sharedAlbumTitle: String
    var associatedBy: String
    var associatedAt: Date
}

// MARK: - Store

@available(iOS 26, *)
@Observable
class SharedAlbumAssociationStore {
    var associations: [String: SharedAlbumAssociation] = [:]

    private static let userDefaultsKey = "SharedAlbumAssociations"
    private static let appGroupIdentifier = "group.com.cliquellc.clique"

    init() {
        associations = Self.load()
    }

    // MARK: - Public API

    func associate(collectionId: String, album: PHAssetCollection, userId: String) {
        let association = SharedAlbumAssociation(
            collectionId: collectionId,
            sharedAlbumLocalIdentifier: album.localIdentifier,
            sharedAlbumTitle: album.localizedTitle ?? "",
            associatedBy: userId,
            associatedAt: Date()
        )
        associations[collectionId] = association
        save()

        // Sync to backend
        Task {
            try? await SharedAlbumAssociationService.putAssociation(
                collectionId: collectionId,
                albumTitle: album.localizedTitle ?? ""
            )
        }
    }

    func disassociate(collectionId: String) {
        associations.removeValue(forKey: collectionId)
        save()

        // Sync to backend
        Task {
            try? await SharedAlbumAssociationService.deleteAssociation(collectionId: collectionId)
        }
    }

    func getAssociation(for collectionId: String) -> SharedAlbumAssociation? {
        associations[collectionId]
    }

    /// Fetches the actual PHAssetCollection from a stored localIdentifier, falling back to title match.
    func resolveAlbum(for collectionId: String) -> PHAssetCollection? {
        guard let association = associations[collectionId] else { return nil }

        // Try localIdentifier first
        if !association.sharedAlbumLocalIdentifier.isEmpty {
            let result = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [association.sharedAlbumLocalIdentifier],
                options: nil
            )
            if let found = result.firstObject { return found }
        }

        // Fallback to title match
        return resolveAlbumByTitle(association.sharedAlbumTitle)
    }

    /// Find a shared album by title (used when localIdentifier is empty).
    func resolveAlbumByTitle(_ title: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumCloudShared,
            options: nil
        )
        var match: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == title {
                match = collection
                stop.pointee = true
            }
        }
        return match
    }

    /// Fetches association from backend and merges with local state.
    /// If local association exists (has localIdentifier), keep it.
    /// If only backend has it, store with empty localIdentifier for title-based resolution.
    func fetchFromBackend(collectionId: String) async {
        do {
            guard let dto = try await SharedAlbumAssociationService.getAssociation(collectionId: collectionId) else {
                return // No backend association
            }

            // If we already have a local association, keep it (it has localIdentifier)
            if associations[collectionId] != nil { return }

            // Backend has it but we don't — store with empty localIdentifier
            let association = SharedAlbumAssociation(
                collectionId: dto.collectionId,
                sharedAlbumLocalIdentifier: "",
                sharedAlbumTitle: dto.albumTitle,
                associatedBy: dto.associatedBy,
                associatedAt: ISO8601DateFormatter().date(from: dto.createdAt) ?? Date()
            )
            associations[collectionId] = association
            save()
        } catch {
            print("[SharedAlbumAssociationStore] fetchFromBackend failed: \(error)")
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        if let data = try? JSONEncoder().encode(associations) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    private static func load() -> [String: SharedAlbumAssociation] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: userDefaultsKey),
              let stored = try? JSONDecoder().decode([String: SharedAlbumAssociation].self, from: data) else {
            return [:]
        }
        return stored
    }

}
