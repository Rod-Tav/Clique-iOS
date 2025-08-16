//
//  UserStatView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/18/24.
//

import SwiftUI

struct UserStatView: View {
    let value: Int
    let title: String
    var statColor: Color?
    var descColor: Color?
    
    var body: some View {
        HStack {
            Text(formatNumber(value))
                .font(.caption.bold())
                .foregroundStyle(statColor ?? Color.theme.textPrimary) +
            
            // TODO: put ending with s logic here
            Text(" \(title)")
                .font(.caption)
                .foregroundStyle(descColor ?? Color.theme.textSecondary)
        }
        .lineLimit(1)
        // greyed out when stat is 0
//        .opacity(value == 0 ? 0.5 : 1.0)
    }
}

#Preview {
    UserStatView(value: 362000000, title: "Cliques")
}
