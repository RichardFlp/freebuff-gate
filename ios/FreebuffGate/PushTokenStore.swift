import Foundation

/// Holds the APNs device token and the active pairing session. Uploads the
/// token to the relay whenever both are available so the relay can push
/// turn-finished notifications, and deletes the relay-side token when the user
/// disconnects or the pairing is revoked.
final class PushTokenStore {
    static let shared = PushTokenStore()

    typealias UploadHandler = (PairingSession, String) async -> Void
    typealias EraseHandler = (PairingSession) async -> Void

    private let queue = DispatchQueue(label: "com.freebuff.gate.push-token")
    private let upload: UploadHandler
    private let erase: EraseHandler

    private var deviceToken: String?
    private var session: PairingSession?
    /// Kept after `session` is cleared so cleanup can still authenticate a
    /// `DELETE /v1/mobile/push-token` for the device that just disconnected.
    private var lastSession: PairingSession?

    init(
        upload: @escaping UploadHandler = PushTokenStore.uploadToRelay,
        erase: @escaping EraseHandler = PushTokenStore.eraseFromRelay
    ) {
        self.upload = upload
        self.erase = erase
    }

    func setDeviceToken(_ token: String) {
        queue.sync { self.deviceToken = token.isEmpty ? nil : token }
        uploadIfPossible()
    }

    func setSession(_ session: PairingSession?) {
        queue.sync {
            self.session = session
            if let session {
                self.lastSession = session
            }
        }
        uploadIfPossible()
    }

    func uploadIfPossible() {
        let pair = queue.sync { () -> (token: String, session: PairingSession)? in
            guard let token = self.deviceToken, let session = self.session else { return nil }
            return (token, session)
        }
        guard let pair else { return }
        Task { await self.upload(pair.session, pair.token) }
    }

    /// Best-effort relay cleanup. Only the first call while a device token is
    /// held issues a request, so repeated state transitions do not spam
    /// `DELETE /v1/mobile/push-token`. Failures are swallowed: an
    /// expired/revoked access token returns 401 and there is nothing left to
    /// clean up. Local state is cleared regardless, so this never blocks or
    /// crashes the disconnect path.
    func unregister() {
        let pending = queue.sync { () -> (token: String?, session: PairingSession?) in
            let token = self.deviceToken
            self.deviceToken = nil
            self.session = nil
            return (token, self.lastSession)
        }
        guard pending.token != nil, let session = pending.session else { return }
        Task { await self.erase(session) }
    }

    private static func uploadToRelay(session: PairingSession, token: String) async {
        guard let api = try? PairingApi(rawBaseUrl: session.gatewayBaseUrl) else { return }
        try? await api.uploadPushToken(session: session, token: token)
    }

    private static func eraseFromRelay(session: PairingSession) async {
        guard let api = try? PairingApi(rawBaseUrl: session.gatewayBaseUrl) else { return }
        try? await api.deletePushToken(session: session)
    }
}
