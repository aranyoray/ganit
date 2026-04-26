import Foundation

// MARK: - Storage Provider Protocol

/// Abstracts encrypted persistence. Implementations use AES-GCM + Keychain.
protocol StorageProvider {
    /// Read a string value for a key and user.
    func read(_ key: String, user: String) -> String

    /// Save a string value for a key and user.
    @discardableResult
    func save(_ key: String, value: String, user: String) -> Bool

    /// Save a Codable value.
    @discardableResult
    func saveCodable<T: Codable>(_ key: String, value: T, user: String) -> Bool

    /// Read a Codable value.
    func readCodable<T: Codable>(_ key: String, as type: T.Type, user: String) -> T?

    /// Save user password to keychain.
    func savePassword(username: String, password: String)

    /// Load user password from keychain.
    func loadPassword(username: String) -> String?
}
