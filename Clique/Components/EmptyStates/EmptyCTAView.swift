//
//  EmptyCTAView.swift
//  Clique
//
//  Created by Rod Tavangar on 1/25/25.
//

import SwiftUI

struct EmptyCTAView: View {
    let icon: String
    let text: String
    let button: CliqueButton
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                IconImage(name: icon, color: .primaryIcon, size: 32)
                
                Text(text)
                    .textPrimary()
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }
            
            button
        }
    }
}

#Preview {
    EmptyCTAView(icon: "search", text: "Clique is way more fun with friends. Let’s add some?", button: CliqueButton(type: .tertiary, leadingIcon: "plus", text: "Add Friends") { })
}
