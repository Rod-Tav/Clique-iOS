//
//  EditUserProfileViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI

@Observable final class EditUserProfileViewModel {
    var username: String
    var bio: String
    var firstname: String
    var lastname: String
    var pfp: UIImage?
    
    init(user: User) {
        self.username = user.username
        self.bio = user.bio
        self.firstname = user.firstname
        self.lastname = user.lastname
    }
    
    func editUser() async throws -> User {
        // Step 1: Prepare photo data if pfp is provided
        let photoDataNoPath = prepareUIImage(pfp)
        
        // Step 2: Call UserService to update text fields and request photo PUT URLs
        let updatedUser = try await UserService.editUser(
            .init(body: .json(.init(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio,
                firstName: firstname.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastname.trimmingCharacters(in: .whitespacesAndNewlines),
                profilePic: photoDataNoPath?.photoData // can be nil if no new pfp provided
            )))
        )
        
        // Step 3: If new pfp is provided, upload all variants using URLs from updatedUser.profilePic
        // Step 3: If new pfp is provided, upload all variants using URLs from updatedUser.profilePic
        if let pfp = pfp, let profilePicUrls = updatedUser.profilePic {
            // ✅ Prepare image data and variants
            guard let preparedPfp = prepareUIImage(pfp) else { return updatedUser }
            
            // ✅ Upload high/med/low variants using exact prepared data
            async let highUpload: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.high.data, to: profilePicUrls.highQualityUrl)
            async let medUpload: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.medium.data, to: profilePicUrls.medQualityUrl)
            async let lowUpload: () = PhotoHelper.uploadImageData(preparedPfp.imageVariants.low.data, to: profilePicUrls.lowQualityUrl)
            
            do {
                _ = try await (highUpload, medUpload, lowUpload)
                print("🎉 All profile pic variants uploaded")
            } catch {
                print("❌ Failed to upload one or more profile pic variants: \(error.localizedDescription)")
            }
            
            return try await UserService.getUserById(updatedUser.id)
        }
        
        // Step 4: Return updated user to caller
        return updatedUser
    }
}
