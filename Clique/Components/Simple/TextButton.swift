//
//  TextButton.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

struct TextButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.theme.buttonText)
                .contentShape(.rect)
        }
    }
}
