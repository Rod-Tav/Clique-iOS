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
        // Step 3: If new pfp is provided, upload using URL from updatedUser.profilePic (original quality - backend handles conversion)
        if let pfp = pfp, let profilePicUrl = updatedUser.profilePic?.url {
            // ✅ Prepare image data
            guard let preparedPfp = prepareUIImage(pfp) else { return updatedUser }

            // ✅ Upload original quality (backend handles quality conversion)
            do {
                try await PhotoHelper.uploadImageData(preparedPfp.imageVariant.data, to: profilePicUrl)
                print("🎉 Profile pic uploaded")
            } catch {
                print("❌ Failed to upload profile pic: \(error.localizedDescription)")
            }

            return try await UserService.getUserById(updatedUser.id)
        }
        
        // Step 4: Return updated user to caller
        return updatedUser
    }
}
