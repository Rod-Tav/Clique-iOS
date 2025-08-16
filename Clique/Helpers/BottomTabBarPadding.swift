//
//  BottomTabBarPadding.swift
//  Clique
//
//  Created by Rod Tavangar on 2/28/25.
//

import SwiftUI

struct BottomTabBarModifier: ViewModifier {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, Constants.bottomTabBarHeight - safeAreaInsets.bottom + 16)
    }
}

extension View {
    func bottomTabBarPadding() -> some View {
        self.modifier(BottomTabBarModifier())
    }
}
