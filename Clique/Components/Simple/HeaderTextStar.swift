//
//  HeaderTextStar.swift
//  Clique
//
//  Created by Rod Tavangar on 9/8/25.
//

import SwiftUI

struct HeaderTextStar: View {
    let title: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(title)
                .font(Font.custom("NewakeDemo", size: 24))
                .textPrimary()
            
            IconImage(name: "clique-star", color: Color.theme.cliquePink, size: 8)
        }
    }
}
