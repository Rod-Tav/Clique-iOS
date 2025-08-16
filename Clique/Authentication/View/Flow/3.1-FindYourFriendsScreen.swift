//
//  FindYourFriendsScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI

struct FindYourFriendsScreen: View {
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(TopIconFlowCoordinator.self) var coordinator
    @Environment(AuthFlowViewModel.self) var viewModel
    
    @State private var buttonEnabled: Bool = false
    @State private var contactsOnClique: [User] = []
    @State private var contacts: [User] = []
    
    // MARK: - body
    var body: some View {
        AddContactsView(alignment: .leading, fromAuth: true)
            .environment(TabViewCoordinator())
            .onAppear {
                coordinator.backButtonAction = {
                    coordinator.highlightNextBar = false
                }
                
                coordinator.isRootOfStep = false
                
                coordinator.bottomButton = { AnyView(BottomButton()) }
            }
    }
}

// MARK: - Bottom Button
extension FindYourFriendsScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Next",
            buttonEnabled: true,
            canSkip: true
        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        coordinator.highlightNextBar = false
        coordinator.currentIconStep += 1
        coordinator.path.append(4.0)
    }
}

#Preview {
    FindYourFriendsScreen()
        .environment(AuthFlowViewModel())
        .environment(TopIconFlowCoordinator())
}
