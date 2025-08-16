//
//  Color.swift
//  Clique
//
//  Created by Rod Tavangar on 11/15/24.
//

import Foundation
import SwiftUI

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    // MARK: - Button
    let buttonCTA = Color("ButtonCTA")
    let buttonTertiary = Color("ButtonTertiary")
    let buttonContent = Color("ButtonContent")
    let buttonText = Color("ButtonText")
    
    // MARK: - Text
    let textPrimary = Color("PrimaryText")
    let textSecondary = Color("SecondaryText")
    let textTertiary = Color("TertiaryText")
    let inversePrimaryText = Color("InversePrimaryText")
    
    // MARK: - Icon
    let iconPrimary = Color("PrimaryIcon")
    let iconSecondary = Color("SecondaryIcon")
    let iconTertiary = Color("TertiaryIcon")
    let iconInversePrimary = Color("InversePrimaryIcon")
    
    // MARK: - Navbar
    let navbarBackground = Color("NavbarBackground")
    let navbarSelectedTab = Color("NavbarSelectedTab")
    let navbarUnselectedTab = Color("NavbarUnselectedTab")
    let navbarShadow = Color("NavbarShadow")
    
    // MARK: - Stroke
    let strokePrimary = Color("PrimaryStroke")
    let strokeSecondary = Color("SecondaryStroke")
    let strokeTertiary = Color("TertiaryStroke")
    let strokeBgMatch = Color("PrimaryBackground")
    
    // MARK: - Surfaces
    // TODO: organize the overlays into Overlays
    let surfacesBackgroundPrimary = Color("PrimaryBackground")
    let surfacesElevatedPrimary = Color("ElevatedPrimary")
    let surfacesElevatedBlur = Color("ElevatedBlur")
    let surfacesElevatedBlurDark = Color("ElevatedBlurDark")
    let surfacesElevatedBlurDarkest = Color("ElevatedBlurDarkest")
    let surfacesImageBgDarkOverlay = Color("ImageBgDarkOverlay")
    let surfacesPrimary = Color("PrimarySurface")
    
    // MARK: - Colors
    let red = Color("ColorRed")
    let purple = Color("ColorPurple")
    let skyblue = Color("ColorSkyblue")
    let lightPink = Color("ColorLightPink")
    let gold = Color("ColorGold")
    let blue = Color("ColorBlue")
    let cliquePink = Color("ColorCliquePink")
    let pink = Color("ColorPink")
    let white = Color("ColorWhite")
    let black = Color("ColorBlack")
    let green = Color("ColorGreen")
    let dark = Color("ColorDark")
    
    // MARK: - Shades
    let shadesWhite95 = Color("White95")
    let shadesWhite65 = Color("White65")
    let shadesWhite50 = Color("White50")
    let shadesWhite30 = Color("White30")
    let shadesWhite15 = Color("White15")
    let shadesElevatedBlurDark = Color("ShadesElevatedBlurDark")
    
     // MARK: - Non-app
    let messages = Color("Messages")
}
