//
//  UserListCellView.swift
//  Clique
//
//  Created by Rod Tavangar on 11/1/24.
//

import SwiftUI

struct UserListCellView: View {
    @Environment(UserStore.self) private var userStore
    
    let uid: String
    var type: UserListCellViewType
    var isLeader: Bool = false
    var forceWhite: Bool = false
    var showFollowedByLine: Bool = false // TODO: fetch
    
    private var user: User? {
        userStore.users[uid]
    }
    
    var body: some View {
        if let user {
            HStack(spacing: 8) {
                UserPfpAsyncView(pfp: user.profilePic, size: type.size, quality: type.quality, context: .list)
                
                VStack(alignment: .leading, spacing: showFollowedByLine ? 2 : 4) {
                    HStack(spacing: 4) {
                        Text(user.fullname)
                            .font(.footnote.bold())
                            .foregroundStyle(forceWhite ? Color.theme.shadesWhite95 : Color.theme.textPrimary)
                            .lineLimit(1)
                        
                        if isLeader {
                            IconImage("crown-leader", color: Color.theme.buttonCTA, size: 12)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.caption2)
                        .foregroundStyle(forceWhite ? Color.theme.shadesWhite65 : Color.theme.textSecondary)
                    
//                    if showFollowedByLine {
//                        SubLabel(
//                            text: {
//                                Text("Followed by **Rod** & 10 others")
//                                    .font(.caption2)
//                                    .textSecondary()
//                            },
//                            leadingIcon: {
//                                UserPfpAsyncView(pfp: "rod-pp", size: 12)
//                            }
//                        )
//                    }
                }
            }
        }
    }
}

//#Preview {
//    UserListCellView(user: User.MOCK_USERS[0], type: .searchRecents)
//}
