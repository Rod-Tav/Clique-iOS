//
//  TopTitle.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI

// TODO: more specific. clique creator only maybe
struct TopTitle: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .kerning(0.0748)
                .textPrimary()
            
            Text(description)
                .font(.footnote)
                .textPrimary()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    TopTitle(title: "Invite Members", description: "You can always invite more people once the Clique is created.")
}
