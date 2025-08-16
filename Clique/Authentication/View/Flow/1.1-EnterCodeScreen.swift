//
//  EnterCodeScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/22/25.
//


import SwiftUI
import FirebaseAuth
import Toasts

struct EnterCodeScreen: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(AuthFlowViewModel.self) private var viewModel
    @Environment(AuthService.self) private var authService
    
    @FocusState private var isFocused: Bool
    
    @State private var loginUserDoesNotExist: Bool = false
    @State private var buttonLoading: Bool = false
    
    private var buttonEnabled: Bool {
        viewModel.phoneCode.count == 6 && !loginUserDoesNotExist
    }
    
    private var authFlowType: AuthFlowType {
        viewModel.authFlowType
    }
    
    var body: some View {
        AuthContentView(
            title: "Enter your code",
            description: {
                AuthFlowDescription(entryType: .phone)
                    .environment(viewModel)
            },
            inputView: {
                PhoneConfirmation()
            }
        )
        .onAppear {
            coordinator.backButtonAction = {
                coordinator.highlightNextBar = false
                viewModel.phoneCode = ""
            }
            coordinator.isRootOfStep = false
        }
        .onChange(of: [buttonEnabled, buttonLoading], initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
    
    @ViewBuilder private func PhoneConfirmation() -> some View {
        @Bindable var bindableVm = viewModel
        
        TextField("123456", text: $bindableVm.phoneCode)
            .padding(.top, 64)
            .font(.largeTitle.bold())
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .onChange(of: viewModel.phoneCode) { oldValue, newValue in
                if newValue.count > 6 {
                    bindableVm.phoneCode = String(newValue.prefix(6))
                }
            }
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
    }
    
}

// MARK: Bottom Button
extension EnterCodeScreen {
    @ViewBuilder private func BottomButton() -> some View {
        VStack(spacing: 16) {
            Text("No account found. Did you mean to sign up?")
                .opacity(loginUserDoesNotExist ? 1 : 0)
                .font(.callout)
                .foregroundStyle(Color.theme.red)
            
            
            FlowBottomButton(
                text: authFlowType == .signup ? "Next" : "Sign In",
                buttonEnabled: buttonEnabled,
                buttonLoading: buttonLoading
            ) {
                bottomButtonAction()
            }
        }
    }
    
    private func bottomButtonAction() {
        buttonLoading = true
        if authFlowType == .signup {
            authService.verifyCode(smsCode: viewModel.phoneCode, userStore: userStore) { success, userExists  in
                buttonLoading = false
                
                guard success else {
                    presentToast(Toasts.somethingWentWrong)
                    return
                }
                
                if !userExists {
                    coordinator.currentIconStep += 1
                    coordinator.highlightNextBar = false
                    coordinator.path.append(2.0)
                } // else they are signed in since userSession was set in verifyCode
            }
        } else {
            authService.verifyCode(smsCode: viewModel.phoneCode, userStore: userStore) { success, userExists in
                buttonLoading = false
                
                guard success else {
                    presentToast(Toasts.somethingWentWrong)
                    return
                }
                
                if !userExists {
                    do {
                        try Auth.auth().signOut()
                        loginUserDoesNotExist = true
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
        }
    }
}

#Preview {
    EnterCodeScreen()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
}

