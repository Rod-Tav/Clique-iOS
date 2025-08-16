//
//  CliqueCreatorFlowViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 1/17/25.
//

import SwiftUI

@Observable final class CliqueCreatorFlowViewModel {
    // fields
    var invitedMembers: [User] = []
    var cliqueName: String = ""
    var cliqueBio: String = ""
    var selectedCoverUIImage: UIImage?
    var selectedPfpUIImage: UIImage?
    var createdClique: Clique?
    
    var triggerDismissKeyboard: Bool = false
    var triggerDismiss: Bool = false
    var suggestedMembers: [User] = []
    
    func fetchSuggestedMembers() {
        suggestedMembers = []
    }
    
    func createClique() async throws {
        // ✅ Step 1: Prepare image metadata and data if available
        let preparedPfp = prepareUIImage(selectedPfpUIImage)
        let preparedBanner = prepareUIImage(selectedCoverUIImage)
        
        // ✅ Step 2: Send metadata to backend for pre-signed URLs
        let clique = try await CliqueService.createClique(.init(body: .json(.init(
            name: cliqueName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: cliqueBio,
            cliqueProfilePic: preparedPfp?.photoData, // Metadata or nil
            cliqueBanner: preparedBanner?.photoData, // Metadata or nil
            members: invitedMembers.map { $0.id }
        ))))
        
        // ✅ Step 3: Conditionally upload profile picture if provided
        if let preparedPfp, let profilePicUrls = clique.cliquePic {
            async let pfpHigh: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.high.data, to: profilePicUrls.highQualityUrl)
            async let pfpMed: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.medium.data, to: profilePicUrls.medQualityUrl)
            async let pfpLow: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.low.data, to: profilePicUrls.lowQualityUrl)
            
            do {
                _ = try await (pfpHigh, pfpMed, pfpLow)
                print("✅ Uploaded clique profile pictures")
            } catch {
                print("❌ Failed to upload clique profile pictures: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 4: Conditionally upload banner if provided
        if let preparedBanner, let bannerUrls = clique.cliqueBanner {
            async let bannerHigh: () = PhotoHelper.uploadImageData(preparedBanner.imageVariants.high.data, to: bannerUrls.highQualityUrl)
            async let bannerMed: () = PhotoHelper.uploadImageData(preparedBanner.imageVariants.medium.data, to: bannerUrls.medQualityUrl)
            async let bannerLow: () = PhotoHelper.uploadImageData(preparedBanner.imageVariants.low.data, to: bannerUrls.lowQualityUrl)
            
            do {
                _ = try await (bannerHigh, bannerMed, bannerLow)
                print("✅ Uploaded clique banners")
            } catch {
                print("❌ Failed to upload clique banners: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 5: Fetch final clique with URLs
        createdClique = try await CliqueService.getCliqueById(id: clique.id)
        
        print("✅ CREATED CLIQUE with multi-quality images (if provided)")
    }
    
    func reset() {
        invitedMembers = []
        cliqueName = ""
        cliqueBio = ""
        selectedCoverUIImage = nil
        selectedPfpUIImage = nil
        createdClique = nil
        suggestedMembers = []
    }
}
