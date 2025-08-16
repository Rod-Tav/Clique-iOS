//
//  FlickCliqueMembersView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/26/25.
//

import SwiftUI
import Toasts

struct FlickCliqueMembersView: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @State private var cliqueMembersVM: CliqueProfileViewModel
    
    @State private var showCliqueMembers: Bool = false
    
    let cid: String
    
    init(cid: String) {
        self.cid = cid
        self.cliqueMembersVM = .init(cid: cid)
    }
    
    var body: some View {
        ZStack {
            if !cliqueMembersVM.firstXMembers.isEmpty {
                CliqueCircularMembersView(
                    members: cliqueMembersVM.firstXMembers,
                    memberLimit: 5,
                    type: .medium,
                    forceDark: true
                )
                .onHighPriorityTap {
                    showCliqueMembers.toggle()
                }
                .sheet(isPresented: $showCliqueMembers) { // TODO: DRY
                    CliqueMembersListSheetView(cid: cid, fromFeed: true, userStore, cliqueStore)
                        .presentationDetents([.fraction(0.35), .fraction(0.999)])
                        .bottomSheetModifiers()
                }
            }
        }
        .onAppear {
            Task {
                guard let clique = cliqueStore.cliques[cid], cliqueMembersVM.firstXMembers.count < min(clique.numMembers, 5) else { return }
                do {
                    try await cliqueMembersVM.fetchCliqueFirstXMembers(count: 5, total: clique.numMembers, userStore, cliqueStore)
                } catch {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
    }
}
