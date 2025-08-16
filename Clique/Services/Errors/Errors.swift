//
//  Errors.swift
//  Clique
//
//  Created by Rod Tavangar on 1/22/25.
//

import Foundation

enum ServiceError: Error {
    case userNotAuthenticated
    case userDoesNotExist
    
    case somethingWentWrong
    case uploadFailed
}
