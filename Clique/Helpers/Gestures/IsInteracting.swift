//
//  IsInteracting.swift
//  Clique
//
//  Created by Rod Tavangar on 2/17/25.
//

import SwiftUI

struct IsInteracting: ViewModifier {
    @GestureState var isInteracting: Bool = false
    @Binding var isScrolling: Bool
    
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture()
                    .updating($isInteracting) { _, gestureState, _ in
                        if !isInteracting {
                            gestureState = true
                        }
                    }
            )
            .onChange(of: isInteracting) {
                isScrolling = isInteracting
            }
    }
}

extension View {
    func isInteracting(_ isScrolling: Binding<Bool>) -> some View {
        self.modifier(IsInteracting(isScrolling: isScrolling))
    }
}
