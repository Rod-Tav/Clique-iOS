//
//  UserFollowButton.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI

struct UserFollowButton: View {
    let relationship: UserRelationship
    let action: () -> Void
    
    var body: some View {
        SmallCTA(
            type: relationship.buttonType,
            leadingIcon: relationship.leadingIcon,
            text: relationship.buttonText,
            action: {
                haptics(relationship == .following ? .rigid : .soft)
                action()
            }
        )
    }
}

#Preview {
    UserFollowButton(relationship: .following, action: {})
}
