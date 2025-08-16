//
//  TopAppBar.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

enum TopAppBarType {
    case small
    case smallClique
    case medium
    
    var iconColor: Color {
        switch self {
        case .small, .medium:
            return .theme.iconPrimary
        case .smallClique:
            return .theme.white
        }
    }
}

struct TopAppBar<LeadingIcon: View, Header: View, TrailingIcon: View>: View {
    let type: TopAppBarType
    @ViewBuilder var leadingIcon: LeadingIcon
    @ViewBuilder var header: Header
    @ViewBuilder var trailingIcon: TrailingIcon

    var body: some View {
        if type == .medium {
            HStack(spacing: 12) {
                leadingIcon
                
                header
                
                Spacer()
                
                trailingIcon
            }
        } else {
            HStack(spacing: 0) {
                leadingIcon
                
                Spacer()
                
                header
                
                Spacer()
                
                trailingIcon
            }
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var color: Color = .theme.iconPrimary
    let size: CGFloat
    var needsHighPriorityTap: Bool = false
    var customAction: (() -> Void)? = nil
    
    var body: some View {
        if needsHighPriorityTap {
            label
                .onHighPriorityTap { action() }
        } else {
            Button {
                action()
            } label: {
                label
            }.buttonStyle(.noHighlight)
        }
    }
    
    private var label: some View {
        IconImage("arrow-left", color: color, size: size)
    }
}

private extension BackButton {
    func action() {
        if let customAction {
            customAction()
        } else {
            dismiss()
        }
    }
}

struct EllipsisImage: View {
    let color: Color
    let size: CGFloat
    
    var body: some View {
        IconImage("ellipsis", color: color, size: size)
    }
}
