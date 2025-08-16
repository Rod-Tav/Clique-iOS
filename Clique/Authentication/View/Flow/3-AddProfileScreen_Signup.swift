//
//  AddProfileScreen_Signup.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI
import PhotosUI
import Toasts

struct AddProfileScreen_Signup: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(TopIconFlowCoordinator.self) var coordinator
    @Environment(AuthFlowViewModel.self) var viewModel
    
    @State private var pickerEnabled: Bool = false
    @State private var buttonLoading: Bool = false
    
    private var profilePic: UIImage? { viewModel.profilePic }
    private var buttonEnabled: Bool { profilePic != nil }
    
    // MARK: - Body
    var body: some View {
        AuthContentView(
            title: "Add a profile pic",
            description: {
                Text("So people can recognize you!")
                    .textSecondary()
                    .font(.body)
            },
            inputView: {
                ProfilePicEntry()
            }
        )
        .onAppear {
            coordinator.backButtonAction = {
                coordinator.highlightNextBar = true
            }
            coordinator.isRootOfStep = true
        }
        .onChange(of: [buttonEnabled, buttonLoading], initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
    
    @ViewBuilder private func ProfilePicEntry() -> some View {
        @Bindable var bindableVm = viewModel
        
        Button {
            pickerEnabled = true
        } label: {
            VStack(spacing: 12) {
                if let profilePic {
                    Image(uiImage: profilePic)
                        .resizable()
                        .scaledToFill()
                        .frame(128)
                        .clipShape(.circle)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                } else {
                    Image("default-gradient")
                        .frame(128)
                        .overlay(
                            Rectangle()
                                .stroke(Color.theme.strokeTertiary, lineWidth: 0.5)
                        )
                        .clipShape(.circle)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                }
                
                HStack(spacing: 8) {
                    SmallCTA(type: .secondary, leadingIcon: "camera", text: "Change Image") {
                        pickerEnabled = true
                    }
                    
                    if profilePic != nil {
                        Button {
                            viewModel.profilePic = nil
                        } label: {
                            IconImage("x-icon", color: .theme.iconSecondary, size: 12)
                                .padding(5)
                                .background {
                                    Circle().fill(Color.theme.buttonTertiary)
                                }
                        }
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.noHighlight)
        .maxWidth()
        .cropImagePicker(
            type: .circle,
            show: $pickerEnabled,
            croppedUIImage: $bindableVm.profilePic
        )
        .padding(.top, 64) // from quinn: maybe make it a zstack?
    }
}

// MARK: - Bottom Button
extension AddProfileScreen_Signup {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: buttonEnabled ? "Next" : "Skip",
            buttonEnabled: buttonEnabled,
            buttonLoading: buttonLoading,
            canSkip: true
        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        Task {
            do {
                buttonLoading = true
                
                try await viewModel.signup(userStore: userStore)
                
                coordinator.highlightNextBar = true
                coordinator.path.append(3.1)
                
                buttonLoading = false
            } catch(let error) {
                buttonLoading = false
                if let error = error as? ServiceError, error == .uploadFailed { // upload failed
                    // TODO: better error handling
                    presentToast(Toasts.uploadFailed)
                }
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
}

#Preview {
    AddProfileScreen_Signup()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
}
