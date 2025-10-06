//
//  EditCliqueProfileViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/4/24.
//

import SwiftUI

@Observable final class EditCliqueProfileViewModel {
    var invitedMembers: [User] = []
    var cliqueName: String
    var cliqueBio: String
    var selectedCoverUIImage: UIImage?
    var selectedPfpUIImage: UIImage?
    
    let cid: String
    
    init(clique: Clique) {
        self.cid = clique.id
        self.cliqueName = clique.name
        self.cliqueBio = clique.bio
    }
    
    func editClique() async throws -> Clique {
        // ✅ Step 1: Invite users
        try await CliqueService.inviteUsers(.init(body: .json(.init(
            cliqueId: cid,
            userIds: invitedMembers.map { $0.id }
        ))))
        
        // ✅ Step 2: Prepare images and photo data
        let preparedPfp = prepareUIImage(selectedPfpUIImage)
        let preparedBanner = prepareUIImage(selectedCoverUIImage)
        
        // ✅ Step 3: Edit clique and get pre-signed URLs
        let editedClique = try await CliqueService.editClique(.init(body: .json(.init(
            cliqueId: cid,
            name: cliqueName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: cliqueBio.trimmingCharacters(in: .whitespaces),
            profilePic: preparedPfp?.photoData,  // Metadata only
            banner: preparedBanner?.photoData   // Metadata only
        ))))
        
        // ✅ Step 4: Upload profile pic if provided (original quality - backend handles conversion)
        if let profilePicUrl = editedClique.cliquePic?.url, let imageVariant = preparedPfp?.imageVariant {
            do {
                try await PhotoHelper.uploadImageData(imageVariant.data, to: profilePicUrl)
                print("🎉 Clique profile pic uploaded")
            } catch {
                print("❌ Failed to upload clique profile pic: \(error.localizedDescription)")
            }
        }

        // ✅ Step 5: Upload banner if provided (original quality - backend handles conversion)
        if let bannerUrl = editedClique.cliqueBanner?.url, let bannerVariant = preparedBanner?.imageVariant {
            do {
                try await PhotoHelper.uploadImageData(bannerVariant.data, to: bannerUrl)
                print("🎉 Clique banner uploaded")
            } catch {
                print("❌ Failed to upload clique banner: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 6: Return updated clique with uploaded URLs
        return try await CliqueService.getCliqueById(id: cid)
    }
}
