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
                DragGesture(minimumDistance: GestureConstants.minimumRecognitionDistance)
                    .onChanged { value in
                        guard value.translation.height > GestureConstants.minimumVerticalSwipe && abs(value.translation.width) < GestureConstants.maximumHorizontalDeviation else { return }
                        dismissOffset = CGSize(width: 0, height: value.translation.height)
                    }
                    .onEnded { value in
                        let height = value.translation.height + (value.velocity.height / GestureConstants.velocityDampening)
                        if height > GestureConstants.dismissThresholdBasic {
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
