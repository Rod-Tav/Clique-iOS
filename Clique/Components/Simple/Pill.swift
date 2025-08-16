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
            IconImage(icon, color: .theme.iconSecondary, size: 12)
            
            Text(text)
                .font(.caption2.bold())
                .textSecondary()
        }
    }
}

struct CollectionPill: View {
    let collection: ClCollection
    
    init(_ collection: ClCollection) {
        self.collection = collection
    }
    
    var body: some View {
        VisibilityPill(collection.visibility)
    }
}

struct VisibilityPill: View {
    let visibility: Visibility
    
    init(_ visibility: Visibility) {
        self.visibility = visibility
    }
    
    var body: some View {
        Pill(icon: visibility.icon, text: visibility.title)
    }
}
