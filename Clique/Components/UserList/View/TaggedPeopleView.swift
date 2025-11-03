//
//  TaggedPeopleView.swift
//  Clique
//
//  Created by Rod Tavangar on 1/9/25.
//

import SwiftUI

struct TaggedPeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    let users: [User]
    var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.callout.bold())
                .textPrimary()
                .maxWidth()
            
            if false { // TODO: fetch, if no tagged users. separate loading/placeholder view
                VStack(spacing: 8) {
                    IconImage(name: "camera", color: .theme.iconPrimary, size: 32)
                    
                    Text("Hmmm. No one’s been tagged in this flick.")
                        .font(.footnote)
                        .textPrimary()
                }
                .infiniteFrame()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(users) { user in
                            Button {
                                dismiss()
                                tabViewCoordinator.navigate(to: user)
                            } label: {
                                UserCellWithFollow(uid: user.id)
                                //                            HStack(spacing: 0) {
                                //                                UserListCellView(uid: user.id, type: .taggedPost)
                                //                                
                                //                                Spacer()
                                //                                
                                //                                // TODO: fetch type (user relationship)
                                //                                SmallCTA(type: .primary, text: "Add") {
                                //                                    // TODO: update user relationship
                                //                                }
                                //                            }
                            }.buttonStyle(.noHighlight)
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

//#Preview {
//    TaggedPeopleView()
//        .environment(TabViewCoordinator())
//}
