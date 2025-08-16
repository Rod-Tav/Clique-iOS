//
//  TextDivider.swift
//  Clique
//
//  Created by Rod Tavangar on 11/25/24.
//

import SwiftUI

struct TextDivider<Content: View>: View {
    let title: String
    let color: Color
    let content: Content

    init(_ title: String, color: Color = Color.theme.textSecondary, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .frame(height: 1.5)
            
            if Content.self == EmptyView.self {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .layoutPriority(1)
            } else {
                content
            }

            Rectangle()
                .frame(height: 1.5)
        }
        .foregroundStyle(color)
    }
}

#Preview {
    TextDivider("Suggested")
}
