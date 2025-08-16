//
//  HeroOverlayModifier.swift
//  Clique
//
//  Created by Rod Tavangar on 1/20/25.
//

import SwiftUI

struct HeroSourceModifier: ViewModifier {
    @Environment(HeroCoordinator.self) private var heroCoordinator
    
    var urls: PhotoUrls?
    let action: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            HeroSourceBox(urls: urls)
            
            content
                .opacity(heroCoordinator.imageUrls?.highQualityUrl == urls?.highQualityUrl ? 0 : 1)
                .onTapGesture {
                    action()
                    heroCoordinator.imageUrls = urls
                }
        }
        .contentShape(.rect)
    }
}

extension View {
    func heroSource(urls: PhotoUrls?, action: @escaping () -> Void) -> some View {
        self.modifier(HeroSourceModifier(urls: urls, action: action))
    }
}

struct HeroSourceBox: View {
    var urls: PhotoUrls?
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .anchorPreference(key: HeroKey.self, value: .bounds, transform: { anchor in
                guard let url = urls?.highQualityUrl else { return [:] } // Safely unwrap
                return [url + "SOURCE": anchor] // ✅ Now it's non-optional
            })
    }
}

struct HeroOverlayModifier<DetailView: View>: ViewModifier {
    @Environment(HeroCoordinator.self) private var heroCoordinator
    
    let detailView: () -> DetailView
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if heroCoordinator.imageUrls != nil {
                    detailView()
                        .allowsHitTesting(heroCoordinator.showDetailView)
                }
            }
            .overlayPreferenceValue(HeroKey.self) { value in
                if let selectedImage = heroCoordinator.imageUrls?.highQualityUrl, // ✅ Access the high-quality url
                   let sAnchor = value[selectedImage + "SOURCE"],
                   let dAnchor = value[selectedImage + "DEST"] {
                    HeroLayer(
                        sAnchor: sAnchor,
                        dAnchor: dAnchor
                    )
                }
            }
    }
}

extension View {
    func heroOverlay<DetailView: View>(@ViewBuilder detailView: @escaping () -> DetailView) -> some View {
        self.modifier(HeroOverlayModifier(detailView: detailView))
    }
}

//struct HeroBackgroundModifier<DetailView: View>: ViewModifier {
//    @Environment(HeroCoordinator.self) private var heroCoordinator
//    
//    let detailView: () -> DetailView
//    
//    func body(content: Content) -> some View {
//        content
//            .overlay {
//                if heroCoordinator.imageUrls != nil {
//                    detailView()
//                        .allowsHitTesting(heroCoordinator.showDetailView)
//                }
//            }
//            .overlayPreferenceValue(HeroKey.self) { value in
//                if let selectedImage = heroCoordinator.imageUrls?.url,
//                   let sAnchor = value[selectedImage + "SOURCE"],
//                   let dAnchor = value[selectedImage + "DEST"] {
//                    HeroLayer(
//                        sAnchor: sAnchor,
//                        dAnchor: dAnchor
//                    )
//                }
//            }
//    }
//}
//
//extension View {
//    func heroBackground<DetailView: View>(@ViewBuilder detailView: @escaping () -> DetailView) -> some View {
//        self.modifier(HeroOverlayModifier(detailView: detailView))
//    }
//}
