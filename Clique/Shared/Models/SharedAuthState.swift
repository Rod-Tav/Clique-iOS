//
//  SharedAuthState.swift
//  Clique
//
//  Bridges authentication state between the main app and extensions via App Group Keychain.
//

import Foundation
import Security

/// Shared authentication state stored in the App Group Keychain so that
/// both the main Clique app and the iMessage extension can read it.
struct SharedAuthState: Codable {
    var firebaseToken: String?
    var userId: String?
    var username: String?
    var expiresAt: Date?

    // MARK: - Keychain Configuration

    private static let keychainService = "com.cliquellc.clique.shared"
    private static let keychainAccount = "authState"
    private static let accessGroup = "group.com.cliquellc.clique"

    // MARK: - Keychain Operations

    /// Saves the auth state to the shared App Group Keychain.
    static func save(_ state: SharedAuthState) {
        guard let data = try? JSONEncoder().encode(state) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Loads the auth state from the shared App Group Keychain.
    static func load() -> SharedAuthState? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SharedAuthState.self, from: data)
    }

    /// Removes the auth state from the shared App Group Keychain.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(query as CFDictionary)
    }
}
