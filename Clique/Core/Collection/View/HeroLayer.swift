//
//  HeroLayer.swift
//  Clique
//
//  Created by Rod Tavangar on 6/30/24.
//

import SwiftUI
import Kingfisher

struct HeroLayer: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.displayScale) private var displayScale
    
    @Environment(HeroCoordinator.self) private var heroCoordinator
    
    @State private var loadedImage: UIImage?
    
    var sAnchor: Anchor<CGRect>
    var dAnchor: Anchor<CGRect>
    
    var body: some View {
        GeometryReader { proxy in
            let sRect = proxy[sAnchor]
            let dRect = proxy[dAnchor]
            let animateView = heroCoordinator.animateView
            
            let viewSize: CGSize = .init(
                width: animateView ? dRect.width : sRect.width,
                height: animateView ? dRect.height : sRect.height
            )
            let viewPosition: CGSize = .init(
                width: animateView ? dRect.minX : sRect.minX,
                height: animateView ? dRect.minY : sRect.minY
            )
            
            if let photoUrls = heroCoordinator.imageUrls, !heroCoordinator.showDetailView {
                HeroImageAsyncView(urls: photoUrls, size: viewSize, animateView: animateView) { image in
                    loadedImage = image
                }
                .offset(viewPosition)
                .transition(.identity)
                .opacity(heroCoordinator.animationIsOpen ? 1 : 0)
                
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: animateView ? .fit : .fill)
                        .frame(width: viewSize.width, height: viewSize.height)
                        .clipped()
                        .offset(viewPosition)
                        .transition(.identity)
                        .opacity(heroCoordinator.animationIsOpen ? 0 : 1)
                }
            }
        }
    }
}
    
    //        .gesture(
    //                        DragGesture(minimumDistance: 10)
    //                            .onEnded { value in
    //                                if value.translation.height > 10 {
    //                                    coordinator.earlyClose = true
    //                                    coordinator.toggleView(show: false)
    //                                }
       //                            }
       //                    )

struct HeroKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String : Anchor<CGRect>], nextValue: () -> [String : Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
