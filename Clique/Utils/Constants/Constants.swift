//
//  Constants.swift
//  Clique
//
//  Created by Rod Tavangar on 7/16/24.
//

import SwiftUI
import SwiftUINavigationTransitions

// MARK: - Colors
struct Constants {
    static let white90: Color = Color(red: 255, green: 255, blue: 255, opacity: 0.9)
    static let black90: Color = Color(red: 0, green: 0, blue: 0, opacity: 0.9)
    static let black15: Color = Color(red: 0, green: 0, blue: 0, opacity: 0.15)
    static let buttonColor: Color = Color(red: 0, green: 41 / 255, blue: 255 / 255)
    static let textButtonColor: Color = Color(red: 133 / 255, green: 152 / 255, blue: 254 / 255)
}

// MARK: - Ratios
extension Constants {
    static let expandedBannerRatio: CGFloat = (390.0 / 267.0)
    static let collapsedBannerRatio: CGFloat = (390.0 / 119.0)
    static let collectionPreviewRatio: CGFloat = (128.6666667 / 160.0)
    static let collectionCoverPreviewRatio: CGFloat = (359.0 / 208.0)
    static let collectionCarouselSelectedRatio: CGFloat = (56.68310546875 / 68.503173828125)
    static let collectionCarouselRatio: CGFloat = (36.66461181640625 / 52)
    /// posts
    static let portraitPostRatio: CGFloat = (3.0 / 4.0)
    static let squarePostRatio: CGFloat = (1.0 / 1.0)
    static let landscapePostRatio: CGFloat = (4.0 / 3.0)
    /// collection image
    static let collectionImageDetailRatio: CGFloat = (3.0 / 4.0)
    static let wordmarkRatio: CGFloat = (151.0 / 35.0)
}

// MARK: - Scale Factors
extension Constants {
   
}

// MARK: - Numbers
extension Constants {
    static let transitionShrinkFactor: CGFloat = 0.9
    
    static let commentAutoScrollInterval: CGFloat = 4000 // milliseconds
    
    
    static let countryPhoneCodes: [String: String] = [
        "US": "+1", "CA": "+1", "GB": "+44", "FR": "+33", "DE": "+49",
        "IT": "+39", "ES": "+34", "AU": "+61", "JP": "+81", "CN": "+86",
        "IN": "+91", "BR": "+55", "MX": "+52", "RU": "+7", "ZA": "+27",
        "KR": "+82", "SE": "+46", "NO": "+47", "DK": "+45", "FI": "+358",
        "NL": "+31", "BE": "+32", "CH": "+41", "AT": "+43", "IE": "+353",
        "NZ": "+64", "SG": "+65", "HK": "+852", "AE": "+971", "SA": "+966",
        "AR": "+54", "CL": "+56", "CO": "+57", "TH": "+66", "MY": "+60",
        "PH": "+63", "ID": "+62", "PK": "+92", "EG": "+20", "NG": "+234",
        "KE": "+254", "GH": "+233", "ZW": "+263", "TR": "+90", "GR": "+30",
        "PT": "+351", "PL": "+48", "CZ": "+420", "HU": "+36", "RO": "+40",
        "BG": "+359", "HR": "+385", "SI": "+386", "SK": "+421", "UA": "+380",
        "IL": "+972", "IQ": "+964", "IR": "+98", "VN": "+84"
    ]
    
    static let collectionPreviewGridBgHeight: CGFloat = 7.03
}
    
// MARK: - Heights
extension Constants {
    @MainActor static let bottomTabBarHeight: CGFloat = UIScreen.height * (66.0 / 835.0)
    static let tabBarIndicatorHeight: Double = 2.5
    
    //    static let screenCornerRadius: CGFloat = DeviceValues.screenCornerRadius()
}

// MARK: - Navigation
extension Constants {
    static let mainTransition: AnyNavigationTransition =
    .mainSlide.animation(.easeOut(duration: 0.17))
//        .mainSlide.animation(.interpolatingSpring(stiffness: 125, damping: 21.9, initialVelocity: 12))
//        .mainSlide.animation(.interpolatingSpring(stiffness: 300, damping: 30))
    
}

