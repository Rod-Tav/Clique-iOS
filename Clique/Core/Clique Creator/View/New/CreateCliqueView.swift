//
//  CreateCliqueView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/26/25.
//

import SwiftUI
import Toasts

struct CreateCliqueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var invitedMembers: [User] = []
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            TopAppBar(
                type: .small,
                leadingIcon: {
                    Button {
                        dismiss()
                    } label: {
                        IconImage(name: "x-icon", color: .theme.iconPrimary, size: 24)
                    }.noHighlight()
                },
                header: { },
                trailingIcon: {
                    Button {
                        isLoading = true
                        Task {
                            do {
                                try await createClique()
                                isLoading = false
                            } catch {
                                isLoading = false
                                presentToast(Toasts.somethingWentWrong)
                            }
                        }
                    } label: {
                        if isLoading {
                            CliqueProgressView(size: 24)
                        } else {
                            IconImage(name: "check", color: .theme.iconPrimary, size: 24)
                        }
                    }
                    .noHighlight()
                    .disabled(isLoading)
                }
            )
            
            TopTitle(
                title: "Invite Members to your Clique",
                description: "You can always invite more people once the Clique is created."
            )
            .ignoresSafeArea(.keyboard)
            
            InviteMembersView(userStore: userStore, searchText: $searchText, isSearchFocused: $isSearchFocused, invitedMembers: $invitedMembers)
        }
        .maxHeight(.top)
        .padding(.horizontal, 16)
        .primaryBackground()
    }
    
    private func createClique() async throws {
        guard let firstName = userStore.currentUser?.firstname else {
            presentToast(Toasts.somethingWentWrong)
            return
        }
        
        var clique = try await CliqueService.createClique(.init(body: .json(.init(
            name: firstName + "'s Clique",
            members: invitedMembers.map { $0.id }
        ))))
        
        clique.numMembers = 1
        
        cliqueStore.updateClique(clique)
        
        DispatchQueue.main.async {
            dismiss()
            tabViewCoordinator.navigate(to: clique)
        }
    }
}

#Preview {
    CreateCliqueView()
}
