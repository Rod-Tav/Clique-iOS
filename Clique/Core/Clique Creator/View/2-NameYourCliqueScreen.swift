//
//  NameYourCliqueScreen.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI

enum CliqueInfoFocusedField {
    case cliqueName, cliqueBio
}

struct NameYourCliqueScreen: View {
    @Environment(UserStore.self) private var userStore
    
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
    
    // https://www.hackingwithswift.com/forums/100-days-of-swiftui/unusual-behavior-when-trying-to-change-the-style-of-the-text-in-a-swiftui-textfield/28414
    @State private var nameTextColor: Color = .theme.textTertiary
    @State private var descriptionTextColor: Color = .theme.textTertiary
    
    @FocusState private var focusedField: CliqueInfoFocusedField?
    
    private var cliqueName: String {
        viewModel.cliqueName
    }
    
    private var invitedMembers: [User] {
        viewModel.invitedMembers
    }
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableVM = viewModel
        
        VStack(spacing: 32) {
            TopTitle(
                title: "Name your Clique",
                description: "What brings you all together? You will be able to edit your name and description at any time."
            )
            
            VStack(alignment: .leading, spacing: 12) {
                if let currentUser = userStore.currentUser {
                    CliqueCircularMembersView(members: [currentUser] + invitedMembers, memberLimit: 5, type: .large)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("", text: $bindableVM.cliqueName, prompt: Text("Add a name...").foregroundStyle(Color.theme.textTertiary))
                        .font(.title3.bold())
                        .kerning(0.072)
                        .textPrimary()
//                        .onChange(of: viewModel.cliqueName) { oldValue, newValue in
//                            guard oldValue.isEmpty || newValue.isEmpty else { return }
//                            nameTextColor = cliqueName.isEmpty ? Color.theme.textTertiary : Color.theme.textPrimary
//                        }
                        .focused($focusedField, equals: .cliqueName)
                        .limitTextField(to: 50, text: $bindableVM.cliqueName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .cliqueBio
                        }
                    
                    TextField("Tap to add a description...", text: $bindableVM.cliqueBio, axis: .vertical)
                        .font(.footnote)
                        .foregroundStyle(descriptionTextColor)
                        .onChange(of: viewModel.cliqueBio) {
                            descriptionTextColor = viewModel.cliqueBio.isEmpty ? Color.theme.textTertiary : Color.theme.textSecondary
                        }
                        .focused($focusedField, equals: .cliqueBio)
                        .submitLabel(.done)
                        .limitTextField(to: 200, text: $bindableVM.cliqueBio)
                        .onEnter($of: $bindableVM.cliqueBio) {
                            bottomButtonAction()
                        }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .roundCorners(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(Color.theme.strokeSecondary, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            focusedField = .cliqueName
        }
        .onChange(of: cliqueName, initial: true) {
            coordinator.highlightNextBar = !cliqueName.isEmpty
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
}

// MARK: - Bottom Button
extension NameYourCliqueScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Done",
            buttonEnabled: !cliqueName.isEmpty
        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        coordinator.highlightNextBar = false
        coordinator.currentIconStep += 1
        coordinator.path.append(3)
    }
}

#Preview {
    NameYourCliqueScreen()
        .padding(.top, 24)
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .frameTop()
        .environment(TopIconFlowCoordinator())
        .environment(CliqueCreatorFlowViewModel())
}
