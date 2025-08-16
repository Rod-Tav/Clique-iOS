//
//  CliqueFetcher.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import SwiftUI

struct FetchCliqueModifier: ViewModifier {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(CliqueStore.self) private var cliqueStore
    
    var cid: String?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    do {
                        try await fetchClique(cid: cid, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
    }
}

extension View {
    func fetchClique(cid: String?) -> some View {
        self.modifier(FetchCliqueModifier(cid: cid))
    }
}

private func fetchClique(cid: String?, _ cliqueStore: CliqueStore) async throws {
    guard let cid, await cliqueStore.cliques[cid] == nil else { return }
    
    let collectionClique = try await CliqueService.getCliqueById(id: cid)
    
    await cliqueStore.updateClique(collectionClique)
}
