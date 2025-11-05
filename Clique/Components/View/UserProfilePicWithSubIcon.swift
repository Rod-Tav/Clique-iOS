//
//  UserProfilePicWithSubIcon.swift
//  Clique
//
//  Created by Kyuho Lee on 1/23/25.
//

import SwiftUI

enum SubIconType {
    case like
    case comment
    case add
    case clique
    case collection
    case leader
    case tag
    case inviteClique
    case inviteText
    
    var pfpType: String? {
        switch self {
        case .like, .comment, .add, .clique, .leader, .tag:
            return nil
        case .collection:
            return "collections"
        case .inviteClique:
            return "clique-star"
        case .inviteText:
            return "messages"
        }
    }
    
    var pfpShape: AnyShape? {
        switch self {
        case .like:
            return AnyShape(HeartFilledIcon())
        case .comment:
            return AnyShape(CommentFilledIcon())
        case .add:
            return AnyShape(AddUserIcon())
        case .clique:
            return AnyShape(ThreeUserIcon())
        case .leader:
            return AnyShape(CrownLeaderIcon())
        case .tag:
            return AnyShape(CameraIcon())
        case .collection, .inviteClique, .inviteText:
            return nil
        }
    }
    
    var iconColor: Color {
        switch self {
        case .like:
            return Color.theme.red
        case .comment:
            return Color.theme.skyblue
        case .add:
            return Color.theme.purple
        case .clique, .collection, .tag:
            return Color.theme.iconPrimary
        case .leader:
            return Color.theme.gold
        case .inviteClique:
            return Color.theme.black
        case .inviteText:
            return Color.theme.white
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .like, .comment, .add, .leader, .clique, .tag, .collection:
            return Color.theme.strokeBgMatch
        case .inviteClique:
            return Color.theme.white
        case .inviteText:
            return Color.theme.messages
        }
    }
    
    var stroke: Bool {
        switch self {
        case .like, .comment, .add, .leader, .tag, .clique:
            return true
        case .collection, .inviteClique, .inviteText:
            return false
        }
    }
    
}

struct UserProfilePicWithSubIcon: View {
    var pfp: PhotoUrls?
    let type: SubIconType
    let size: CGFloat
    let quality: ImageQuality
    
    var body: some View {
        ZStack {
            UserPfpAsyncView(pfp: pfp, size: size, quality: quality)
            
            if type.stroke {
                IconOuterStroke(
                    shape: type.pfpShape ?? AnyShape(Circle()),
                    color: type.iconColor, size: 18,
                    strokeColor: type.secondaryColor, strokeWidth: 2
                )
                .offset(x: size / 3, y: size / 3)
            } else {
                ZStack {
                    Circle()
                        .fill(type.secondaryColor)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 1)
                        .frame(18)
                    
                    IconImage(name: type.pfpType ?? "dot", color: type.iconColor, size: 12)
                }
                .offset(x: size / 3, y: size / 3)
            }
            
            
        }
        .frame(size)
    }
}


struct CliquePicWithSubIcon: View {
    var pfp: PhotoUrls?
    let subIconType: SubIconType
    let cliquePfpType: CliquePfpViewType
    var hasBorder: Bool = true
    let size: CGFloat
    let quality: ImageQuality
    var context: ImageLoadingContext = .detail

    var body: some View {
        ZStack {
            CliquePfpAsyncView(pfp: pfp, type: cliquePfpType, hasBorder: hasBorder, quality: quality, context: context)
            
            if subIconType.stroke {
                IconOuterStroke(
                    shape: subIconType.pfpShape ?? AnyShape(Circle()),
                    color: subIconType.iconColor, size: 18,
                    strokeColor: subIconType.secondaryColor, strokeWidth: 2
                )
                .offset(x: size / 3, y: size / 3)
            } else {
                ZStack {
                    Circle()
                        .fill(subIconType.secondaryColor)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 1)
                        .frame(18)
                    
                    IconImage(name: subIconType.pfpType ?? "dot", color: subIconType.iconColor, size: 12)
                }
                .offset(x: size / 3, y: size / 3)
            }
            
            
        }
        .frame(size)
    }
}

// This is super jank - had to wrap / unwrap the value to pass it in correctly to IconOuterStroke

struct AnyShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        self._path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}

#Preview {
    UserProfilePicWithSubIcon(pfp: User.MOCK_USERS[0].profilePic, type: .add, size: 48, quality: .low)
}
