//
//  SwipeDownToDismiss.swift
//  Clique
//
//  Created by Rod Tavangar on 7/10/25.
//

import SwiftUI

struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    
    @State private var dismissOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(dismissOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard value.translation.height > 10 && abs(value.translation.width) < 20 else { return }
                        dismissOffset = CGSize(width: 0, height: value.translation.height)
                    }
                    .onEnded { value in
                        let height = value.translation.height + (value.velocity.height / 5)
                        if height > 10 {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissOffset = .zero
                            }
                        }
                    }
            )
    }
}

extension View {
    func swipeDownToDismiss() -> some View {
        self.modifier(SwipeToDismissModifier())
    }
}
