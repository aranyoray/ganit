import XCTest
@testable import Ganit

final class AccountDeletionTests: XCTestCase {

    private let testUser = "test_delete_user"

    override func tearDown() {
        super.tearDown()
        EncryptedStorage.shared.deleteAllData(for: testUser)
        EncryptedStorage.shared.deletePassword(username: testUser)
    }

    func testDeleteAllDataRemovesUserDefaults() {
        let storage = EncryptedStorage.shared

        // Save some data
        storage.save("key1", value: "value1", user: testUser)
        storage.save("key2", value: "value2", user: testUser)

        // Verify data exists
        XCTAssertFalse(storage.read("key1", user: testUser).isEmpty)
        XCTAssertFalse(storage.read("key2", user: testUser).isEmpty)

        // Delete all
        storage.deleteAllData(for: testUser)

        // Verify data is gone
        XCTAssertTrue(storage.read("key1", user: testUser).isEmpty)
        XCTAssertTrue(storage.read("key2", user: testUser).isEmpty)
    }

    func testDeletePasswordRemovesKeychain() {
        let storage = EncryptedStorage.shared

        storage.savePassword(username: testUser, password: "test123")
        XCTAssertNotNil(storage.loadPassword(username: testUser))

        storage.deletePassword(username: testUser)
        XCTAssertNil(storage.loadPassword(username: testUser))
    }

    @MainActor
    func testDeleteAccountClearsEverything() {
        let storage = EncryptedStorage.shared
        let authService = AuthService(storage: storage)

        // Create a user with data
        storage.save("profile", value: "test", user: testUser)
        storage.save("sessionIndex", value: "[]", user: testUser)
        storage.savePassword(username: testUser, password: "pass123")

        // Delete account
        authService.deleteAccount(username: testUser)

        // Verify everything is cleared
        XCTAssertTrue(storage.read("profile", user: testUser).isEmpty)
        XCTAssertTrue(storage.read("sessionIndex", user: testUser).isEmpty)
        XCTAssertNil(storage.loadPassword(username: testUser))
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isAuthenticated)
    }

    func testDeleteDoesNotAffectOtherUsers() {
        let storage = EncryptedStorage.shared
        let otherUser = "other_user"

        storage.save("data", value: "mine", user: testUser)
        storage.save("data", value: "theirs", user: otherUser)

        storage.deleteAllData(for: testUser)

        XCTAssertTrue(storage.read("data", user: testUser).isEmpty)
        XCTAssertFalse(storage.read("data", user: otherUser).isEmpty)

        // Cleanup
        storage.deleteAllData(for: otherUser)
    }
}
