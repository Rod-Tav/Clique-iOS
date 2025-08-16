//
//  CliqueCreatedScreen.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI

struct CliqueCreatedScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: -8) {
                if let pfp = viewModel.selectedPfpUIImage {
                    CliquePfpView(pfp: pfp, type: .cliqueCreated)
                    
                } else {
                    CliquePfpView(pfp: "default-gradient", type: .cliqueCreated)
                }
                
                if let currentUser = userStore.currentUser {
                    CliqueCircularMembersView(members: [currentUser] + viewModel.invitedMembers, memberLimit: 5, type: .medium)
                }
            }
            
            TopTitle(
                title: "Clique created!",
                description: "Your member invitations have been sent! Now get started by uploading your first flicks."
            )
        }
        .infiniteFrame()
        .onAppear {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
}

// MARK: - Bottom Button
extension CliqueCreatedScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(text: "Done") {
            bottomButtonAction()
        }
    }
    
    private func bottomButtonAction() {
        viewModel.triggerDismiss.toggle()
        trigger(.refreshUserCliques)
        tabViewCoordinator.navigate(to: viewModel.createdClique!)
    }
}

#Preview {
    CliqueCreatedScreen()
        .environment(TopIconFlowCoordinator())
        .environment(CliqueCreatorFlowViewModel())
}
