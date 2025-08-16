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
        
        // ✅ Step 4: Upload profile pic variants if provided
        if let profilePicUrls = editedClique.cliquePic, let imageVariants = preparedPfp?.imageVariants {
            async let highUpload: () = PhotoHelper.uploadImageData(imageVariants.high.data, to: profilePicUrls.highQualityUrl)
            async let medUpload: () = PhotoHelper.uploadImageData(imageVariants.medium.data, to: profilePicUrls.medQualityUrl)
            async let lowUpload: () = PhotoHelper.uploadImageData(imageVariants.low.data, to: profilePicUrls.lowQualityUrl)
            
            do {
                _ = try await (highUpload, medUpload, lowUpload)
                print("🎉 All clique profile pic variants uploaded")
            } catch {
                print("❌ Failed to upload one or more clique profile pic variants: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 5: Upload banner variants if provided
        if let bannerUrls = editedClique.cliqueBanner, let bannerVariants = preparedBanner?.imageVariants {
            async let highUpload: () = PhotoHelper.uploadImageData(bannerVariants.high.data, to: bannerUrls.highQualityUrl)
            async let medUpload: () = PhotoHelper.uploadImageData(bannerVariants.medium.data, to: bannerUrls.medQualityUrl)
            async let lowUpload: () = PhotoHelper.uploadImageData(bannerVariants.low.data, to: bannerUrls.lowQualityUrl)
            
            do {
                _ = try await (highUpload, medUpload, lowUpload)
                print("🎉 All clique banner variants uploaded")
            } catch {
                print("❌ Failed to upload one or more clique banner variants: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 6: Return updated clique with uploaded URLs
        return try await CliqueService.getCliqueById(id: cid)
    }
}
