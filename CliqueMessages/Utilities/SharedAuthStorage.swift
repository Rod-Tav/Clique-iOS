//
//  SharedAuthStorage.swift
//  CliqueMessages
//
//  Wraps SharedAuthState for the extension's authentication checks.
//

import Foundation

struct SharedAuthStorage {
    var isAuthenticated: Bool {
        ExtensionAuthManager.shared.isAuthenticated
    }
}
