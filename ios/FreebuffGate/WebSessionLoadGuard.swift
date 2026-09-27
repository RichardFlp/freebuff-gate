import Foundation

/// Identifies the relay web session a WebView load belongs to.
///
/// Keyed on the device identity and target URL only, not the short-lived
/// access token: the relay-issued web-session cookie outlives an access-token
/// rotation, so refreshing the token must not reload the page out from under
/// the user. A new pairing gets a new device id, and a revoked/cleared session
/// tears the WebView host down, so both still re-establish.
enum WebSessionKey {
    static func make(session: PairingSession, url: URL) -> String {
        "\(session.deviceId):\(url.absoluteString)"
    }
}

/// Decides whether the relay web session should be (re)established and the
/// WKWebView reloaded.
///
/// SwiftUI calls `updateUIViewController` on every state change, so without a
/// guard each render would mint a new relay web session and reload the page.
/// This mirrors the `loadedWebSessionKey` / `webSessionLoading` guard in the
/// Android `MainActivity`. It is intentionally free of WebKit so the rules are
/// unit-testable.
final class WebSessionLoadGuard {
    private var loadedKey: String?
    private var loading = false

    /// True when a load should start for `key`: never while another load is in
    /// flight, and never for a session that is already loaded.
    func shouldLoad(key: String) -> Bool {
        if loading { return false }
        if key == loadedKey { return false }
        return true
    }

    func begin() {
        loading = true
    }

    /// Records the load as complete. The next load for a different key (a
    /// newly paired device or a different target URL) is allowed.
    func finish(key: String) {
        loading = false
        loadedKey = key
    }

    /// Drops the loaded marker after a revoke/clear so a later session for the
    /// same key is established again.
    func invalidate() {
        loadedKey = nil
    }
}
