//
//  CliqueFollowButton.swift
//  Clique
//
//  Created by Rod Tavangar on 2/10/25.
//

import SwiftUI

struct CliqueFollowButton: View {
    let relationship: CliqueRelationship
    let action: () -> Void
    
    var body: some View {
        SmallCTA(
            type: relationship.buttonType,
            leadingIcon: relationship.leadingIcon,
            text: relationship.buttonText,
            action: {
                haptics(relationship == .following ? .soft : .rigid)
                action()
            }
        )
        .disabled(relationship == .leader || relationship == .member)
    }
}
