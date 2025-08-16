//
//  Gradients.swift
//  Clique
//
//  Created by Rod Tavangar on 2/1/25.
//

import SwiftUI

struct Gradients {
//    static let splashGradient = EllipticalGradient(
//        stops: [
//            Gradient.Stop(color: Color(red: 0.55, green: 0.63, blue: 0.91).opacity(0), location: 0.00),
//            Gradient.Stop(color: Color(red: 0.55, green: 0.74, blue: 0.91).opacity(0.5), location: 0.27),
//            Gradient.Stop(color: Color(red: 0.55, green: 0.67, blue: 0.91).opacity(0.75), location: 0.66),
//            Gradient.Stop(color: Color(red: 0.55, green: 0.72, blue: 0.91).opacity(0.88), location: 0.77),
//            Gradient.Stop(color: Color(red: 0.55, green: 0.78, blue: 0.91), location: 0.88),
//        ],
//        center: UnitPoint(x: 0.02, y: 0)
//    )
    static let cliqueBanner = LinearGradient(
        stops: [
            Gradient.Stop(color: .black.opacity(0.4), location: 0.00),
            Gradient.Stop(color: .black.opacity(0.35), location: 0.13),
            Gradient.Stop(color: .black.opacity(0), location: 0.44),
        ],
        startPoint: UnitPoint(x: 0.5, y: 0),
        endPoint: UnitPoint(x: 0.5, y: 1)
    )
    static let collectionBannerGradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .black.opacity(0.4), location: 0.00),
            Gradient.Stop(color: .black.opacity(0.35), location: 0.28),
            Gradient.Stop(color: .black.opacity(0), location: 0.56),
        ],
        startPoint: UnitPoint(x: 0.5, y: 0),
        endPoint: UnitPoint(x: 0.5, y: 1)
    )
    static let buttonBgLight = LinearGradient(
        stops: [
            Gradient.Stop(color: .white.opacity(0.5), location: 0.55),
            Gradient.Stop(color: .white.opacity(0), location: 1.00),
        ],
        startPoint: UnitPoint(x: 0.5, y: 1),
        endPoint: UnitPoint(x: 0.5, y: 0.02)
    )
    static let buttonBgDark = LinearGradient(
        stops: [
            Gradient.Stop(color: Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.5), location: 0.55),
            Gradient.Stop(color: Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0), location: 1.00),
        ],
        startPoint: UnitPoint(x: 0.5, y: 1),
        endPoint: UnitPoint(x: 0.5, y: 0.02)
    )
    static let feedCellCommentBg = LinearGradient(
        stops: [
            Gradient.Stop(color: Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0), location: 0.00),
            Gradient.Stop(color: Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.8), location: 1.00),
        ],
        startPoint: UnitPoint(x: 0.5, y: 0),
        endPoint: UnitPoint(x: 0.5, y: 1)
    )
}
