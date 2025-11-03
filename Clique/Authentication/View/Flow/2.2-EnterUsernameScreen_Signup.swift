//
//  EnterUsernameScreen_Signup.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI
import Toasts

struct EnterUsernameScreen_Signup: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(TopIconFlowCoordinator.self) var coordinator
    @Environment(AuthFlowViewModel.self) var viewModel
    
    @FocusState private var isFocused
    @State private var isUsernameTaken: Bool = true
    @State private var hasTriedUsername: Bool = false
    @State private var buttonLoading: Bool = false
    
    private var buttonEnabled: Bool {
        !viewModel.username.isEmpty
    }
    
    // MARK: - Body
    var body: some View {
        AuthContentView(
            title: "Pick a username",
            description: {
                Text("Get creative with it...")
                    .textSecondary()
                    .font(.body)
            },
            inputView: {
                UsernameEntry()
            }
        )
        .onAppear {
            isFocused = true
            isUsernameTaken = true
            hasTriedUsername = false
            
            coordinator.backButtonAction = {
                coordinator.highlightNextBar = false
            }
            coordinator.isRootOfStep = false
        }
        .onChange(of: buttonEnabled, initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
    
    // MARK: - Username field
    @ViewBuilder private func UsernameEntry() -> some View {
        @Bindable var bindableVm = viewModel
        
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text("@")
                        .textPrimary()
                    
                    TextField("enter username here", text: $bindableVm.username)
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                        .submitLabel(.next)
                        .onSubmit { bottomButtonAction() }
                        .onChange(of: viewModel.username) {
                            guard viewModel.username.contains(" ") else { return }
                            viewModel.username = viewModel.username.replacing(" ", with: "")
                        }
                        .limitTextField(to: 30, text: $bindableVm.username)
                }

                Spacer()

                if !viewModel.username.isEmpty, hasTriedUsername {
                    IconImage(
                        name: isUsernameTaken ? "x-icon" : "check-circle-empty",
                        color: isUsernameTaken ? .theme.red : .theme.green, size: 20
                    )
                    .animation(.easeInOut, value: isUsernameTaken)
                }
            }
            
            Divider()
                .frame(height: 1)
                .background(Color.theme.strokeSecondary)
        }
        .padding(.top, 64)
    }
    
    // MARK: - Bottom Button
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Next",
            buttonEnabled: buttonEnabled
        ) {
            bottomButtonAction()
        }
    }
    
    // MARK: - Helper functions
    private func bottomButtonAction() {
        Task {
            do {
                buttonLoading = true
                
                let isUnique = try await UserService.checkUsernameUnique(.init(path: .init(username: viewModel.username)))
                
                await MainActor.run {
                    if isUnique {
                        isUsernameTaken = false
                        coordinator.highlightNextBar = false
                        coordinator.currentIconStep += 1
                        coordinator.path.append(3.0)
                    } else {
                        isUsernameTaken = true
                    }
                    
                    buttonLoading = false
                    hasTriedUsername = true
                }
            } catch {
                buttonLoading = false
                hasTriedUsername = true
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
}

#Preview {
    EnterUsernameScreen_Signup()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
}
