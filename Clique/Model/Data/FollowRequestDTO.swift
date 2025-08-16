//
//  FollowRequestDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/5/25.
//

import Foundation

struct FollowRequest: Identifiable {
    var id: String
    var fromUser: User
}

func mapToFollowRequest(_ fr: Components.Schemas.FollowRequest) -> FollowRequest {
    return FollowRequest(id: fr.followRequestId!, fromUser: mapToUser(fr.fromUser!))
}
