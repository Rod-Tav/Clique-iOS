//
//  CliqueButton.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

enum CliqueButtonType {
    case primary
    case secondary
    case tertiary
    
    var buttonColor: Color {
        switch self {
        case .primary: return .theme.buttonCTA
        case .secondary: return .theme.buttonTertiary
        case .tertiary: return .clear
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary: return .theme.buttonContent
        case .secondary: return .theme.iconPrimary
        case .tertiary: return .theme.textSecondary
        }
    }
}

// TODO: ButtonStyle support
struct CliqueButton: View {
    let type: CliqueButtonType
    
    var leadingIcon: String?
    var leadingIconColor: Color?
    
    let text: String
    var textColor: Color?
    var size: CGFloat = 16
    var fontWeight: (Font.Weight)?
    var buttonColor: Color?
    
    var fullWidth: Bool = false
    var alignment: Alignment = .center
    var isLoading = false
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 8) {
                    if isLoading {
                        CliqueProgressView(forceLight: true)
                            .frame(16)
                    } else {
                        if let leadingIcon {
                            IconImage(name: leadingIcon, color: leadingIconColor ?? textColor ?? type.textColor, size: size)
                        }
                        
                        Text(text)
                            .font(type == .tertiary ? .footnote : .callout)
                            .fontWeight(fontWeight ?? (type == .primary ? .bold : .regular))
                            .foregroundStyle(textColor ?? type.textColor)
                    }
                }
                .if(fullWidth) { view in
                    view
                        .maxWidth(alignment)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassButton(backgroundColor: buttonColor ?? type.buttonColor)
            .if(type == .tertiary) { view in
                view
                    .overlay(
                        Capsule()
                            .inset(by: 0.5)
                            .stroke(Color.theme.strokeSecondary, lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
        }
//        .buttonStyle(.bounce)
    }
}

#Preview {
    CliqueButton(type: .secondary, leadingIcon: "search", text: "Button", action: {})
}
