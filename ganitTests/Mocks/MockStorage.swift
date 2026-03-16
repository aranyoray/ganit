import Foundation
@testable import ganit

// MARK: - Mock Storage Provider

/// In-memory storage for testing. No Keychain, no encryption, no UserDefaults.
class MockStorage: StorageProvider {
    var store: [String: String] = [:]
    var codableStore: [String: Data] = [:]
    var passwords: [String: String] = [:]

    func read(_ key: String, user: String) -> String {
        store["\(user)_\(key)"] ?? ""
    }

    @discardableResult
    func save(_ key: String, value: String, user: String) -> Bool {
        store["\(user)_\(key)"] = value
        return true
    }

    @discardableResult
    func saveCodable<T: Codable>(_ key: String, value: T, user: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        codableStore["\(user)_\(key)"] = data
        return true
    }

    func readCodable<T: Codable>(_ key: String, as type: T.Type, user: String) -> T? {
        guard let data = codableStore["\(user)_\(key)"] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func savePassword(username: String, password: String) {
        passwords[username] = password
    }

    func loadPassword(username: String) -> String? {
        passwords[username]
    }

    func reset() {
        store.removeAll()
        codableStore.removeAll()
        passwords.removeAll()
    }
}
