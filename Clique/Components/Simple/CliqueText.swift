//
//  CliqueText.swift
//  Clique
//
//  Created by Rod Tavangar on 1/8/25.
//

import SwiftUI

enum CliqueTextType {
    case primary
    case secondary
    
    var textColor: Color {
        switch self {
        case .primary:
            return .theme.textPrimary
        case .secondary:
            return .theme.textSecondary
        }
    }
    
    var bgColor: Color {
        switch self {
        case .primary:
            return .clear
        case .secondary:
            return .theme.surfacesElevatedPrimary
        }
    }
}

struct CliqueText: View {
    let text: String
    let type: CliqueTextType
    
    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(type.textColor)
            
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(type.bgColor)
        .roundCorners(8)
        .if(type == .primary) { view in
            view
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .inset(by: -0.5)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 1)
                )
        }
    }
}

#Preview {
    CliqueText(text: "Text", type: .secondary)
}
