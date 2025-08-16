//
//  CliqueRelationshipFetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 2/26/25.
//

import SwiftUI

struct CliqueRelationshipModifier: ViewModifier {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(AuthService.self) private var authService
    @Environment(CliqueStore.self) private var cliqueStore
    
    var cid: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    guard authService.appViewType == .main else { return }
                    
                    do {
                        try await fetchCliqueRelationshipOrReturn(cid: cid, cliqueStore)
                    } catch {
                        print(error)
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
    }
}

extension View {
    func fetchCliqueRelationship(cid: String?) -> some View {
        self.modifier(CliqueRelationshipModifier(cid: cid))
    }
}


func fetchCliqueRelationshipOrReturn(cid: String?, _ cliqueStore: CliqueStore) async throws {
    guard let cid else { return }
    
    if let clique = await cliqueStore.cliques[cid] {
        if clique.relationship == nil {
            let relationship = try await CliqueService.getCliqueRelationship(.init(path: .init(cliqueId: cid)))
            
            await MainActor.run {
                cliqueStore.cliques[cid]?.relationship = relationship
            }
        }
    } else {
        var clique = try await CliqueService.getCliqueById(id: cid)
        let relationship = try await CliqueService.getCliqueRelationship(.init(path: .init(cliqueId: cid)))
        
        clique.relationship = relationship
        
        await cliqueStore.updateClique(clique)
    }
}
