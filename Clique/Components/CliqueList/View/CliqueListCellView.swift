//
//  CliqueListCellView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/21/24.
//

import SwiftUI
import Kingfisher
import Toasts

struct CliqueListCellView: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @State private var viewModel: CliqueProfileViewModel
    
//    private var members: [User] {
//        return viewModel.fetchCliqueMembers()
//    }
    
    var type: CliqueListType = .standard
    var trailingIcon: String?
    var trailingIconColor: Color?
    var trailingIconBgColor: Color?
    
    let cid: String
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(cid: String, type: CliqueListType? = .standard, trailingIcon: String? = "", trailingIconColor: Color? = .theme.iconPrimary, trailingIconBgColor: Color? = .clear) {
        self.cid = cid
        self.viewModel = CliqueProfileViewModel(cid: cid)
        self.type = type ?? .standard
        self.trailingIcon = trailingIcon
        self.trailingIconColor = trailingIconColor
        self.trailingIconBgColor = trailingIconBgColor
    }
    
    var body: some View {
        if let clique {
            HStack(spacing: 0) {
                CliquePfpAsyncView(pfp: clique.cliquePic, type: .cliqueListCell, quality: .low)
                    .padding(.trailing, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    switch type {
                    case .standard:
                        if !viewModel.firstXMembers.isEmpty {
                            CliqueCircularMembersView(members: viewModel.firstXMembers, type: .cliqueListCell)
                        } else {
                            // TODO: loading view
                            Spacer()
                                .frame(CliqueMembersViewType.cliqueListCell.size)
                        }
                    case .cliqueInvite(let fromUserPfp, let fromUserFirstName):
                        HStack(spacing: 4) {
                            UserPfpAsyncView(pfp: fromUserPfp, size: 16, quality: .low, context: .list)

                            Text("**\(fromUserFirstName)** invited you")
                                .textSecondary()
                                .font(.caption2)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clique.name)
                            .textPrimary()
                            .font(.footnote.bold())
                            .lineLimit(1)
                        
                        HStack(spacing: 2) {
                            UserStatView(
                                value: clique.numMembers,
                                title: clique.numMembers == 1 ? "Member" : "Members",
                                statColor: type.statColor,
                                descColor: type.descColor
                            )
                            
//                            Text("•")
//                                .font(.caption)
//                                .foregroundStyle(.gray)
//                            
//                            UserStatView(value: clique.numAura, title: "Aura", statColor: type.statColor, descColor: type.descColor)
                        }
                    }
                }
                
                Spacer()
                
                if let trailingIcon, !trailingIcon.isEmpty, let trailingIconColor {
                    IconImage(trailingIcon, color: trailingIconColor, size: 16)
                        .background {
                            if let bgColor = trailingIconBgColor {
                                bgColor
                                    .clipShape(.circle)
                                    .scaleEffect(0.75)
                            }
                        }
                }
            }
            .contentShape(.rect)
            .onAppear {
                // using onAppear here instead of task because it can get cancelled when coming from clique profile --> create
                Task {
                    guard type == .standard, viewModel.firstXMembers.count < min(clique.numMembers, 20) else { return }
                   
                    do {
                        try await viewModel.fetchCliqueFirstXMembers(count: 20, total: clique.numMembers, userStore, cliqueStore)
                    } catch {
                        //                if !(error is CancellationError) {
                        //                    print(error)
                        presentToast(Toasts.somethingWentWrong)
                        //                }
                    }
                }
            }
        }
    }
}

#Preview {
    CliqueListCellView(cid: Clique.MOCK_CLIQUES[5].id, type: .standard)
}
