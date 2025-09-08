//
//  HeaderTextStar.swift
//  Clique
//
//  Created by Rod Tavangar on 9/8/25.
//

import SwiftUI

struct HeaderTextStar: View {
    private let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(title)
                .font(Font.custom("NewakeDemo", size: 24))
                .textPrimary()
            
            IconImage("clique-star", color: Color.theme.cliquePink, size: 8)
        }
    }
}

#Preview {
    HeaderTextStar("Clique")
}
