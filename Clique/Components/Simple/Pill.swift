//
//  Pill.swift
//  Clique
//
//  Created by Rod Tavangar on 12/15/24.
//

import SwiftUI

struct Pill: View {
    var icon: String
    var text: String
    
    var body: some View {
        HStack(spacing: 4) {
            IconImage(name: icon, color: .theme.iconSecondary, size: 12)
            
            Text(text)
                .font(.caption2.bold())
                .textSecondary()
        }
    }
}

struct CollectionPill: View {
    let collection: ClCollection
    
    var body: some View {
        VisibilityPill(visibility: collection.visibility)
    }
}

struct VisibilityPill: View {
    let visibility: Visibility
    
    var body: some View {
        Pill(icon: visibility.icon, text: visibility.title)
    }
}
