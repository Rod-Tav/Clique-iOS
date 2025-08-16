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
        
        if let coverPhoto, let urls = updatedCollection.coverPhoto {
            guard let preparedCoverPhoto = prepareUIImage(coverPhoto) else { return updatedCollection }
            
            async let highUpload: () = PhotoHelper.uploadImageData(preparedCoverPhoto.imageVariants.high.data, to: urls.highQualityUrl)
            async let medUpload: () = PhotoHelper.uploadImageData(preparedCoverPhoto.imageVariants.medium.data, to: urls.medQualityUrl)
            async let lowUpload: () = PhotoHelper.uploadImageData(preparedCoverPhoto.imageVariants.low.data, to: urls.lowQualityUrl)
            
            do {
                _ = try await (highUpload, medUpload, lowUpload)
                print("🎉 All profile pic variants uploaded")
            } catch {
                print("❌ Failed to upload one or more profile pic variants: \(error.localizedDescription)")
            }
            
            return try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: updatedCollection.id), query: .init(page: 0, size: 1)))
        }
        
        return updatedCollection
    }
}
