//
//  IconOuterStroke.swift
//  Clique
//
//  Created by Kyuho Lee on 1/24/25.
//

import SwiftUI

struct IconOuterStroke<S: Shape>: View {
    let shape: S
    let color: Color
    let size: CGFloat
    var strokeColor: Color? = nil
    var strokeWidth: CGFloat? = nil
    
    var body: some View {
        ZStack {
            shape
                .fill(color, style: FillStyle(eoFill: true))
                .frame(size)
            
            if let strokeColor, let strokeWidth {
                shape
                    .stroke(strokeColor, lineWidth: strokeWidth * 2)
                    .frame(size)
                    .zIndex(-1)
            }
        }
        .frame(size)
    }
}

#Preview {
    IconOuterStroke(shape: CameraIcon(), color: .theme.gold, size: 20, strokeColor: .theme.black, strokeWidth: 2)
}
