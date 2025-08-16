//
//  ScrollViewExtensions.swift
//  Clique
//
//  Created by Rod Tavangar on 12/13/24.
//

import SwiftUI

extension View {
    func scrollBarIgnorePadding(_ size: CGFloat) -> some View {
        self
            .padding(.horizontal, -size)
            .contentMargins(.horizontal, size, for: .scrollContent)
    }
}

extension ScrollView {
    func disableBounce() -> some View {
        self
            .viewExtractor { view in
                if let scrollView = view as? UIScrollView {
                    scrollView.bounces = false
                }
            }
    }
}

struct ScrollTo: ViewModifier {
    @Binding var id: String?

    @ViewBuilder func body(content: Content) -> some View {
        ScrollViewReader { reader in
            content
                .onChange(of: id) { oldValue, newValue in
                    if let newValue {
                        withAnimation {
                            reader.scrollTo(newValue)
                        }
                        id = ""
                    }
                }
        }
    }
}

extension ScrollView {
    func scrollTo(id: Binding<String?>) -> some View {
        modifier(ScrollTo(id: id))
    }

}

//extension TabView {
//    func disableBounce() -> some View {
//        self
//            .viewExtractor { view in
//                if let tabController = view.next as? UITabBarController {
//                    tabController.tabBar
//                }
//            }
//    }
//}
