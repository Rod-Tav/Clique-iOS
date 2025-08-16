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
    
    private var buttonEnabled: Bool {
        !(viewModel.firstName.isEmpty || viewModel.lastName.isEmpty)
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
                NameEntry()
            }
        )
        .onAppear { focusedField = .first }
    }
    
    @ViewBuilder
    private func NameEntry() -> some View {
        @Bindable var viewModel = viewModel
        
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
        .padding(.top, 48)
        .onAppear {
            coordinator.backButtonAction = {}
            coordinator.isRootOfStep = false
        }
        .onChange(of: buttonEnabled, initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
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
