//
//  BlockButton.swift
//  Clique
//
//  Created by Rod Tavangar on 2/4/25.
//

import SwiftUI

struct BlockButton: View {
    var action: () -> Void = {}
    
    var body: some View {
        Button(role: .destructive) {
            action()
        } label: {
            Text("Block")
            
            Image(systemName: "slash.circle")
                .color(.theme.red)
        }
    }
}

#Preview {
    BlockButton()
}
