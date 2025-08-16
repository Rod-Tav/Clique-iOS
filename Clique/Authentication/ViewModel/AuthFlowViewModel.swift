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
    var birthday: Date = Date()
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
        
        // ✅ Step 1: Prepare multi-quality photo data and actual image data
        let preparedPhoto = prepareUIImage(profilePic)
        
        // Split into metadata and image data
        let photoDataNoPath = preparedPhoto?.photoData
        let imageVariants = preparedPhoto?.imageVariants
        
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
        
        // ✅ Step 3: Upload profile pic variants using exact prepared data
        if let profilePicUrls = registeredUser.profilePic, let imageVariants {
            async let highUpload: () = PhotoHelper.uploadImageData(imageVariants.high.data, to: profilePicUrls.highQualityUrl)
            async let medUpload: () = PhotoHelper.uploadImageData(imageVariants.medium.data, to: profilePicUrls.medQualityUrl)
            async let lowUpload: () = PhotoHelper.uploadImageData(imageVariants.low.data, to: profilePicUrls.lowQualityUrl)
            
            do {
                _ = try await (highUpload, medUpload, lowUpload)
                print("🎉 All profile pic variants uploaded")
            } catch {
                print("❌ Failed to upload one or more profile pic variants: \(error.localizedDescription)")
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
        birthday = Date()
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
    case birthday
    case name
    case username
}
