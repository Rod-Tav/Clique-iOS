//
//  CloudCliqueViewModel.swift
//  Clique
//

import Foundation

@Observable @MainActor final class CloudCliqueViewModel {
    var cliqueId: String
    var photos: [SyncedPhoto] = []
    var isLoading = false

    init(cliqueId: String) {
        self.cliqueId = cliqueId
    }

    func loadPhotos(from store: SyncedPhotoStore) {
        photos = store.photosForClique(cliqueId)
    }
}
