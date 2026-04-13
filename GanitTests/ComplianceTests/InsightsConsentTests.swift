import XCTest
@testable import Ganit

final class InsightsConsentTests: XCTestCase {

    private let testUser = "test_consent_user"

    override func tearDown() {
        super.tearDown()
        EncryptedStorage.shared.deleteAllData(for: testUser)
    }

    @MainActor
    func testConsentDefaultsToFalse() {
        let manager = InsightsConsentManager(user: testUser)
        XCTAssertFalse(manager.hasConsented)
    }

    @MainActor
    func testGrantConsentPersists() {
        let manager = InsightsConsentManager(user: testUser)
        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)

        // Verify persistence across instances
        let manager2 = InsightsConsentManager(user: testUser)
        XCTAssertTrue(manager2.hasConsented)
    }

    @MainActor
    func testRevokeConsent() {
        let manager = InsightsConsentManager(user: testUser)
        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)

        manager.revokeConsent()
        XCTAssertFalse(manager.hasConsented)

        let manager2 = InsightsConsentManager(user: testUser)
        XCTAssertFalse(manager2.hasConsented)
    }

    @MainActor
    func testConsentIsolatedPerUser() {
        let manager1 = InsightsConsentManager(user: "user_a")
        let manager2 = InsightsConsentManager(user: "user_b")

        manager1.grantConsent()

        XCTAssertTrue(manager1.hasConsented)
        XCTAssertFalse(manager2.hasConsented)

        // Cleanup
        EncryptedStorage.shared.deleteAllData(for: "user_a")
        EncryptedStorage.shared.deleteAllData(for: "user_b")
    }
}
