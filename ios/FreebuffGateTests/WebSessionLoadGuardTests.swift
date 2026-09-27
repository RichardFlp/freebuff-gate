import XCTest
@testable import FreebuffGate

final class WebSessionLoadGuardTests: XCTestCase {

    func testSuppressesConcurrentAndDuplicateLoads() {
        let loadGuard = WebSessionLoadGuard()

        XCTAssertTrue(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))

        // In flight: a second SwiftUI update must not start another load.
        loadGuard.begin()
        XCTAssertFalse(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))
        XCTAssertFalse(loadGuard.shouldLoad(key: "d_2:https://relay.example.test"))

        // Completed: the same session must not reload.
        loadGuard.finish(key: "d_1:https://relay.example.test")
        XCTAssertFalse(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))
    }

    func testChangedSessionStartsANewLoad() {
        let loadGuard = WebSessionLoadGuard()
        XCTAssertTrue(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))
        loadGuard.begin()
        loadGuard.finish(key: "d_1:https://relay.example.test")

        // A newly paired device or a different relay URL is a different key.
        XCTAssertTrue(loadGuard.shouldLoad(key: "d_2:https://relay.example.test"))
        XCTAssertTrue(loadGuard.shouldLoad(key: "d_1:https://other.example.test"))
    }

    func testInvalidateAllowsReloadAfterRevocation() {
        let loadGuard = WebSessionLoadGuard()
        loadGuard.begin()
        loadGuard.finish(key: "d_1:https://relay.example.test")
        XCTAssertFalse(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))

        loadGuard.invalidate()
        XCTAssertTrue(loadGuard.shouldLoad(key: "d_1:https://relay.example.test"))
    }

    func testSessionKeyIgnoresAccessTokenRotation() throws {
        let url = try XCTUnwrap(URL(string: "https://relay.example.test"))
        let first = makeSession(deviceId: "d_1", accessToken: "token-a")
        let rotated = makeSession(deviceId: "d_1", accessToken: "token-b")
        let otherDevice = makeSession(deviceId: "d_2", accessToken: "token-a")

        // Rotating the short-lived access token must reuse the loaded page.
        XCTAssertEqual(
            WebSessionKey.make(session: first, url: url),
            WebSessionKey.make(session: rotated, url: url)
        )
        // A different device (new pairing) or URL must not.
        XCTAssertNotEqual(
            WebSessionKey.make(session: first, url: url),
            WebSessionKey.make(session: otherDevice, url: url)
        )
        XCTAssertNotEqual(
            WebSessionKey.make(session: first, url: url),
            WebSessionKey.make(session: first, url: try XCTUnwrap(URL(string: "https://other.example.test")))
        )
    }

    private func makeSession(deviceId: String, accessToken: String) -> PairingSession {
        PairingSession(
            gatewayBaseUrl: "https://relay.example.test",
            deviceId: deviceId,
            deviceToken: "device-token",
            accessToken: accessToken,
            accessTokenExpiresAt: "2027-01-01T00:00:00Z",
            deviceExpiresAt: "2027-01-01T00:00:00Z",
            relayUrl: "wss://relay.example.test",
            uiUrl: "https://relay.example.test"
        )
    }
}
