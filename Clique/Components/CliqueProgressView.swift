//
//  CliqueProgressView().swift
//  Clique
//
//  Created by Rod Tavangar on 2/1/25.
//

import SwiftUI

struct CliqueProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var rotationAngle: Double = 0
    
    var speed: Double = 0.8 // default speed for loading
    var forceLight: Bool = false
    var size: CGFloat = 20
    
    var body: some View {
        Image(forceLight ? "splash-dark" : colorScheme == .light ? "splash" : "splash-dark")
            .resizable()
            .frame(forceLight ? size * 0.6 : colorScheme == .light ? size : size * 0.6)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                withAnimation(.linear.speed(speed).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
//        ProgressView()
    }
}

#Preview {
    CliqueProgressView()
}
