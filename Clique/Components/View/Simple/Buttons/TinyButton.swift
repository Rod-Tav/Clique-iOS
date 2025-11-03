//
//  TinyButton.swift
//  Clique
//
//  Created by Quinn Liu on 2/2/25.
//

import SwiftUI

struct TinyButton: View {
    var body: some View {
        IconImage(name: "ellipsis", color: .theme.iconSecondary, size: 20)
            .padding(2)
            .background(Color.theme.buttonTertiary)
            .clipShape(.circle)
    }
}

#Preview {
    TinyButton()
}
