//
//  CollectionVisibilityButton.swift
//  Clique
//
//  Created by Quinn Liu on 3/20/25.
//

import SwiftUI

struct CollectionVisibilityButton: View {
    let visibility: Visibility
    
    @Binding var collectionVisibility: Visibility
    
    private var isSelected: Bool {
        collectionVisibility == visibility
    }
    
    var body: some View {
        Button {
            collectionVisibility = visibility
        } label: {
            HStack(spacing: 8) {
                IconImage(visibility.icon, color: isSelected ? .theme.textPrimary : .theme.textSecondary, size: 20)
                
                Text(visibility.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.theme.textPrimary : Color.theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .maxWidth()
            .roundCorners(100)
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .inset(by: 0.75)
                    .stroke(isSelected ? Color.theme.textPrimary : Color.theme.textSecondary, lineWidth: 1.5)
            )
            .contentShape(.rect)
        }
    }
}

//#Preview {
//    CollectionVisibilityButton(.followers)
//}
