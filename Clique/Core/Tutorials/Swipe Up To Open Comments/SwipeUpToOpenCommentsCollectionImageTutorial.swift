//
//  SwipeUpToOpenCommentsCollectionImageTutorial.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import SwiftUI

struct SwipeUpToOpenCommentsCollectionImageModifier: ViewModifier {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUp: Bool = false
    
    @State var show: Bool = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasSwipedUp {
                    show = true
                }
            }
            .overlay {
                if show {
                    SwipeUpToOpenCommentsView(show: $show)
                }
            }
    }
}


extension View {
    func swipeUpToOpenCommentsTutorial() -> some View {
        modifier(SwipeUpToOpenCommentsCollectionImageModifier())
    }
}
