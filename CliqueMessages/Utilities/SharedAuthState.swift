//
//  SharedAuthState.swift
//  CliqueMessages
//
//  Mirror of the main app's SharedAuthState for reading auth from the shared Keychain.
//

import Foundation
import Security

struct SharedAuthState: Codable {
    var firebaseToken: String?
    var userId: String?
    var username: String?
    var expiresAt: Date?

    private static let keychainService = "com.cliquellc.clique.shared"
    private static let keychainAccount = "authState"
    private static let accessGroup = "group.com.cliquellc.clique"

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
}
