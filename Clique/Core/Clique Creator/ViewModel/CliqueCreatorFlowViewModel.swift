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
        
        // ✅ Step 3: Conditionally upload profile picture if provided (original quality - backend handles conversion)
        if let preparedPfp, let profilePicUrl = clique.cliquePic?.url {
            do {
                try await PhotoHelper.uploadImageData(preparedPfp.imageVariant.data, to: profilePicUrl)
                print("✅ Uploaded clique profile picture")
            } catch {
                print("❌ Failed to upload clique profile picture: \(error.localizedDescription)")
            }
        }

        // ✅ Step 4: Conditionally upload banner if provided (original quality - backend handles conversion)
        if let preparedBanner, let bannerUrl = clique.cliqueBanner?.url {
            do {
                try await PhotoHelper.uploadImageData(preparedBanner.imageVariant.data, to: bannerUrl)
                print("✅ Uploaded clique banner")
            } catch {
                print("❌ Failed to upload clique banner: \(error.localizedDescription)")
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
