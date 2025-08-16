//
//  SwipeUpToOpenCommentsView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/7/25.
//

import SwiftUI

struct SwipeUpToOpenCommentsView: View {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUp: Bool = false
    
    @Binding var show: Bool
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Swipe up to open comments")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.theme.white)
                .multilineTextAlignment(.center)
            
            Image(systemName: "hand.draw.fill")
                .icon(color: .theme.white, size: 100)
                .padding(.top, UIScreen.height / 4)
                .offset(y: offset)
                .opacity(opacity)
                .onAppear {
                    animateSwipeUp()
                }
        }
        .padding(.bottom, 24)
        .infiniteFrame()
        .background(Color.black.opacity(0.5))
        .ignoresSafeArea()
        .onChange(of: hasSwipedUp) { oldValue, newValue in
            guard oldValue == false, newValue == true else { return }
            
            show = false
        }
        .allowsHitTesting(false)
    }
    
    
    private func animateSwipeUp() {
        withAnimation(Animation.easeInOut(duration: 1.5).speed(1.5).repeatForever()) {
            offset = -200 // Move to the top
            opacity = 1 // Fade out at the top
        } completion: {
            offset = 0 // Reset to bottom
            opacity = 0
        }
    }
}

#Preview {
    SwipeUpToOpenCommentsView(show: .constant(true))
}
