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
    
    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.theme.buttonText)
        }
    }
}
