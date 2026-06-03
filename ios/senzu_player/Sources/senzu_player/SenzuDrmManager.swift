import AVFoundation
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// SenzuFairPlayConfig — FairPlay DRM configuration passed from Dart
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Holds Apple FairPlay Streaming (FPS) DRM configuration.
 *
 * @property licenseUrl      URL of the FPS Key Security Module (KSM) / license server.
 * @property certificateUrl  URL from which the FPS Application Certificate is fetched.
 * @property headers         Optional HTTP headers for both certificate and license requests.
 */
struct SenzuFairPlayConfig {
    let licenseUrl:     String
    let certificateUrl: String
    let headers:        [String: String]

    /**
     * Parses a [SenzuFairPlayConfig] from a raw method-channel argument map.
     * Returns nil if the required `drm.licenseUrl` or `drm.certificateUrl` keys
     * are missing.
     */
    init?(from args: [String: Any]?) {
        guard
            let drm  = args?["drm"] as? [String: Any],
            let lic  = drm["licenseUrl"]     as? String,
            let cert = drm["certificateUrl"] as? String
        else { return nil }

        self.licenseUrl      = lic
        self.certificateUrl  = cert
        self.headers         = drm["headers"] as? [String: String] ?? [:]
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuDrmManager — AVContentKeySessionDelegate for FairPlay
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Handles FairPlay Streaming key requests on behalf of an [AVURLAsset].
 *
 * Lifecycle:
 * 1. Call [attach(to:config:)] after creating the asset.
 * 2. The manager registers itself as the [AVContentKeySession] delegate.
 * 3. On key requests the manager fetches the FPS certificate then the CKC.
 * 4. Call [invalidate()] when the player is released to free all resources.
 *
 * Error reporting is done through the [onError] callback so the caller can
 * propagate errors to Flutter without coupling this class to Flutter APIs.
 */
final class SenzuDrmManager: NSObject {

    // ── Internal state ─────────────────────────────────────────────────────

    private var contentKeySession: AVContentKeySession?
    private var config: SenzuFairPlayConfig?
    private var asset: AVURLAsset?

    /// Called on the DRM serial queue when a non-recoverable error occurs.
    var onError: ((String) -> Void)?

    // ── Setup ──────────────────────────────────────────────────────────────

    /**
     * Attaches this manager to [asset] using [config].
     * Creates the [AVContentKeySession] and adds the asset as a recipient.
     */
    func attach(to asset: AVURLAsset, config: SenzuFairPlayConfig) {
        self.config = config
        self.asset  = asset

        let session = AVContentKeySession(keySystem: .fairPlayStreaming)
        contentKeySession = session
        session.setDelegate(self, queue: DispatchQueue(label: "dev.senzu.drm"))
        session.addContentKeyRecipient(asset)
    }

    /**
     * Expires the content key session and releases all references.
     * Must be called before the player is released.
     */
    func invalidate() {
        contentKeySession?.expire()
        contentKeySession = nil
        asset  = nil
        config = nil
    }

    // ── Certificate fetch ──────────────────────────────────────────────────

    /**
     * Synchronously fetches the FPS Application Certificate from [config.certificateUrl].
     * Throws if the URL is invalid, the request fails, or the response is empty.
     */
    private func fetchCertificate() throws -> Data {
        guard let cfg = config, let url = URL(string: cfg.certificateUrl) else {
            throw drmError(code: -1, message: "Bad certificate URL")
        }
        var req = URLRequest(url: url)
        cfg.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return try synchronousFetch(req, emptyErrorCode: -2, emptyMessage: "Empty certificate")
    }

    // ── License (CKC) request ──────────────────────────────────────────────

    /**
     * Synchronously posts the SPC (Server Playback Context) to [config.licenseUrl]
     * and returns the CKC (Content Key Context).
     */
    private func fetchLicense(spcData: Data, assetId: String) throws -> Data {
        guard let cfg = config, let url = URL(string: cfg.licenseUrl) else {
            throw drmError(code: -3, message: "Bad license URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = spcData
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        cfg.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return try synchronousFetch(req, emptyErrorCode: -4, emptyMessage: "Empty CKC")
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    /// Performs a synchronous URLSession data task using a semaphore.
    private func synchronousFetch(_ req: URLRequest, emptyErrorCode: Int, emptyMessage: String) throws -> Data {
        var data: Data?
        var fetchError: Error?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { d, _, e in
            data = d; fetchError = e; sem.signal()
        }.resume()
        sem.wait()
        if let e = fetchError { throw e }
        guard let d = data, !d.isEmpty else { throw drmError(code: emptyErrorCode, message: emptyMessage) }
        return d
    }

    private func drmError(code: Int, message: String) -> NSError {
        NSError(domain: "SenzuDRM", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVContentKeySessionDelegate
// ─────────────────────────────────────────────────────────────────────────────

extension SenzuDrmManager: AVContentKeySessionDelegate {

    func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        handleKeyRequest(keyRequest)
    }

    func contentKeySession(
        _ session: AVContentKeySession,
        didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest
    ) {
        handleKeyRequest(keyRequest)
    }

    /**
     * Handles a FairPlay key request end-to-end:
     * 1. Fetch the Application Certificate.
     * 2. Generate the SPC via [makeStreamingContentKeyRequestData].
     * 3. Exchange SPC for CKC at the license server.
     * 4. Provide the CKC as an [AVContentKeyResponse].
     */
    private func handleKeyRequest(_ keyRequest: AVContentKeyRequest) {
        do {
            let certData   = try fetchCertificate()
            let assetId    = keyRequest.identifier as? String ?? ""
            let assetIdData = assetId.data(using: .utf8) ?? Data()

            keyRequest.makeStreamingContentKeyRequestData(
                forApp: certData,
                contentIdentifier: assetIdData,
                options: [AVContentKeyRequestProtocolVersionsKey: [1]]
            ) { [weak self] spcData, error in
                guard let self else { return }

                if let e = error {
                    keyRequest.processContentKeyResponseError(e)
                    self.onError?(e.localizedDescription)
                    return
                }

                guard let spc = spcData else { return }

                do {
                    let ckc      = try self.fetchLicense(spcData: spc, assetId: assetId)
                    let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
                    keyRequest.processContentKeyResponse(response)
                } catch {
                    keyRequest.processContentKeyResponseError(error)
                    self.onError?(error.localizedDescription)
                }
            }
        } catch {
            keyRequest.processContentKeyResponseError(error)
            onError?(error.localizedDescription)
        }
    }
}