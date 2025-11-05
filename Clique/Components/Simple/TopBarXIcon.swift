//
//  TopBarXIcon.swift
//  Clique
//
//  Created by Rod Tavangar on 7/10/25.
//

import SwiftUI

struct TopBarXIcon: View {
    @Environment(\.dismiss) private var dismiss
    
    var color: Color = .theme.iconPrimary
    
    var body: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    dismiss()
                } label: {
                    IconImage(name: "x-icon", color: color, size: 24)
                }.buttonStyle(.noHighlight)
            },
            header: { },
            trailingIcon: {
                Spacer().frame(24)
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}
