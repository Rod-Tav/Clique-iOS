//
//  PresentWhatsNew.swift
//  Clique
//
//  Created by Rod Tavangar on 3/5/25.
//

import SwiftUI

struct WhatsNewOverlayModifier: ViewModifier {
    @Binding var showWhatsNew: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                Color.theme.black.opacity(0.5)
                    .ignoresSafeArea()
                    .opacity(showWhatsNew ? 1 : 0)
                    .animation(showWhatsNew ? nil : .easeInOut, value: showWhatsNew)
            }
            .overlay {
                WhatsNewView(isPresented: $showWhatsNew)
                    .opacity(showWhatsNew ? 1 : 0)
                    .animation(.easeInOut, value: showWhatsNew)
            }
    }
}

extension View {
    func whatsNewOverlay(showWhatsNew: Binding<Bool>) -> some View {
        self.modifier(WhatsNewOverlayModifier(showWhatsNew: showWhatsNew))
    }
}
