//
//  AuthSplashView.swift
//  Clique
//
//  Created by Quinn Liu on 1/21/25.
//

import SwiftUI

struct AuthSplashView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var coordinator = TopIconFlowCoordinator()
    @State private var viewModel = AuthFlowViewModel()
    
    @State private var showAuthCover: Bool = false
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let width = UIScreen.width * ScaleFactors.wordmark
            Image(colorScheme == .light ? "wordmark-light" : "wordmark-dark")
                .resizable()
                .frame(width: width, height: width / Constants.wordmarkRatio)
            
            VStack(spacing: 16) {
                SignUpButton()
                
//                LogInButton()
                
                TermsConditionsText()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .maxHeight(.bottom)
        .fullScreenCover(isPresented: $showAuthCover) {
            AuthFlowView()
                .environment(viewModel)
        }
        .primaryBackground()
    }
}

// MARK: - Views
extension AuthSplashView {
    @ViewBuilder private func SignUpButton() -> some View {
        Button {
            viewModel.authFlowType = .signup
            showAuthCover = true
        } label: {
            HStack(spacing: 8) {
                Text("Get Started")
                    .font(.callout.bold())
                    .foregroundStyle(Color.theme.buttonContent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .maxWidth()
            .background(Color.theme.cliquePink)
            .clipShape(.capsule)
        }
    }
    
    @ViewBuilder private func LogInButton() -> some View {
        CliqueButton(
            type: .secondary,
            text: "Log In",
            fontWeight: .semibold,
            fullWidth: true
        ) {
            viewModel.authFlowType = .login
            showAuthCover = true
        }
    }
    
    @ViewBuilder private func TermsConditionsText() -> some View {
        Group {
            Text("By continuing, you agree to our ") +
            Text("[Terms](https://cliqueapp.org/terms)")
                .underline() +
            Text(" and ") +
            Text("[Privacy Policy](https://cliqueapp.org/privacy)")
                .underline() +
            Text(".")
        }
        .tint(Color.theme.textTertiary)
        .foregroundStyle(Color.theme.textTertiary)
        .font(.caption2)
    }
}

#Preview {
    AuthSplashView()
}

