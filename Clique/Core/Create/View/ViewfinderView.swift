//
//  ViewfinderView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/9/25.
//

import SwiftUI

struct ViewfinderView: View {
    @Binding var image: Image?
    @Binding var zoomFactor: CGFloat  // ✅ Add zoom factor binding to sync with CameraDataModel
    
    @State private var lastZoomFactor: CGFloat = 1.0  // ✅ Track gesture state
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(  // ✅ Add pinch-to-zoom gesture
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / self.lastZoomFactor
                                self.lastZoomFactor = value
                                
                                let newZoom = zoomFactor * delta
                                // Clamp the zoom between 1x and 5x (or any value you wish)
                                zoomFactor = max(1.0, min(newZoom, 5.0))  // You can make 5.0 dynamic later
                            }
                            .onEnded { _ in
                                self.lastZoomFactor = 1.0  // Reset for the next gesture
                            }
                    )
                    .clipped()
            } else {
                // Placeholder or empty state
                Color.black
            }
        }
    }
}

#Preview {
    ViewfinderView(image: .constant(Image(systemName: "pencil")), zoomFactor: .constant(1.0))
}
