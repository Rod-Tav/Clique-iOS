//
//  NotificationsPill.swift
//  Clique
//
//  Created by Rod Tavangar on 1/11/25.
//

import SwiftUI

struct NotificationsPill: View {
    var body: some View {
        HStack(spacing: 4) {
            IconImage(name: "dot", color: .theme.buttonContent, size: 12)
            
            Text("7 new")
                .font(.caption2.bold())
//                        .fontWeight(.semibold)
                .foregroundStyle(Color.theme.buttonContent)
        }
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .background(Color.theme.red)
        .clipShape(.capsule)
    }
}

#Preview {
    NotificationsPill()
}
