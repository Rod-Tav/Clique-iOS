//
//  EditMenuButton.swift
//  Clique
//
//  Created by Quinn Liu on 3/20/25.
//

import SwiftUI

struct EditMenuButton: View {
    var action: () -> Void = { }
    
    var body: some View {
        Button {
            action()
        } label: {
            Text("Edit")
            Image("pen")
                .color(.theme.iconPrimary)
        }
    }
}

#Preview {
    EditMenuButton()
}
