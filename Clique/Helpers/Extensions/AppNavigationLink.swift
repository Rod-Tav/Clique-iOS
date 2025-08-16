//
//  AppNavigationLink.swift
//  Clique
//
//  Created by Rod Tavangar on 12/8/24.
//

import SwiftUI

struct AppNavigationLink<Content: View, Label: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    
    var body: some View {
        NavigationLink {
            content
                .navigationBarBackButtonHidden()
        } label: {
            label
        }
        .buttonStyle(.noHighlight)
//        .id(UUID()) // https://forums.developer.apple.com/forums/thread/720096
    }
}
