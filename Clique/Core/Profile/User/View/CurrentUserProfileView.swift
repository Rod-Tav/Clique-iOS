//
//  CurrentUserProfileView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/18/24.
//

import SwiftUI

struct CurrentUserProfileView: View {
    @Environment(UserStore.self) private var userStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    var body: some View {
        if let uid = userStore.currentUserId {
            @Bindable var bindableTVC = tabViewCoordinator
            
            TabNavigationStack(path: $bindableTVC.profileNavigationPath) {
                UserProfileTabsView(userId: uid, isCurrentUser: true)
                    .primaryBackground()
            }
        }
    }
}

//#Preview {
//    CurrentUserProfileView(user: User.MOCK_USERS[0])
//}
