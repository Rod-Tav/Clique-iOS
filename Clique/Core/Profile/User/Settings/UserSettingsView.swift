//
//  UserSettingsView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/17/24.
//

import SwiftUI
import FirebaseAuth
import Toasts

struct UserSettingsView: View {
    @AppStorage("userTheme") private var userTheme: Theme = .systemDefault
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUpToOpenComments: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(AuthService.self) private var authService
    
    @State private var showDeleteAccountAlert: Bool = false
    @State private var privateAccount: Bool = false // TODO: confirm that toggle isn't false and onAppear works for private account
    @State private var notifications: Bool = false
    @State private var showWhatsNew: Bool = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                TopBar()
                
                AppSettingsSection()
            }
            
            FeedPerformanceSettings()
            
            OutlinksSection()
            
            SettingEntry(
                icon: "time-clock-recents",
                settingText: "What's New",
                trailingIcon: {
                    TrailingIcon("chevron-right")
                },
                action: {
                    showWhatsNew = true
                }
            )
            
            DestructiveSection()
            
            Spacer()
            
            Text("Version \(AppConfig.currentVersion)")
                .font(.footnote)
                .textSecondary()
                .maxWidth(.trailing)
        }
        .padding(.horizontal, 16)
        .frameTop()
        .bottomTabBarPadding()
        .padding(.bottom, 16)
        .primaryBackground()
        .onAppear {
            privateAccount = userStore.currentUser?.isPrivate ?? false
        }
        .whatsNewOverlay(showWhatsNew: $showWhatsNew)
    }
}

// MARK: - Top bar
extension UserSettingsView {
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                BackButton(size: 24)
            },
            header: {
                Text("Settings")
                    .textPrimary()
                    .font(.callout.weight(.semibold))
            },
            trailingIcon: { Spacer().frame(24) }
        )
        .padding(.vertical, 12)
    }
}

// MARK: - App settings section
extension UserSettingsView {
    @ViewBuilder private func AppSettingsSection() -> some View {
        VStack(spacing: 8) {
//            SettingEntry(
//                icon: "lock",
//                settingText: "Private Account",
//                trailingIcon: {
//                    Toggle("", isOn: $privateAccount)
//                        .labelsHidden()
//                        .tint(.theme.pink)
//                        .onChange(of: privateAccount) {
//                            haptics(.medium)
//                            
//                            Task {
//                                do {
//                                    _ = try await UserService.editUser(.init(body: .json(.init(isPrivate: privateAccount))))
//                                    
//                                    userStore.users[userStore.currentUserId!]?.isPrivate = privateAccount
//                                } catch {
//                                    privateAccount.toggle()
//                                    presentToast(Toasts.somethingWentWrong)
//                                }
//                            }
//                        }
//                }
//            )
            
            // TODO: Notifications
//            SettingEntry(
//                icon: "inbox",
//                settingText: "Notifications",
//                trailingIcon: {
//                    Toggle("", isOn: $notifications)
//                        .labelsHidden()
//                        .tint(.theme.blue)
//                }
//            )
            
            Menu {
                Button {
                    userTheme = .systemDefault
                } label: {
                    Label {
                        Text("System")
                    } icon: {
                        if userTheme == .systemDefault {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button {
                    userTheme = .light
                } label: {
                    Label {
                        Text("Light")
                    } icon: {
                        if userTheme == .light {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button {
                    userTheme = .dark
                } label: {
                    Label {
                        Text("Dark")
                    } icon: {
                        if userTheme == .dark {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                SettingEntry(
                    icon: "filter",
                    settingText: "Theme",
                    trailingIcon: {
                        HStack(spacing: 5) {
                            Text(userTheme.title)
                                .foregroundStyle(Color.theme.textSecondary)
                                .font(.callout)
                            
                            TrailingIcon("chevron-right")
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Outlinks section
extension UserSettingsView {
    @ViewBuilder private func OutlinksSection() -> some View {
        VStack(spacing: 8) {
//            SettingEntry(
//                icon: "write",
//                settingText: "Rate Clique",
//                trailingIcon: {
//                    TrailingIcon("arrow-up-right")
//                },
//                action: {
//                    print("rate clique")
//                }
//            )
            
            SettingEntry(
                icon: "message",
                settingText: "Send Feedback",
                trailingIcon: {
                    TrailingIcon("arrow-up-right")
                },
                action: {
                    if let url = URL(string: "https://airtable.com/appjitxxXC0ujDGas/pagOXRxv4JIRdXvAL/form") {
                        openURL(url)
                    }
                }
            )
            
            SettingEntry(
                icon: "globe-public",
                settingText: "Privacy",
                trailingIcon: {
                    TrailingIcon("arrow-up-right")
                },
                action: {
                    if let url = URL(string: "https://cliqueapp.org/privacy") {
                        openURL(url)
                    }
                }
            )
        }
    }
}

// MARK: - Log out and delete account
extension UserSettingsView {
    @ViewBuilder private func DestructiveSection() -> some View {
        VStack(spacing: 8) {
            SettingEntry(
                icon: "logout",
                settingText: "Log Out",
                trailingIcon: {
                    TrailingIcon("chevron-right")
                },
                color: .theme.pink,
                action: {
                    // SIGNOUT
                    do {
                        try Auth.auth().signOut()
                        
                        AppService.userToken = ""
                        AuthService.hasMixpanelProfile = false
                        hasSwipedUpToOpenComments = false
                        RecentUsersManager.storedUsersData = Data()
                        
                        userStore.reset()
                        cliqueStore.reset()
                        collectionStore.reset()
                        collectionImageStore.reset()
                        commentStore.reset()
                        
                        authService.appViewType = .auth
                    } catch {
                        print("DEBUG: signout failed")
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            )
            
            SettingEntry(
                icon: "delete",
                settingText: "Delete Account",
                trailingIcon: {
                    TrailingIcon("chevron-right")
                },
                color: .theme.red,
                action: {
                    showDeleteAccountAlert = true
                }
            )
            .alert(isPresented: $showDeleteAccountAlert) {
                Alert(
                    title: Text("Are you sure you want to delete your account?"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        // TODO: delete account
                        print("delete account")
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// MARK: - Setting Entry abstraction
extension UserSettingsView {
    @ViewBuilder private func SettingEntry<TrailingIcon: View>(
        icon: String,
        settingText: String,
        trailingIcon: () -> TrailingIcon,
        color: Color = .theme.iconPrimary,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    IconImage(icon, color: color, size: 20)

                    Text(settingText)
                        .font(.callout)
                        .foregroundStyle(color)
                }
                
                Spacer()
                
                trailingIcon()
            }
            .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
            .contentShape(Rectangle())
        }
        .if(action == nil) { view in
            view
                .buttonStyle(.noHighlight)
        }
    }
}

// MARK: - Helpers
extension UserSettingsView {
    @ViewBuilder private func TrailingIcon(_ name: String) -> some View {
        IconImage(name, color: .theme.iconSecondary, size: 20)
    }
}

#Preview {
    UserSettingsView()
}
