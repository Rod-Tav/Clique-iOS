//
//  Theme.swift
//  Clique
//
//  Created by Rod Tavangar on 7/17/24.
//

import SwiftUI

enum Theme: String, CaseIterable {
    case systemDefault = "Default"
    case light = "Light"
    case dark = "Dark"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .systemDefault: nil
        case .light: .light
        case .dark: .dark
        }
    }
    
    var title: String {
        switch self {
        case .systemDefault: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
