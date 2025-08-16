//
//  SmallCTA.swift
//  Clique
//
//  Created by Rod Tavangar on 12/4/24.
//

import SwiftUI

enum SmallCTAType {
    case primary
    case secondary
    case tertiary
    case postPicker
    
    var buttonColor: Color {
        switch self {
        case .primary:
                .theme.buttonCTA
        case .secondary, .tertiary:
                .theme.buttonTertiary
        case .postPicker:
                .theme.surfacesElevatedPrimary
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary:
                .theme.buttonContent
        case .secondary:
                .theme.textPrimary
        case .tertiary:
                .theme.textTertiary
        case .postPicker:
                .theme.white
        }
    }
}

struct SmallCTA: View {
    let type: SmallCTAType
    var leadingIcon: String?
    var text: String = ""
    var textColor: Color?
    var buttonColor: Color?
    var action: () -> Void = { }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let leadingIcon {
                    IconImage(leadingIcon, color: textColor ?? type.foregroundColor, size: 12)
                }
                
                if text != "" {
                    Text(text)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(textColor ?? type.foregroundColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)
            .padding(.bottom, 4)
            .background(buttonColor ?? type.buttonColor)
            .clipShape(.capsule)
        }
    }
}

#Preview {
    SmallCTA(type: .secondary, leadingIcon: "plus", text: "Add", action: {})
}
