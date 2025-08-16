//
//  ExpandedPfpView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/18/25.
//

import SwiftUI

struct ExpandedPfpView<Content: View>: View {
    @ViewBuilder let view: Content
    
    var body: some View {
        ZoomContainer {
            VStack(spacing: 0) {
                TopBarXIcon()
                
                Spacer()
                
                view
                    .pinchZoom(dimsBackground: false)
                    .swipeDownToDismiss()
                
                Spacer()
            }
        }
    }
}
