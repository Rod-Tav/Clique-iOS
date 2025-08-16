//
//  ListSelectionItem.swift
//  Clique
//
//  Created by Rod Tavangar on 1/18/25.
//

import SwiftUI

struct ListSelectionItem: View {
    let leadingIcon: String
    let title: String
    let description: String
    let selectedColor: Color
    let unselectedColor: Color
//    var isCheckSecondary: Bool = false
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    IconImage(leadingIcon, color: color, size: 20)
                    
                    Text(title)
                        .font(.callout.bold())
                        .foregroundStyle(color)
                }
                
                Spacer()
                
                IconImage("check-circle-empty", color: color, size: 20)
            }
            
            Text(description)
                .font(.footnote)
                .foregroundStyle(unselectedColor)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.75)
                .stroke(color, lineWidth: 1.5)
        )
    }
    
    // TODO: primary choosing logic refactor
    private var color: Color {
        isSelected ? selectedColor : unselectedColor
    }
}

#Preview {
    ListSelectionItem(leadingIcon: "posts", title: "New Post", description: "Share up to 4 flicks with your Clique.", selectedColor: .theme.iconPrimary, unselectedColor: .theme.surfacesElevatedPrimary, isSelected: false)
}
