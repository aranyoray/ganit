import Foundation
import Security
import CryptoKit

// MARK: - Encrypted Storage

/// AES-GCM encrypted storage backed by UserDefaults with Keychain master key.
/// Extracted from ganit_base/SecureStoring.swift with cleaner Codable-first API.
final class EncryptedStorage: StorageProvider {

    static let shared = EncryptedStorage()

    private let service = "com.ganit.app"
    private let masterKeyAccount = "masterKey"
    private var cachedMasterKey: SymmetricKey?

    private init() {}

    // MARK: - StorageProvider Conformance

    func read(_ key: String, user: String) -> String {
        let compositeKey = "\(user)_\(key)"
        guard let data = UserDefaults.standard.data(forKey: compositeKey),
              let box = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(box, using: masterKey) else {
            return ""
        }
        return String(data: decrypted, encoding: .utf8) ?? ""
    }

    @discardableResult
    func save(_ key: String, value: String, user: String) -> Bool {
        guard !user.isEmpty, let data = value.data(using: .utf8) else { return false }
        return encrypt(data: data, forKey: "\(user)_\(key)")
    }

    @discardableResult
    func saveCodable<T: Codable>(_ key: String, value: T, user: String) -> Bool {
        guard !user.isEmpty else { return false }
        do {
            let json = try JSONEncoder().encode(value)
            return encrypt(data: json, forKey: "\(user)_\(key)")
        } catch {
            print("[EncryptedStorage] Codable encode failed for \(key): \(error)")
            return false
        }
    }

    func readCodable<T: Codable>(_ key: String, as type: T.Type, user: String) -> T? {
        let compositeKey = "\(user)_\(key)"
        guard let data = UserDefaults.standard.data(forKey: compositeKey),
              let box = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(box, using: masterKey) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: decrypted)
    }

    func savePassword(username: String, password: String) {
        guard let passwordData = password.data(using: .utf8) else { return }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: username
            ]
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: passwordData] as CFDictionary)
        }
    }

    func loadPassword(username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    // MARK: - Session Record Batch Save

    /// Saves an entire session record at once (batch write pattern).
    @discardableResult
    func saveSession(_ session: SessionRecord, user: String) -> Bool {
        saveCodable("session_\(session.id.uuidString)", value: session, user: user)
    }

    func loadSession(_ sessionId: UUID, user: String) -> SessionRecord? {
        readCodable("session_\(sessionId.uuidString)", as: SessionRecord.self, user: user)
    }

    /// Save/load session ID list for a user.
    func saveSessionIndex(_ ids: [UUID], user: String) {
        saveCodable("sessionIndex", value: ids, user: user)
    }

    func loadSessionIndex(user: String) -> [UUID] {
        readCodable("sessionIndex", as: [UUID].self, user: user) ?? []
    }

    // MARK: - Risk Assessment Storage

    @discardableResult
    func saveScreeningResults(_ results: [ScreeningResult], user: String) -> Bool {
        saveCodable("screeningResults", value: results, user: user)
    }

    func loadScreeningResults(user: String) -> [ScreeningResult] {
        readCodable("screeningResults", as: [ScreeningResult].self, user: user) ?? []
    }

    // MARK: - Data Deletion

    /// Deletes all encrypted data for a specific user from UserDefaults.
    func deleteAllData(for user: String) {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        let userPrefix = "\(user)_"
        for key in allKeys where key.hasPrefix(userPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Deletes a user's password from the Keychain.
    func deletePassword(username: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Helpers

    private var masterKey: SymmetricKey {
        if let cached = cachedMasterKey { return cached }

        if let keyData = loadKeyData(account: masterKeyAccount) {
            let key = SymmetricKey(data: keyData)
            cachedMasterKey = key
            return key
        }

        let newKey = SymmetricKey(size: .bits256)
        let raw = newKey.withUnsafeBytes { Data($0) }
        saveKeyData(raw, account: masterKeyAccount)
        cachedMasterKey = newKey
        return newKey
    }

    private func encrypt(data: Data, forKey compositeKey: String) -> Bool {
        do {
            let sealed = try AES.GCM.seal(data, using: masterKey)
            guard let combined = sealed.combined else { return false }
            UserDefaults.standard.set(combined, forKey: compositeKey)
            return true
        } catch {
            print("[EncryptedStorage] Encryption failed for \(compositeKey): \(error)")
            return false
        }
    }

    private func saveKeyData(_ data: Data, account: String) {
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    private func loadKeyData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return data
    }
}

// MARK: - API Key Storage

extension EncryptedStorage {
    private static let apiKeyAccount = "geminiAPIKey"

    func saveAPIKey(_ key: String) {
        saveKeyData(Data(key.utf8), account: Self.apiKeyAccount)
    }

    func loadAPIKey() -> String? {
        guard let data = loadKeyData(account: Self.apiKeyAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
