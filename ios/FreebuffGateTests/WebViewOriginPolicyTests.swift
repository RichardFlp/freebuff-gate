import XCTest
@testable import FreebuffGate

final class WebViewOriginPolicyTests: XCTestCase {

    private let allowed = "https://relay.example.test"

    private func allowedURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw) else { return false }
        return RestrictedWebViewController.isAllowed(url, allowedOrigin: allowed)
    }

    func testExactHttpsOriginIsAllowed() {
        XCTAssertTrue(allowedURL("https://relay.example.test"))
        XCTAssertTrue(allowedURL("https://relay.example.test/thread/123?x=1"))
    }

    func testOtherHostOrSchemeIsRejected() {
        XCTAssertFalse(allowedURL("https://evil.example.test/"))
        XCTAssertFalse(allowedURL("http://relay.example.test/"))
        XCTAssertFalse(allowedURL("https://sub.relay.example.test/"))
        XCTAssertFalse(allowedURL("https://relay.example.test.evil.test/"))
    }

    func testDifferentPortIsRejected() {
        XCTAssertFalse(allowedURL("https://relay.example.test:8443/"))
    }

    func testOriginOfLowercasesHostAndKeepsPort() {
        XCTAssertEqual(RestrictedWebViewController.originOf("https://Relay.Example.Test/thread"), "https://relay.example.test")
        XCTAssertEqual(RestrictedWebViewController.originOf("https://Relay.Example.Test:8443/thread"), "https://relay.example.test:8443")
    }
}
