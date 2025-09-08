//
//  AuthFlowView.swift
//  Clique
//
//  Created by Quinn Liu on 1/21/25.
//

import SwiftUI
import Toasts

struct AuthFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(AuthFlowViewModel.self) private var viewModel
    @Environment(AuthService.self) private var authService
    
    @State private var coordinator = TopIconFlowCoordinator()
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 64) {
                TopBar()
                
                NavStack()
            }
            
            coordinator.bottomButton()
                .padding(.horizontal, 16)
                .background(colorScheme == .light ? Gradients.buttonBgLight : Gradients.buttonBgDark)
        }
        .contentShape(.rect)
        .primaryBackground()
    }
    
    @ViewBuilder private func NavStack() -> some View {
        NavigationStack(path: $coordinator.path) {
            EnterPhoneNumberScreen()
                .frameTop()
                .padding(.horizontal, 24)
                .primaryBackground()
                .environment(coordinator)
                .environment(viewModel)
                .navigationDestination(for: Double.self) { dest in
                    Group {
                        if dest == 1.1 {
                            EnterCodeScreen()
                        } else if dest == 2.1 {
                            EnterNameScreen()
                        } else if dest == 2.2 {
                            EnterUsernameScreen_Signup()
                        } else if dest == 3 {
                            AddProfileScreen_Signup()
                        } else if dest == 3.1 {
                            FindYourFriendsScreen()
                                .padding(.horizontal, -24)
                        } else if dest == 4 {
                            WelcomeToCliqueScreen()
                                .padding(.horizontal, -24)
                        }
                    }
                    .frameTop()
                    .primaryBackground()
                    .padding(.horizontal, 24)
                    .environment(coordinator)
                    .environment(viewModel)
                    .navigationBarBackButtonHidden()
//                    .safeAreaPadding(.bottom, 32 + safeAreaInsets.bottom)
                    .primaryBackground()
                }
        }
    }
    
    @ViewBuilder
    private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    if false { // at end of flow
                        
                    } else {
                        if coordinator.currentIconStep == 1, coordinator.path.isEmpty { // first screen
                            viewModel.reset()
                            dismiss()
                        } else if coordinator.currentIconStep == 4 { // last screen
                            userStore.updateUser(viewModel.registeredUser!) // must exist
                            authService.appViewType = .main
                        } else if coordinator.isRootOfStep, coordinator.currentIconStep > 1 {
                            coordinator.currentIconStep -= 1
                        }
                        
                        coordinator.backButtonAction()
                        
                        if !coordinator.path.isEmpty {
                            coordinator.path.removeLast()
                        }
                    }
                } label: {
                    IconImage((coordinator.path.isEmpty || coordinator.currentIconStep == 4) ? "x-icon" : "arrow-left", color: .theme.iconSecondary, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: {
                if viewModel.authFlowType == .signup {
                    TopIconBar(icons: ["phone", "pen", "camera", "clique-star"])
                        .environment(coordinator)
                }
            },
            trailingIcon: { Spacer().frame(24) }
        )
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }
}

#Preview {
    AuthFlowView()
        .environment(AuthFlowViewModel())
}
