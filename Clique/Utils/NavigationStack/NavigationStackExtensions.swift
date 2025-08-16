//
//  NavigationStackExetnsions.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI
import SwiftUINavigationTransitions

struct TabNavigationStack<Content: View>: View {
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Binding var path: NavigationPath
    var useRootNavDests: Bool = true
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        NavigationStack(path: $path) {
            content()
                .if(useRootNavDests) { view in
                    view
                        .rootNavigationDestinations()
                }
        }
        .navigationTransition(
            tabViewCoordinator.animation,
            interactivity: tabViewCoordinator.pan
        )
    }
}

//                .slide2.animation(.interpolatingSpring(stiffness: 125, damping: 21.9, initialVelocity: 12)),
//                .zoom.animation(.easeOut(duration: 0.2)),
