import XCTest
@testable import FreebuffGate

final class OriginConfigTests: XCTestCase {

    func testBlankOrMissingConfigurationYieldsNil() {
        XCTAssertNil(OriginConfig.configuredOrigin(nil))
        XCTAssertNil(OriginConfig.configuredOrigin(""))
        XCTAssertNil(OriginConfig.configuredOrigin("   "))
    }

    func testValidHttpsOriginIsNormalized() {
        XCTAssertEqual(
            OriginConfig.configuredOrigin("https://Relay.Example.Test:8443/path"),
            "https://relay.example.test:8443"
        )
    }

    func testProductionOriginOnlyMatchesItself() {
        let configured = OriginConfig.configuredOrigin("https://relay.example.test")
        XCTAssertEqual(configured, "https://relay.example.test")
        XCTAssertNotEqual(configured, RestrictedWebViewController.originOf("https://relay.example.test:8443/"))
        XCTAssertNotEqual(configured, RestrictedWebViewController.originOf("https://evil.example.test/"))
    }

    func testInsecureCredentialedOrMalformedOriginsAreRejected() {
        XCTAssertNil(OriginConfig.configuredOrigin("http://relay.example.test"))
        XCTAssertNil(OriginConfig.configuredOrigin("https://user:pass@relay.example.test"))
        XCTAssertNil(OriginConfig.configuredOrigin("not a url"))
    }
}
