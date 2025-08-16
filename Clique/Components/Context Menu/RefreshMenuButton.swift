//
//  RefreshButton.swift
//  Clique
//
//  Created by Rod Tavangar on 3/1/25.
//

import SwiftUI

struct RefreshMenuButton: View {
    var action: () -> Void = { }
    
    var body: some View {
        Button {
            action()
        } label: {
            Text("Refresh")
            Image("refresh")
                .color(.theme.iconPrimary)
        }
    }
}

#Preview {
    RefreshMenuButton()
}
