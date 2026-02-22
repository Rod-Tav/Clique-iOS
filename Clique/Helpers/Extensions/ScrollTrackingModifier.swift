//
//  ScrollTrackingModifier.swift
//  Clique
//

import SwiftUI

struct ScrollTrackingModifier: ViewModifier {
    let title: String
    @Binding var showNavBar: Bool

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { g in
                let yFromTop = g.contentOffset.y + g.contentInsets.top
                return yFromTop > 48
            } action: { _, isPastThreshold in
                showNavBar = isPastThreshold
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .opacity(showNavBar ? 1 : 0)
                }
            }
    }
}

extension View {
    func trackScrollWithToolbar(title: String, showNavBar: Binding<Bool>) -> some View {
        modifier(ScrollTrackingModifier(title: title, showNavBar: showNavBar))
    }
}
