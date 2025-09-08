//
//  AppConfig.swift
//  Clique
//
//  Created by Rod Tavangar on 1/27/25.
//

import Foundation

enum ServerEnvironment {
    case development, production
    
    var serverURL: URL {
        switch self {
        case .development:
           URL(string: "http://accbf7e7599704f989a582ebfcf59ca4-1759478004.us-east-2.elb.amazonaws.com:8080")!
        case .production:
            URL(string: "https://api.example.com")!
        }
    }
}

struct AppConfig {
    static let currentEnvironment: ServerEnvironment = .development
    static let serverURL: URL = currentEnvironment.serverURL
    
    static let currentVersion: String = "1.6.4"
}
