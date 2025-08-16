//
//  NothingHereYetView.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
//

import SwiftUI

struct NothingHereYetView: View {
    var body: some View {
        VStack(spacing: 8) {
            IconImage("search", color: .theme.iconPrimary, size: 32)
            
            Text("Nothing here yet.")
                .font(.footnote)
                .textPrimary()
        }
        .infiniteFrame()
    }
}

struct NothingHereYetAddFlicksView: View {
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    let clique: Clique
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                IconImage("search", color: .theme.iconPrimary, size: 32)
                
                Text("Nothing here yet.\nWhy don’t you add some flicks?")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .textPrimary()
            }
            
            CliqueButton(
                type: .tertiary,
                leadingIcon: "plus",
                text: "Upload Flicks"
            ) {
                tabViewCoordinator.startCreateFlow(for: clique)
            }
        }
    }
}

#Preview {
    NothingHereYetView()
}
