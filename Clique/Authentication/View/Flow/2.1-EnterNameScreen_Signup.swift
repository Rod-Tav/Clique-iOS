//
//  EnterNameScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/23/25.
//

import SwiftUI

private enum FocusedField {
    case first, last
}

struct EnterNameScreen: View {
    @Environment(TopIconFlowCoordinator.self) var coordinator
    @Environment(AuthFlowViewModel.self) var viewModel
    
    @FocusState private var focusedField: FocusedField?
    @State private var ageConfirmed: Bool = false
    
    private var buttonEnabled: Bool {
        !(viewModel.firstName.isEmpty || viewModel.lastName.isEmpty) && ageConfirmed
    }
    
    var body: some View {
        AuthContentView(
            title: "What's your name?",
            description: {
                Text("Nice to meet you!")
                    .textSecondary()
                    .font(.body)
            },
            inputView: {
                nameEntry
            }
        )
        .onAppear { focusedField = .first }
    }
    
    private var nameEntry:  some View {
        @Bindable var viewModel = viewModel
        
        return VStack(spacing: 24) {
            VStack(spacing: 8) {
                Group {
                    TextField("First Name", text: $viewModel.firstName)
                        .focused($focusedField, equals: .first)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .last }
                        .limitTextField(to: 50, text: $viewModel.firstName)
                    
                    TextField("Last Name", text: $viewModel.lastName)
                        .focused($focusedField, equals: .last)
                        .submitLabel(.next)
                        .onSubmit { bottomButtonAction() }
                        .limitTextField(to: 50, text: $viewModel.lastName)
                }
                .font(.largeTitle.bold())
                .textPrimary()
            }
            
            Spacer()
            
            ageConfirmationCheckbox
                .padding(.bottom, 24)
        }
        .padding(.top, 48)
        .onAppear {
            coordinator.backButtonAction = {}
            coordinator.isRootOfStep = false
        }
        .onChange(of: buttonEnabled, initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
    
    // MARK: Age checkbox
    private var ageConfirmationCheckbox: some View {
        Button {
            ageConfirmed.toggle()
        } label: {
            HStack(spacing: 8) {
                IconImage(
                    "check-circle-empty",
                    color: ageConfirmed ? .theme.cliquePink : .theme.iconSecondary,
                    size: 20
                )
                
                Text("I confirm I am 16 years old or older")
                    .font(.footnote)
                    .textPrimary()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.noHighlight)
        .maxWidth(.leading)
    }
}

// MARK: - Bottom Button
extension EnterNameScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Next",
            buttonEnabled: buttonEnabled
        ) {
            bottomButtonAction()
        }
    }
    
    private func bottomButtonAction() {
        coordinator.highlightNextBar = true
        coordinator.path.append(2.2) // username view
    }
}

#Preview {
    EnterNameScreen()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
}
