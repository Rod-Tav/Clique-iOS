//
//  CliqueTextFieldModifier.swift
//  Clique
//
//  Created by Rod Tavangar on 7/9/24.
//

import SwiftUI

struct CliqueTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top)
    }
}
