//
//  ImageExtensions.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

extension Image {
    func color(_ color: Color) -> some View {
        self
            .renderingMode(.template)
            .foregroundStyle(color)
    }
    
    // MARK: - Expanded Banner Modifiers
    @ViewBuilder func expandedBannerModifiers(type: BannerType, showGradient: Bool = true) -> some View {
        if type == .clique {
            self.cliqueExpandedBannerModifiers(showGradient: showGradient)
        } else {
            self.collectionExpandedBannerModifiers(showGradient: showGradient)
        }
    }
    
    func generalExpandedBannerModifiers() -> some View {
        self
        //            .resizable()
        //            .scaledToFill()
        //            .frame(width: UIScreen.width, height: UIScreen.width / Constants.expandedBannerRatio)
        //            .clipped()
        
            .resizable()
            .scaledToFill()
        //            .frame(minWidth: 0, maxWidth: .infinity)
        //            .frame(minHeight: 0, maxHeight: .infinity)
        //            .aspectRatio(Constants.expandedBannerRatio, contentMode: .fill)
            .frame(width: UIScreen.width, height: UIScreen.width / Constants.expandedBannerRatio)
            .clipped()
    }
    
    func cliqueExpandedBannerModifiers(showGradient: Bool) -> some View {
        self
        //            .resizable()
        //            .scaledToFill()
        //            .containerRelativeFrame(.horizontal)
        //            .frame(height: UIScreen.width / Constants.cliqueBannerRatio)
        
        //            .resizable()
        //            .scaledToFill()
        //            .frame(minWidth: 0, maxWidth: .infinity)
        //            .frame(minHeight: 0, maxHeight: .infinity)
        //            .aspectRatio(Constants.expandedBannerRatio, contentMode: .fill)
        //            .overlay(Constants.cliqueBannerGradient)
        //            .clipped()
        //            .clipTopCorners()
        
            .generalExpandedBannerModifiers()
            .if(showGradient) { view in
                view
                    .overlay(Gradients.cliqueBanner)
            }
    }
    
    func collectionExpandedBannerModifiers(showGradient: Bool) -> some View {
        self
            .generalExpandedBannerModifiers()
            .if(showGradient) { view in
                view
                    .overlay(Gradients.collectionBannerGradient)
            }
    }
    
    // MARK: - Collapsed Banner Modifiers
    @MainActor func collapsedBannerModifiers() -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: UIScreen.width, height: UIScreen.width / Constants.collapsedBannerRatio)
            .overlay(Color.theme.surfacesImageBgDarkOverlay.blur(radius: 1))
            .clipped()
    }
    
    // MARK: - Other Modifiers
    func collectionCoverPreviewModifiers() -> some View {
        self
        //            .resizable()
        //            .aspectRatio(Constants.expandedBannerRatio, contentMode: .fill)
        //            .clipped()
        
        //            .resizable()
        //            .scaledToFill()
        //            .frame(minWidth: 0, maxWidth: .infinity)
        //            .frame(minHeight: 0, maxHeight: .infinity)
        //            .aspectRatio(Constants.collectionCoverPreviewRatio, contentMode: .fill)
        //            .clipped()
            .resizable()
            .scaledToFill()
            .frameRatio(width: UIScreen.width - 32, ratio: Constants.collectionCoverPreviewRatio)
            .roundCorners(8)
    }
    
    func collectionPreviewImageModifiers() -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(minHeight: 0, maxHeight: .infinity)
            .aspectRatio(Constants.collectionPreviewRatio, contentMode: .fill)
            .clipped()
    }
    
    // MARK: - Icon Modifiers
    func iconButton(color: Color = Color.theme.iconPrimary, size: CGFloat = 16, padding: CGFloat = 8) -> some View {
        self
            .resizable()
            .color(color)
            .scaledToFill()
            .frame(size)
            .padding(padding)
    }
    
    func icon(color: Color, size: CGFloat) -> some View {
        self
            .resizable()
            .color(color)
            .frame(size)
    }
}
