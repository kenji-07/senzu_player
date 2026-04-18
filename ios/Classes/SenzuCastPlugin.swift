import Flutter
import UIKit
import GoogleCast

public class SenzuCastPlugin: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var pollingTimer: Timer?

    private var sessionManager: GCKSessionManager {
        GCKCastContext.sharedInstance().sessionManager
    }

    private var castSession: GCKCastSession? {
        sessionManager.currentCastSession
    }

    public static func register(
        with registrar: FlutterPluginRegistrar,
        method: FlutterMethodChannel,
        event: FlutterEventChannel
    ) {
        let instance = SenzuCastPlugin()
        method.setMethodCallHandler(instance.handle)
        event.setStreamHandler(instance)

        // GCKCastContext initialize болсны дараа л дуудагдана
        // (SenzuPlayerPlugin.register дотор DispatchQueue.main.async-д хийгдсэн)
        guard GCKCastContext.isSharedInstanceInitialized() else {
            print("SenzuCast: WARNING - GCKCastContext not initialized. Discovery will not work.")
            return
        }

        GCKCastContext.sharedInstance().sessionManager.add(instance)

        let dm = GCKCastContext.sharedInstance().discoveryManager
        dm.passiveScan = false
        dm.add(instance)
        dm.startDiscovery()

        print("SenzuCast: Plugin registered, discovery started")
    }

    // ── MethodChannel ──────────────────────────────────────────────────────
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        // GCKCastContext initialize эсэхийг шалгана
        guard GCKCastContext.isSharedInstanceInitialized() else {
            print("SenzuCast: GCKCastContext not initialized for method: \(call.method)")
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "GCKCastContext is not initialized",
                details: nil))
            return
        }

        switch call.method {

        case "discoverDevices":
            let dm = GCKCastContext.sharedInstance().discoveryManager

            // Discovery идэвхтэй эсэхийг шалгаж, шаардлагатай бол дахин эхлүүлнэ
            if !dm.discoveryActive {
                dm.passiveScan = false
                dm.startDiscovery()
                print("SenzuCast: Restarted discovery")
            }

            print("SenzuCast: discoveryActive=\(dm.discoveryActive), deviceCount=\(dm.deviceCount)")

            // Хэрэв device байхгүй бол 1 секунд хүлээж дахин шалгана
            if dm.deviceCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    var devices: [[String: Any]] = []
                    for i in 0..<dm.deviceCount {
                        let device = dm.device(at: i)
                        print("SenzuCast: found device = \(device.friendlyName ?? "?") id=\(device.deviceID)")
                        devices.append([
                            "deviceId":   device.deviceID,
                            "deviceName": device.friendlyName ?? "Unknown",
                            "modelName":  device.modelName ?? "",
                        ])
                    }
                    result(devices)
                }
            } else {
                var devices: [[String: Any]] = []
                for i in 0..<dm.deviceCount {
                    let device = dm.device(at: i)
                    print("SenzuCast: found device = \(device.friendlyName ?? "?") id=\(device.deviceID)")
                    devices.append([
                        "deviceId":   device.deviceID,
                        "deviceName": device.friendlyName ?? "Unknown",
                        "modelName":  device.modelName ?? "",
                    ])
                }
                result(devices)
            }

        case "connectToDevice":
            let deviceId = args?["deviceId"] as? String ?? ""
            let dm = GCKCastContext.sharedInstance().discoveryManager
            var found = false
            for i in 0..<dm.deviceCount {
                let device = dm.device(at: i)
                if device.deviceID == deviceId {
                    found = true
                    DispatchQueue.main.async {
                        GCKCastContext.sharedInstance().sessionManager
                            .startSession(with: device)
                    }
                    result(nil)
                    break
                }
            }
            if !found {
                result(FlutterError(
                    code: "DEVICE_NOT_FOUND",
                    message: "Device \(deviceId) not found",
                    details: nil
                ))
            }

        case "showDevicePicker":
            DispatchQueue.main.async {
                GCKCastContext.sharedInstance().presentCastDialog()
            }
            result(nil)

        case "loadMedia":
            loadMedia(args: args, result: result)

        case "play":
            castSession?.remoteMediaClient?.play()
            result(nil)

        case "pause":
            castSession?.remoteMediaClient?.pause()
            result(nil)

        case "stop":
            castSession?.remoteMediaClient?.stop()
            result(nil)

        case "seekTo":
            let posMs = args?["positionMs"] as? Int ?? 0
            let options = GCKMediaSeekOptions()
            options.interval = TimeInterval(posMs) / 1000.0
            castSession?.remoteMediaClient?.seek(with: options)
            result(nil)

        case "disconnect":
            sessionManager.endSessionAndStopCasting(true)
            result(nil)

        case "getCastState":
            let state = castSession != nil ? "connected" : "notConnected"
            result(state)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── Load Media ─────────────────────────────────────────────────────────
    private func loadMedia(args: [String: Any]?, result: @escaping FlutterResult) {
        guard
            let session = castSession,
            let urlStr  = args?["url"] as? String,
            let url     = URL(string: urlStr)
        else {
            result(false)
            return
        }

        let title        = args?["title"]           as? String ?? ""
        let description  = args?["description"]     as? String ?? ""
        let posterUrlStr = args?["posterUrl"]        as? String ?? ""
        let mimeType     = args?["mimeType"]         as? String ?? "video/mp4"
        let positionMs   = args?["positionMs"]       as? Int    ?? 0
        let subtitleUrl  = args?["subtitleUrl"]      as? String ?? ""
        let subtitleLang = args?["subtitleLanguage"] as? String ?? "en"

        // Metadata
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        metadata.setString(description, forKey: kGCKMetadataKeyStudio)

        if !posterUrlStr.isEmpty, let posterUrl = URL(string: posterUrlStr) {
            metadata.addImage(GCKImage(url: posterUrl, width: 480, height: 270))
        }

        // Subtitle tracks
        var tracks: [GCKMediaTrack] = []
        if !subtitleUrl.isEmpty {
            if let track = GCKMediaTrack(
                identifier:        1,
                contentIdentifier: subtitleUrl,
                contentType:       "text/vtt",
                type:              .text,
                textSubtype:       .subtitles,
                name:              "Subtitle",
                languageCode:      subtitleLang,
                customData:        nil
            ) {
                tracks.append(track)
            }
        }

        // MediaInformation
        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.contentType = mimeType
        builder.metadata    = metadata
        builder.streamType  = .buffered

        if !tracks.isEmpty {
            builder.mediaTracks = tracks
        }

        let mediaInfo = builder.build()

        // Load options
        let loadOptions = GCKMediaLoadOptions()
        loadOptions.playPosition = TimeInterval(positionMs) / 1000.0
        loadOptions.autoplay     = true

        if !tracks.isEmpty {
            loadOptions.activeTrackIDs = [1]
        }

        session.remoteMediaClient?.loadMedia(mediaInfo, with: loadOptions)
        result(true)
    }

    // ── EventChannel ───────────────────────────────────────────────────────
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events

        // GCKCastContext initialize болсны дараа л listener нэмнэ
        guard GCKCastContext.isSharedInstanceInitialized() else {
            return nil
        }

        // Session manager болон discovery listener-г eventSink тохирогдсоны дараа дахин нэмнэ
        // (register үед нэмэгдсэн байж болох тул давхардалт үүсгэхгүйн тулд шалгана)
        sessionManager.add(self)

        let dm = GCKCastContext.sharedInstance().discoveryManager
        if !dm.discoveryActive {
            dm.passiveScan = false
            dm.startDiscovery()
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        stopPolling()
        return nil
    }

    // ── State emission ─────────────────────────────────────────────────────
    private func emitCastState(_ state: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": "castState", "state": state])
        }
    }

    private func emitRemoteState() {
        guard
            let client = castSession?.remoteMediaClient,
            let status = client.mediaStatus
        else { return }

        let stateStr: String
        switch status.playerState {
        case .playing:   stateStr = "playing"
        case .paused:    stateStr = "paused"
        case .buffering: stateStr = "buffering"
        case .loading:   stateStr = "loading"
        default:         stateStr = "idle"
        }

        let durationSec = status.mediaInformation?.streamDuration ?? 0
        let positionSec = client.approximateStreamPosition()

        let info: [String: Any] = [
            "type":         "remoteState",
            "sessionState": stateStr,
            "positionMs":   Int(positionSec * 1000),
            "durationMs":   Int(durationSec * 1000),
            "isPlaying":    status.playerState == .playing,
            "volume":       castSession?.currentDeviceVolume ?? 1.0,
            "isMuted":      castSession?.currentDeviceMuted  ?? false,
        ]

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(info)
        }
    }

    // ── Polling ────────────────────────────────────────────────────────────
    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.2,
            repeats: true
        ) { [weak self] _ in
            self?.emitRemoteState()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

// ── GCKDiscoveryManagerListener ────────────────────────────────────────────────
extension SenzuCastPlugin: GCKDiscoveryManagerListener {

    public func didInsert(
        _ device: GCKDevice,
        at index: UInt
    ) {
        print("SenzuCast: device inserted = \(device.friendlyName ?? "?"), id=\(device.deviceID)")
        emitDeviceList()
    }

    public func didUpdate(
        _ device: GCKDevice,
        at index: UInt
    ) {
        emitDeviceList()
    }

    public func didRemove(
        _ device: GCKDevice,
        at index: UInt
    ) {
        print("SenzuCast: device removed = \(device.friendlyName ?? "?")")
        emitDeviceList()
    }

    private func emitDeviceList() {
        guard GCKCastContext.isSharedInstanceInitialized() else { return }
        let dm = GCKCastContext.sharedInstance().discoveryManager
        var devices: [[String: Any]] = []
        for i in 0..<dm.deviceCount {
            let d = dm.device(at: i)
            devices.append([
                "deviceId":   d.deviceID,
                "deviceName": d.friendlyName ?? "Unknown",
                "modelName":  d.modelName ?? "",
            ])
        }
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type":    "devices",
                "devices": devices
            ] as [String: Any])
        }
    }
}

// ── GCKSessionManagerListener ──────────────────────────────────────────────────
extension SenzuCastPlugin: GCKSessionManagerListener {

    public func sessionManager(
        _ sessionManager: GCKSessionManager,
        didStart session: GCKCastSession
    ) {
        print("SenzuCast: session started")
        emitCastState("connected")
        startPolling()
    }

    public func sessionManager(
        _ sessionManager: GCKSessionManager,
        didEnd session: GCKCastSession,
        withError error: Error?
    ) {
        print("SenzuCast: session ended, error=\(error?.localizedDescription ?? "none")")
        emitCastState("notConnected")
        stopPolling()
    }

    public func sessionManager(
        _ sessionManager: GCKSessionManager,
        didResumeCastSession session: GCKCastSession
    ) {
        print("SenzuCast: session resumed")
        emitCastState("connected")
        startPolling()
    }

    public func sessionManager(
        _ sessionManager: GCKSessionManager,
        didFailToStart session: GCKCastSession,
        withError error: Error
    ) {
        print("SenzuCast: session failed to start, error=\(error.localizedDescription)")
        emitCastState("notConnected")
    }

    public func sessionManager(
        _ sessionManager: GCKSessionManager,
        willStart session: GCKCastSession
    ) {
        print("SenzuCast: session will start")
        emitCastState("connecting")
    }
}