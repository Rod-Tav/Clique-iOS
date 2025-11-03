//
//  CliqueCircularMembersView.swift
//  Clique
//
//  Created by Rod Tavangar on 8/12/24.
//

import SwiftUI

struct CliqueCircularMembersView: View {
    let members: [User]
    var memberLimit: Int?
    let type: CliqueMembersViewType
    var forceDark: Bool = false
    
    private var limit: Int { memberLimit ?? type.memberLimit }
    
    var body: some View {
        let limitExceeded: Bool = members.count > limit
        let max = limitExceeded ? limit - 1 : members.count
        
        HStack(spacing: type.spacing) {
            ForEach(0 ..< max, id: \.self) { i in
                if i < members.count {
                    UserPfpAsyncView(pfp: members[i].profilePic, size: type.size.width, quality: .low, context: .list)
                        .overlay( // border
                            Circle()
                                .inset(by: type.inset)
                                .stroke(forceDark ? Color("DarkPrimaryBackground") : type.strokeColor, lineWidth: type.strokeWidth)
                        )
                        .zIndex(-Double(i))
                }
            }

            if limitExceeded {
                ZStack {
                    if limit - 1 < members.count {
                        UserPfpAsyncView(pfp: members[limit - 1].profilePic, size: type.size.width, quality: .low, context: .list)
                            .overlay(.black.opacity(0.6))
                            .overlay(
                                Circle()
                                    .inset(by: type.inset)
                                    .stroke(forceDark ? Color("DarkPrimaryBackground") : type.strokeColor, lineWidth: type.strokeWidth)
                            )
                    }
                    
                    EllipsisImage(color: .theme.shadesWhite95, size: type.size.width)
                }
                .zIndex(-Double(max))
                .clipShape(.circle)
            }
            
            // TODO: optional var as part of type cleanup
            if type == .sharePostTagged || type == .cliqueCreator {
                ZStack {
                    Circle()
                        .foregroundColor(.black.opacity(0.9))
                        .frame(type.size)
                        .overlay(
                            Circle()
                                .inset(by: type.inset)
                                .stroke(forceDark ? Color("DarkPrimaryBackground") : type.strokeColor, lineWidth: type.strokeWidth)
                        )
                    
                    Image("plus")
                        .icon(color: .theme.shadesWhite95, size: 24)
                }
                .zIndex(-Double(max))
            }
        }
    }
}

#Preview {
    CliqueCircularMembersView(members: [User.MOCK_USERS[0], User.MOCK_USERS[1], User.MOCK_USERS[2], User.MOCK_USERS[3], User.MOCK_USERS[4], User.MOCK_USERS[5], User.MOCK_USERS[6]], type: .cliqueProfile)
}
