import AVFoundation
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// SenzuFairPlayConfig  —  Dart-аас дамжуулах DRM тохиргоо
// ─────────────────────────────────────────────────────────────────────────────

struct SenzuFairPlayConfig {
    let licenseUrl: String
    let certificateUrl: String
    let headers: [String: String]

    init?(from args: [String: Any]?) {
        guard
            let drm = args?["drm"] as? [String: Any],
            let lic  = drm["licenseUrl"]     as? String,
            let cert = drm["certificateUrl"] as? String
        else { return nil }
        self.licenseUrl      = lic
        self.certificateUrl  = cert
        self.headers         = drm["headers"] as? [String: String] ?? [:]
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuDrmManager  —  AVContentKeySessionDelegate
// ─────────────────────────────────────────────────────────────────────────────

final class SenzuDrmManager: NSObject {

    private var contentKeySession: AVContentKeySession?
    private var config: SenzuFairPlayConfig?
    private var asset: AVURLAsset?

    // Caller-д алдаа мэдэгдэх callback
    var onError: ((String) -> Void)?

    // ── Setup ──────────────────────────────────────────────────────────────
    func attach(to asset: AVURLAsset, config: SenzuFairPlayConfig) {
        self.config = config
        self.asset  = asset

        let session = AVContentKeySession(keySystem: .fairPlayStreaming)
        contentKeySession = session
        session.setDelegate(self, queue: DispatchQueue(label: "dev.senzu.drm"))
        session.addContentKeyRecipient(asset)
    }

    func invalidate() {
        contentKeySession?.expire()
        contentKeySession = nil
        asset = nil
        config = nil
    }

    // ── Certificate fetch ──────────────────────────────────────────────────
    private func fetchCertificate() throws -> Data {
        guard let cfg = config, let url = URL(string: cfg.certificateUrl) else {
            throw NSError(domain: "SenzuDRM", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad certificate URL"])
        }
        var req = URLRequest(url: url)
        cfg.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        var data: Data?
        var fetchError: Error?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { d, _, e in
            data = d; fetchError = e; sem.signal()
        }.resume()
        sem.wait()
        if let e = fetchError { throw e }
        guard let d = data, !d.isEmpty else {
            throw NSError(domain: "SenzuDRM", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Empty certificate"])
        }
        return d
    }

    // ── License request ────────────────────────────────────────────────────
    private func fetchLicense(spcData: Data, assetId: String) throws -> Data {
        guard let cfg = config, let url = URL(string: cfg.licenseUrl) else {
            throw NSError(domain: "SenzuDRM", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Bad license URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = spcData
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        cfg.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        var ckc: Data?
        var fetchError: Error?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { d, _, e in
            ckc = d; fetchError = e; sem.signal()
        }.resume()
        sem.wait()
        if let e = fetchError { throw e }
        guard let c = ckc, !c.isEmpty else {
            throw NSError(domain: "SenzuDRM", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "Empty CKC"])
        }
        return c
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

    private func handleKeyRequest(_ keyRequest: AVContentKeyRequest) {
        do {
            let certData = try fetchCertificate()

            // Asset ID — HLS URI scheme-аас ална
            let assetId = keyRequest.identifier as? String ?? ""
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
                    let ckc = try self.fetchLicense(spcData: spc, assetId: assetId)
                    let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
                    keyRequest.process(contentKeyResponse: response)
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