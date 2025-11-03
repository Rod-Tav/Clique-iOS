//
//  AuthFlowViewModel.swift
//  Clique
//
//  Created by Quinn Liu on 1/18/25.
//

import Foundation
import SwiftUI
import Mixpanel

enum AuthFlowType {
    case signup, login
}

@Observable final class AuthFlowViewModel {
    var authFlowType: AuthFlowType = .login
    
    var countryCode: String = "US"
    var phone: String = ""
    var phoneCode: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var username: String = ""
    var profilePic: UIImage?
    var bio: String = ""
    
    var usernameAvailable: Bool = true
    
    var followList: [User] = [] // idea is to add all "followed" users to a list and then send it as a batch follow request after their profile has been made
    var inviteList: [User] = [] // contacts to invite to clique
    
    var joinNumber: Int?
    var registeredUser: User?
    
    func signup(userStore: UserStore) async throws {
        guard let countryCodePrefix = Constants.countryPhoneCodes[countryCode] else {
            throw ServiceError.somethingWentWrong
        }
        
        // ✅ Step 1: Prepare photo data (original quality - backend handles quality conversion)
        let preparedPhoto = prepareUIImage(profilePic)

        // Split into metadata and image data
        let photoDataNoPath = preparedPhoto?.photoData
        let imageVariant = preparedPhoto?.imageVariant

        // ✅ Step 2: Register user, receiving profile pic upload URLs
        let (registeredUser, joinNumber) = try await UserService.registerUser(.init(body: .json(.init(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: countryCodePrefix + phone,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            profilePic: photoDataNoPath
        ))))

        self.registeredUser = registeredUser
        self.joinNumber = joinNumber

        // ✅ Step 3: Upload profile pic (original quality only - backend handles quality conversion)
        if let profilePicUrl = registeredUser.profilePic?.url, let imageVariant {
            do {
                try await PhotoHelper.uploadImageData(imageVariant.data, to: profilePicUrl)
                print("🎉 Profile pic uploaded")
            } catch {
                print("❌ Failed to upload profile pic: \(error.localizedDescription)")
            }
        }
        
        // ✅ Step 4: Fetch updated user with profile pic and set as current user
        self.registeredUser = try await UserService.fetchSelf()
        await MainActor.run {
            userStore.currentUserId = self.registeredUser!.id
        }
        await userStore.updateUser(self.registeredUser!)
        
        Mixpanel.mainInstance().identify(distinctId: registeredUser.id)
        
        Mixpanel.mainInstance().people.set(properties: [
            "$name": registeredUser.fullname,
            "$number": registeredUser.number,
            "$id": registeredUser.id,
            "$visibility": registeredUser.isPrivate
        ])
        
        track("Sign Up")
    }
    
    func reset() {
        authFlowType = .login
        countryCode = "US"
        phone = ""
        phoneCode = ""
        firstName = ""
        lastName = ""
        username = ""
        profilePic = nil
        usernameAvailable = true
        followList.removeAll()
        inviteList.removeAll()
    }
}

enum AuthEntryType {
    case phone
    case name
    case username
}
