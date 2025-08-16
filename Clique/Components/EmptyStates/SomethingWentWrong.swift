//
//  SomethingWentWrong.swift
//  Clique
//
//  Created by Rod Tavangar on 1/25/25.
//

import SwiftUI

struct SomethingWentWrong: View {
    var action: (() async -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await action?() }
            } label: {
                IconImage("refresh", color: .theme.iconPrimary, size: 32)
            }
            
            Text("Something went wrong. Tap to refresh.")
                .textPrimary()
                .multilineTextAlignment(.center)
                .font(.footnote)
        }
        .infiniteFrame()
    }
}

