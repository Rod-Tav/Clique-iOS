//
//  ExtensionAuthManager.swift
//  CliqueMessages
//
//  Reads shared authentication state written by the main Clique app.
//

import Foundation

class ExtensionAuthManager {
    static let shared = ExtensionAuthManager()

    private init() {}

    /// Whether a valid (non-expired) auth token is available.
    var isAuthenticated: Bool {
        getAuthToken() != nil
    }

    /// Returns the Firebase ID token if it exists and has not expired.
    func getAuthToken() -> String? {
        guard let state = SharedAuthState.load() else { return nil }
        if let expiresAt = state.expiresAt, expiresAt < Date() { return nil }
        return state.firebaseToken
    }

    /// Returns the current user's ID, or nil if not authenticated.
    func getUserId() -> String? {
        SharedAuthState.load()?.userId
    }

    /// Returns the current user's username, or nil if not authenticated.
    func getUsername() -> String? {
        SharedAuthState.load()?.username
    }
}
