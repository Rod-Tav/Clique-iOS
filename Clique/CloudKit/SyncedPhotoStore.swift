//
//  SyncedPhotoStore.swift
//  Clique
//

import Foundation

@Observable @MainActor final class SyncedPhotoStore {
    var photos = [String: SyncedPhoto]()
    var syncStatus: SyncStatus = .idle
    var lastSyncDate: Date?

    enum SyncStatus {
        case idle, syncing, error(String)
    }

    func updatePhoto(_ photo: SyncedPhoto) {
        photos[photo.id] = photo
    }

    func updatePhotos(_ newPhotos: [String: SyncedPhoto]) {
        for (key, value) in newPhotos {
            photos[key] = value
        }
    }

    func photosForClique(_ cliqueId: String) -> [SyncedPhoto] {
        photos.values
            .filter { $0.cliqueId == cliqueId }
            .sorted { $0.captureDate > $1.captureDate }
    }

    func reset() {
        photos.removeAll()
        syncStatus = .idle
        lastSyncDate = nil
    }
}
