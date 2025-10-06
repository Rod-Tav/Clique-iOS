//
//  EditCollectionViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI

@Observable final class EditCollectionViewModel {
    var id: String
    var name: String
    var description: String
    var coverPhoto: UIImage?
    var visibility: Visibility
    var dateCreated: Date
    var photoUrls: PhotoUrls?
    
    init(collection: ClCollection) {
        self.id = collection.id
        self.name = collection.name
        self.description = collection.description
        self.visibility = collection.visibility
        self.dateCreated = collection.creation
        self.photoUrls = collection.coverPhoto
    }
    
    // TODO: DRY with editUser
    func editCollection() async throws -> ClCollection {
        let photoDataNoPath = prepareUIImage(coverPhoto)
        
        // Step 2: Call UserService to update text fields and request photo PUT URLs
        let updatedCollection = try await CollectionService.editCollection(
            .init(body: .json(.init(
                collectionDataId: id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespaces),
                coverPhoto: photoDataNoPath?.photoData,
                privacySetting: mapFromVisibility(visibility),
                date: convertFromDate(dateCreated)
            )))
        )
        
        if let coverPhoto, let url = updatedCollection.coverPhoto?.url {
            guard let preparedCoverPhoto = prepareUIImage(coverPhoto) else { return updatedCollection }

            do {
                try await PhotoHelper.uploadImageData(preparedCoverPhoto.imageVariant.data, to: url)
                print("🎉 Cover photo uploaded")
            } catch {
                print("❌ Failed to upload cover photo: \(error.localizedDescription)")
            }

            return try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: updatedCollection.id), query: .init(page: 0, size: 1)))
        }
        
        return updatedCollection
    }
}
