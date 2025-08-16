//
//  WelcomeToCliqueScreen.swift
//  Clique
//
//  Created by Quinn Liu on 1/24/25.
//

import SwiftUI
import Toasts

struct WelcomeToCliqueScreen: View {
    @Environment(\.presentToast) private var presentToast
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(UserStore.self) private var userStore
    
    @Environment(AuthService.self) private var authService
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(AuthFlowViewModel.self) private var viewModel
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .center, spacing: 96) {
            VStack(spacing: 8) {
                Text("Welcome to Clique!")
                    .textPrimary()
                    .font(.largeTitle.bold())
                
                Text("You're all set! Now let's create your first Clique and start sharing.")
                    .textSecondary()
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                CliqueCard()
                
                // TODO: pull up share
//                SmallCTA(type: .secondary, leadingIcon: "share" ,text: "Share your card") {
//                }
            }
        }
        .onAppear {
            requestPushNotificationPermissions()
            
            coordinator.backButtonAction = {}
            coordinator.isRootOfStep = true
            
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveDeviceToken)) { notification in
            Task {
                do {
                    try saveToken(notification)
                } catch  {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
    }
    
    // MARK: Card
    @ViewBuilder private func CliqueCard() -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                let width = UIScreen.width * ScaleFactors.smallWordmark
                
                Image(colorScheme == .light ? "wordmark-light" : "wordmark-dark")
                    .resizable()
                    .frame(width: width, height: width / Constants.wordmarkRatio)
                
                Spacer()
                
                if let joinNumber = viewModel.joinNumber {
                    Text("#\(joinNumber)")
                        .font(.footnote.bold())
                        .textSecondary()
                }
            }
            
            VStack(spacing: 16) {
                Group {
                    if let profilePic = viewModel.profilePic {
                        Image(uiImage: profilePic)
                            .resizable()
                            .scaledToFill()
                            .frame(96)
                            .clipShape(.circle)
                            .overlay(
                                Circle()
                                    .inset(by: -0.25)
                                    .stroke(Color.theme.strokeTertiary, lineWidth: 1.5)
                            )
                    } else {
                        Image("default-gradient")
                            .frame(width: 96, height: 96)
                            .splashBackground()
                            .clipShape(.circle)
                            .overlay(
                                Circle()
                                    .inset(by: -0.25)
                                    .stroke(Color.theme.strokeSecondary, lineWidth: 1.5)
                            )
                    }
                }
                
                VStack(spacing: 0) {
                    Text("\(viewModel.firstName) \(viewModel.lastName)")
                        .font(.system(size: 24).weight(.black))
                        .minimumScaleFactor(0.2)
                        .lineLimit(1)
                        .textPrimary()
                    
                    Text("@\(viewModel.username)")
                        .font(.callout.weight(.semibold))
                        .textSecondary()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(width: 197, alignment: .center)
        .primaryBackground()
        .roundCorners(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: -2.5)
                .stroke(Color.theme.strokeTertiary, lineWidth: 5)
        )
    }
}

// MARK: - Bottom Button
extension WelcomeToCliqueScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: "Done"
        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        userStore.updateUser(viewModel.registeredUser!) // must exist
        authService.appViewType = .main
    }
}

#Preview {
    WelcomeToCliqueScreen()
        .environment(TopIconFlowCoordinator())
        .environment(AuthFlowViewModel())
        .environment(UserStore())
        .environment(AuthService(UserStore()))
}
