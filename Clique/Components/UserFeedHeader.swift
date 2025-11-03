//
//  FeedHeader.swift
//  Clique
//
//  Created by Kyuho Lee on 1/22/25.
//

import SwiftUI

struct UserFeedHeader: View {
    @Environment(UserStore.self) private var userStore
    
    let uid: String
    let visibility: Visibility
    var cliquePfp: PhotoUrls?
    
    private var user: User? {
        userStore.users[uid]
    }
    
    var body: some View {
        if let user, let cuid = userStore.currentUserId {
            NavigationLink(value: user) {
                HStack(spacing: 12) {
//                    UserProfilePicWithSubIcon(pfp: user.profilePic, type: .collection, size: 32)
                    UserPfpAsyncView(pfp: user.profilePic, size: 32, quality: .low)
//                        .overlay(alignment: .bottomTrailing) {
//                            CliquePfpAsyncView(pfp: cliquePfp, type: .notification)
//                                .alignmentGuide(.bottom) {$0[VerticalAlignment.center]}
//                                .alignmentGuide(.trailing) {$0[VerticalAlignment.center]}
////                                .offset(x: 32 / 3, y: 32 / 3)
//                        }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        if visibility == .priv {
                            VisibilityPill(visibility: visibility)
                        }
                        
                        HStack(spacing: 4) {
                            Text(uid == cuid ? "You" : user.firstname)
                                .font(.footnote.bold())
                            
                            Text("created a collection")
                                .font(.footnote)
                                .minimumScaleFactor(0.75)
                        }
                        .textPrimary()
                    }
                }
                .maxWidth(.leading)
                .contentShape(.rect)
            }.buttonStyle(.noHighlight)
        }
    }
}

struct CliqueFeedHeader: View {
    let clique: Clique
//    let type: FeedItemType
    let visibility: Visibility
    let numFlicks: Int
    
    var body: some View {
        NavigationLink(value: clique) {
            HStack(spacing: 12) {
                CliquePicWithSubIcon(
                    pfp: clique.cliquePic,
                    subIconType: .collection,
                    cliquePfpType: .feedCellBanner,
                    size: 32,
                    quality: .low
                )
                
                Group {
                    Text(clique.name)
                        .font(.footnote.bold())
                    
                    + Text(" shared \(pluralizeWithCount(count: numFlicks, singular: "flick"))")
                        .font(.footnote)
                }
                .textPrimary()
            }
            .maxWidth(.leading)
            .contentShape(.rect)
        }
    }
}
