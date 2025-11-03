//
//  NotificationListCellView.swift
//  Clique
//
//  Created by Quinn Liu on 1/31/25.
//

import SwiftUI
import Toasts

struct NotificationListCellView: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    @State private var selectedFlick: CollectionImage?
    
    let notification: UserNotification
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationLink(value: notification.user) {
                ZStack(alignment: .bottomTrailing) {
                    UserPfpAsyncView(pfp: notification.user.profilePic, size: UserListCellViewType.large.size, quality: .low, context: .list)
                        .overlayTopLeftNotification(when: !(notification.viewed ?? false), size: 10)
                    
                    switch notification.type {
                    case .likedFlickInCollection:
                        IconOuterStroke(shape: HeartFilledIcon(), color: notification.type.notificationSymbolColor, size: 16, strokeColor: .theme.strokeBgMatch, strokeWidth: 2)
                            .offset(x: 2, y: 2)
                    case .commentedOnPost, .commentedInCollection, .mentionedYouInComment:
                        IconOuterStroke(shape: CommentFilledIcon(), color: notification.type.notificationSymbolColor, size: 16, strokeColor: .theme.strokeBgMatch, strokeWidth: 2)
                            .offset(x: 2, y: 2)
                    case .newCliqueLeader:
                        IconOuterStroke(shape: CrownLeaderIcon(), color: notification.type.notificationSymbolColor, size: 16, strokeColor: .theme.strokeBgMatch, strokeWidth: 2)
                            .offset(x: 2, y: 2)
                    case .cliqueInvite, .cliqueJoined, .cliqueLeft:
                        IconOuterStroke(shape: ThreeUserIcon(), color: notification.type.notificationSymbolColor, size: 16, strokeColor: .theme.strokeBgMatch, strokeWidth: 2)
                            .offset(x: 2, y: 2)
                    case .followRequest, .followedYou, .acceptedFollowRequest:
                        IconOuterStroke(shape: AddUserIcon(), color: notification.type.notificationSymbolColor, size: 16, strokeColor: .theme.strokeBgMatch, strokeWidth: 2)
                            .offset(x: 2, y: 2)
                    case .taggedInFlicks:
                        IconOuterStroke(
                            shape: CameraIcon(),
                            color: notification.type.notificationSymbolColor,
                            size: 16,
                            strokeColor: .theme.strokeBgMatch,
                            strokeWidth: 2
                        )
                        .offset(x: 2, y: 2)
                    default:
                        IconImage(
                            name: notification.type.notificationSymbol,
                            color: notification.type.notificationSymbolColor,
                            size: 12
                        )
                            .background(
                                Circle()
                                    .fill(Color.theme.surfacesPrimary)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.theme.strokeTertiary, lineWidth: 2)
                                    )
                                    .frame(16)
                            )
                            .offset(x: 0, y: 0)
                    }
                }
            }
            .buttonStyle(.noHighlight)
            .padding(.trailing, 12)
            
            NotificationDetails()
            
            Spacer()
            
            if notification.type == .likedFlickInCollection || notification.type == .commentedInCollection, let flick = notification.collectionImage, let collection = notification.collection {
                Button {
                    selectedFlick = flick
                } label: {
                    LikedFlickNotiAsyncView(urls: flick.imageUrl, size: 36, quality: .low)
                }
                .noHighlight()
                .fullScreenCover(item: $selectedFlick) { flick in
                    SingleFlickView(flick: flick, collection: collection)
                }
            }
            
            if notification.type == .followedYou {
                // TODO: DRY LOL
                if notification.user.id != userStore.currentUserId, let relationship = userStore.users[notification.user.id]?.relationship {
                    UserFollowButton(relationship: relationship) {
                        let uid = notification.user.id
                        let user = notification.user
                        let oldUser = user
                        let oldCurrentUser = userStore.currentUser
                        
                        Task {
                            do {
                                switch relationship {
                                case .following:
                                    try await FollowUserViewModel.unfollow(uid, userStore)
                                case .requested:
                                    try await FollowUserViewModel.unrequest(uid, userStore)
                                case .unrelated:
                                    try await FollowUserViewModel.follow(uid, isPrivate: user.isPrivate, userStore)
                                }
                            } catch {
                                userStore.users[uid] = oldUser
                                userStore.users[userStore.currentUserId!] = oldCurrentUser
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    }
                }
            }
        }
//        .onAppear { // TODO: DRY
//            guard notification.type == .followedYou else { return }
//            
//            let user = notification.user
//            let uid = user.id
//            
//            Task {
//                guard let cuid = userStore.currentUserId, user.id != cuid, userStore.users[user.id]?.relationship == nil else { return }
//                do {
//                    let relationship = try await UserService.getFollowStatus(input: .init(path: .init(userId: uid)))
//                    userStore.users[user.id]?.relationship = relationship
//                } catch {
//                    presentToast(Toasts.somethingWentWrong)
//                }
//            }
//        }
    }
    
    @ViewBuilder private func NotificationDetails() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                if notification.type == .createdCollection {
                    HStack(spacing: 4) {
                        HStack(spacing: 0) {
                            NavigationLink(value: notification.user) {
                                Text("**\(notification.user.firstname)**")
                            }
                            .noHighlight()
                            
                            Text(" created")
                        }
                        
                        NavigationLink(value: notification.collection) {
                            HStack(spacing: 4) {
                                Image("collections")
                                    .icon(color: .theme.iconPrimary, size: 12)
                                
                                Text("\(notification.collection?.name ?? "")")
                            }
                        }
                        .noHighlight()
                        
                    }
                } else {
                    HStack(spacing: 0) {
                        NavigationLink(value: notification.user) {
                            Text("**\(notification.user.firstname)**")
                        }
                        .noHighlight()
                        
                        if notification.type == .commentedInCollection, let name = notification.collection?.name {
                            Text(" \(notification.type.notificationMessage) \(name)")
                                .lineLimit(1)
                        } else {
                            Text(" \(notification.type.notificationMessage)")
                        }
                    }
                }
            }
            .font(.footnote)
            
//            if notification.type == .commentedInCollection, let comment = notification.comment {
//                Text(comment)
//                    .lineLimit(1)
//                    .font(.caption2)
//                    .foregroundStyle(Color.theme.textSecondary)
//            } else {
                NotificationSubDetails()
//            }
        }
    }
    
    @ViewBuilder private func NotificationSubDetails() -> some View {
        HStack(spacing: 4) {
            Group {
                if let clique = notification.clique {
                    NavigationLink(value: clique) {
                        HStack(spacing: 4) {
                            CliquePfpAsyncView(pfp: clique.cliquePic, type: .notification, hasBorder: false, quality: .low)
                            
                            Text(clique.name)
                        }
                    }.noHighlight()
                    
                    Text("•")
                }
                
                if let collection = notification.collection {
                    if notification.type != .createdCollection {
                        NavigationLink(value: collection) {
                            HStack(spacing: 4) {
                                Image("collections")
                                    .icon(color: .theme.iconSecondary, size: 12)
                                
                                Text(collection.name)
                            }
                        }.noHighlight()
                        
                        Text("•")
                    }
                }
                
                Text(timeDifference(time: notification.time))
                
            }
            .font(.caption2)
            .foregroundStyle(Color.theme.textSecondary)
        }
    }
    
//    @ViewBuilder private func AcceptButton() -> some View { // need to figure out view-updating logic
//        if let accepted = notification.accepted, accepted {
//            SmallCTA(type: .tertiary, leadingIcon: "check", text: "Accepted") {
//                notification.accepted = false
//                print("button pressed")
//            }
//        } else {
//            SmallCTA(type: .primary, text: "Accept") {
//                notification.accepted = true
//                print("button pressed")
//            }
//        }
//    }
//
//    @ViewBuilder private func FollowButton() -> some View { // same thing, needs to have view-updating logic
//        if notification.user.relationship == .following {
//            SmallCTA(type: .tertiary, leadingIcon: "check", text: "Following") {
//                notification.user.relationship = .unrelated
//                print("button pressed")
//            }
//        } else if notification.user.relationship == .requested {
//            SmallCTA(type: .tertiary, leadingIcon: "time-clock-recents", text: "Requested") {
//                notification.user.relationship = .unrelated
//                print("button pressed")
//            }
//        } else {
//            SmallCTA(type: .primary, leadingIcon: "plus", text: "Follow") { // should depend on whether the user is public
//                notification.user.relationship = .requested
//                print("button pressed")
//            }
//        }
//    }
    
    private func timeDifference(time: Date) -> String {
        let now = Date()
        let secondsAgo = Int(now.timeIntervalSince(time))
        
        if secondsAgo < 60 {
            return "\(secondsAgo)s"
        }
        
        let minutesAgo = secondsAgo / 60
        if minutesAgo < 60 {
            return "\(minutesAgo)m"
        }
        
        let hoursAgo = minutesAgo / 60
        if hoursAgo < 24 {
            return "\(hoursAgo)h"
        }
        
        let daysAgo = hoursAgo / 24
        if daysAgo < 7 {
            return "\(daysAgo)d"
        }
        
        let weeksAgo = daysAgo / 7
        return "\(weeksAgo)w"
    }
}


#Preview {
    NotificationListCellView(notification: UserNotification.MOCK_NOTIFICATIONS[6])
}
