//
//  DeleteButton.swift
//  Clique
//
//  Created by Rod Tavangar on 2/25/25.
//

import SwiftUI

struct DeleteButton: View {
    var action: () -> Void = {}
    
    var body: some View {
        Button(role: .destructive) {
            action()
        } label: {
            Text("Delete")
            
            Image("delete")
                .color(.theme.red)
        }
    }
}
