//
//  EnterPhoneNumberScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/22/25.
//

import SwiftUI
import Toasts

struct EnterPhoneNumberScreen: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(AuthFlowViewModel.self) private var viewModel
    @Environment(AuthService.self) private var authService
    
    @FocusState private var isFocused: Bool
    
    @State private var buttonLoading: Bool = false
    
    private var buttonEnabled: Bool {
        viewModel.phone.filter { $0.isNumber }.count == 10
    }
    
    var body: some View {
        AuthContentView(
            title: "Enter your phone number",
            description: {},
            inputView: {
                PhoneEmailEntry()
            }
        )
        .onAppear {
            coordinator.backButtonAction = {}
        }
        .onChange(of: [buttonEnabled, buttonLoading], initial: true) {
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
    
    @ViewBuilder
    private func PhoneEmailEntry() -> some View {
        @Bindable var bindableVm = viewModel
        
        HStack(spacing: 12) {
            CountryCode()
            
            TextField("Your phone", text: $bindableVm.phone)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .keyboardType(.phonePad)
                .font(.system(size: 32).weight(.bold))
                .onChange(of: viewModel.phone) {
                    if !viewModel.phone.isEmpty {
                        viewModel.phone = viewModel.phone.formatPhoneNumber()
                    }
                }
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
        }
        .padding(.top, 48)
    }
    
    @ViewBuilder
    private func CountryCode() -> some View {
        @Bindable var bindableViewModel = viewModel
        
        Menu {
            Picker("", selection: $bindableViewModel.countryCode) {
                ForEach(Constants.countryPhoneCodes.keys.sorted(), id: \.self) { countryCode in
                    Text("\(emoji(countryCode)) \(countryCode) \(Constants.countryPhoneCodes[countryCode] ?? "")").tag(countryCode)
                }
            }
        } label: {
            PickerLabel()
        }
    }
    
    @ViewBuilder
    private func PickerLabel() -> some View {
        HStack(spacing: 8) {
            Text("\(emoji(viewModel.countryCode))")
            
            Text("\(Constants.countryPhoneCodes[viewModel.countryCode] ?? "")")
        }
        .font(.body.bold())
        .foregroundStyle(Color.theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.theme.buttonTertiary)
        .clipShape(.capsule)
    }
    
    private func emoji(_ countryCode: String) -> String {
        countryCode
            .unicodeScalars
            .map { 127397 + $0.value }
            .compactMap(UnicodeScalar.init)
            .map(String.init)
            .joined()
    }
}

// MARK: - Bottom Button
extension EnterPhoneNumberScreen {
    @ViewBuilder private func BottomButton() -> some View {
        VStack(spacing: 16) {
            Text("We'll text you a code to verify your identity.\nMessage and data rates may apply.")
                .textSecondary()
                .font(.footnote)
                .multilineTextAlignment(.center)
            
            FlowBottomButton(
                text: "Next",
                buttonEnabled: buttonEnabled,
                buttonLoading: buttonLoading
            ) {
                bottomButtonAction()
            }
        }
    }
    
    private func bottomButtonAction() {
        if let countryCode = Constants.countryPhoneCodes[viewModel.countryCode] {
            buttonLoading = true
            
            authService.startAuth(phoneNumber: countryCode + viewModel.phone) { success in
                guard success else {
                    presentToast(Toasts.somethingWentWrong)
                    buttonLoading = false
                    return
                }
                
                coordinator.highlightNextBar = true
                coordinator.path.append(1.1)
                buttonLoading = false
            }
        }
    }
}

#Preview {
    EnterPhoneNumberScreen()
        .frameTop()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
}
