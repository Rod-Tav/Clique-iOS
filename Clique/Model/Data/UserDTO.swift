//
//  UserData.swift
//  Clique
//
//  Created by Rod Tavangar on 12/7/24.
//

import SwiftUI
import Foundation

func mapToUser(_ data: Components.Schemas.RegisterResponseBody) -> User {
    return mapToUser(data.user!)
}

func mapToUser(_ userResponseBody: Components.Schemas.GetUserResponseBody) -> User {
    let user = userResponseBody.user!
    return mapToUser(user)
}

func mapToUser(_ user: Components.Schemas.User) -> User {
    var relationship: UserRelationship? = nil
    if let rel = user.followStatus {
        print(rel)
        relationship = mapToUserRelationship(rel)
    } else {
//        print("no rel")
    }
    return User(
        id: user.userId!,
        firstname: user.firstName!,
        lastname: user.lastName!,
        number: user.phoneNumber ?? "",
        username: user.username!,
        profilePic: user.profilePic == nil ? nil : mapToMediaUrls(user.profilePic!),
        bio: user.bio ?? "",
        isPrivate: user.isPrivate!,
        numCliques: user.cliqueCount!,
        numFollowers: user.followersCount!,
        numFollowing: user.followingCount!,
        relationship: relationship
    )
}

func mapToUsers(_ usersReponseBody: Components.Schemas.GetUsersResponseBody) -> [User] {
    let users = usersReponseBody.users!
    return users.map { mapToUser($0) }
}

func mapToUsers(_ users: [Components.Schemas.User]) -> [User] {
    return users.map { mapToUser($0) }
}
