import Foundation

/// Parses the build-time configured relay origins.
///
/// The values come from `Info.plist` keys (`FBDefaultPairingOrigin` and
/// `FBDefaultWebOrigin`), which are filled from the `FB_DEFAULT_PAIRING_ORIGIN`
/// and `FB_DEFAULT_WEB_ORIGIN` build settings. Generic builds leave them
/// empty: pairing then trusts the exact HTTPS origin carried by the QR code,
/// and the WebView is pinned to the relay origin returned by the claim. A
/// production/CI build overrides the build settings so only a single known
/// relay origin is accepted.
///
/// A blank or missing value yields `nil`; an insecure, credentialed, or
/// malformed value is rejected rather than silently accepted.
enum OriginConfig {
    static func configuredOrigin(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? PairingApi.normalizeBaseUrl(trimmed)
    }
}
