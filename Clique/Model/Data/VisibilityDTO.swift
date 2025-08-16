//
//  VisibilityDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 2/8/25.
//

import Foundation

enum Visibility: String, Codable, CaseIterable, Identifiable {
    case priv, followers, pub
    
    static let orderedCases: [Visibility] = [.followers, .priv]
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .priv: return "lock"
        case .followers: return "2-user"
        case .pub: return "globe-public"
        }
    }
    
    var title: String {
        switch self {
        case .priv: return "PRIVATE"
        case .followers: return "FOLLOWERS"
        case .pub: return "PUBLIC"
        }
    }
    
    var description: String {
        switch self {
        case .priv: return "Only visible to Clique members."
        case .followers: return "Only visible to Clique members and followers of members."
        case .pub: return "Visible to anyone."
        }
    }
    
    var isPrivate: Bool {
        self == .priv
    }
}

func mapToVisibility(_ data: Components.Schemas.PrivacySetting) -> Visibility {
    switch data {
    case .FOLLOWERS: .followers
    case .PRIVATE: .priv
    case .PUBLIC: .pub
    }
}

func mapFromVisibility(_ data: Visibility) -> Components.Schemas.PrivacySetting {
    switch data {
    case .followers: .FOLLOWERS
    case .priv: .PRIVATE
    case .pub: .PUBLIC
    }
}
