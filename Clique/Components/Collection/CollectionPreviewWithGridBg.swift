//
//  CollectionPreviewWithGridBg.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI

struct CollectionPreviewWithGridBg<CoverPhoto: View>: View {
    let width: CGFloat
    @ViewBuilder var image: CoverPhoto
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                .frameRatio(width: width, ratio: Constants.collectionCoverPreviewRatio)
                .scaleEffect(0.77, anchor: .top)
                .offset(y: -Constants.collectionPreviewGridBgHeight)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.theme.surfacesBackgroundPrimary)
                .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                .frameRatio(width: width, ratio: Constants.collectionCoverPreviewRatio)
                .scaleEffect(0.90, anchor: .top)
                .offset(y: -Constants.collectionPreviewGridBgHeight / 2)
            
            image
        }
    }
}
