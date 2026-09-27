import XCTest
@testable import FreebuffGate

final class PushTokenStoreTests: XCTestCase {

    private func makeSession() -> PairingSession {
        PairingSession(
            gatewayBaseUrl: "https://relay.example.test",
            deviceId: "d_test",
            deviceToken: "device-token",
            accessToken: "access-token",
            accessTokenExpiresAt: "2027-01-01T00:00:00Z",
            deviceExpiresAt: "2027-01-01T00:00:00Z",
            relayUrl: "wss://relay.example.test",
            uiUrl: "https://relay.example.test"
        )
    }

    func testUploadsOnceBothTokenAndSessionArePresent() async {
        let uploaded = expectation(description: "token uploaded")
        var seen: (PairingSession, String)?
        let store = PushTokenStore(
            upload: { session, token in
                seen = (session, token)
                uploaded.fulfill()
            },
            erase: { _ in }
        )

        store.setDeviceToken("apns-token")
        store.setSession(makeSession())

        await fulfillment(of: [uploaded], timeout: 2)
        XCTAssertEqual(seen?.1, "apns-token")
        XCTAssertEqual(seen?.0.deviceId, "d_test")
    }

    func testDoesNotUploadWithOnlyOneHalf() async {
        let upload = expectation(description: "no upload")
        upload.isInverted = true
        let store = PushTokenStore(
            upload: { _, _ in upload.fulfill() },
            erase: { _ in }
        )

        store.setDeviceToken("apns-token")
        store.setSession(nil)

        await fulfillment(of: [upload], timeout: 0.3)
    }

    func testUnregisterDeletesRelayTokenExactlyOnce() async {
        let erased = expectation(description: "token deleted")
        erased.expectedFulfillmentCount = 1
        erased.assertForOverFulfill = true
        let store = PushTokenStore(
            upload: { _, _ in },
            erase: { _ in erased.fulfill() }
        )

        store.setDeviceToken("apns-token")
        store.setSession(makeSession())

        store.unregister()
        store.unregister()

        await fulfillment(of: [erased], timeout: 2)
    }

    func testUnregisterWithoutDeviceTokenSkipsRelayCall() async {
        let erased = expectation(description: "no relay call")
        erased.isInverted = true
        let store = PushTokenStore(
            upload: { _, _ in },
            erase: { _ in erased.fulfill() }
        )

        store.setSession(makeSession())
        store.unregister()

        await fulfillment(of: [erased], timeout: 0.3)
    }

    func testUploadDoesNotReoccurAfterUnregister() async {
        let uploaded = expectation(description: "single upload")
        uploaded.expectedFulfillmentCount = 1
        uploaded.assertForOverFulfill = true
        let store = PushTokenStore(
            upload: { _, _ in uploaded.fulfill() },
            erase: { _ in }
        )

        store.setDeviceToken("apns-token")
        store.setSession(makeSession())
        await fulfillment(of: [uploaded], timeout: 2)

        // Cleanup clears the held token/session; a later upload attempt must
        // not fulfill a second time (over-fulfil trips assertForOverFulfill).
        store.unregister()
        store.uploadIfPossible()

        try? await Task.sleep(nanoseconds: 200_000_000)
        await fulfillment(of: [uploaded], timeout: 0.3)
    }
}
