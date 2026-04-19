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

        guard GCKCastContext.isSharedInstanceInitialized() else {
            print("SenzuCast: GCKCastContext not initialized for method: \(call.method)")
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "GCKCastContext is not initialized",
                details: nil))
            return
        }

        switch call.method {

        // ── Device discovery ───────────────────────────────────────────────
        case "discoverDevices":
            let dm = GCKCastContext.sharedInstance().discoveryManager
            if !dm.discoveryActive {
                dm.passiveScan = false
                dm.startDiscovery()
            }
            if dm.deviceCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    result(self.buildDeviceList(dm))
                }
            } else {
                result(buildDeviceList(dm))
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
                        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
                    }
                    result(nil)
                    break
                }
            }
            if !found {
                result(FlutterError(
                    code: "DEVICE_NOT_FOUND",
                    message: "Device \(deviceId) not found",
                    details: nil))
            }

        case "showDevicePicker":
            DispatchQueue.main.async {
                GCKCastContext.sharedInstance().presentCastDialog()
            }
            result(nil)

        // ── Media ──────────────────────────────────────────────────────────
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

        // ── Quality / URL reload ───────────────────────────────────────────
        case "loadQuality":
            loadQuality(args: args, result: result)

        // ── Track selection ────────────────────────────────────────────────
        // setSubtitleTrack — хуучин API, доор setActiveTracks ашиглана
        case "setSubtitleTrack":
            let trackId = args?["trackId"] as? Int ?? 0
            castSession?.remoteMediaClient?.setActiveTrackIDs([NSNumber(value: trackId)])
            result(nil)

        case "disableSubtitles":
            // Audio track идэвхтэй байвал хадгалах хэрэгтэй бол
            // setActiveTracks ашиглана. Энд бүгдийг унтраана.
            castSession?.remoteMediaClient?.setActiveTrackIDs([])
            result(nil)

        case "setAudioTrack":
            let trackId = args?["trackId"] as? Int ?? 0
            castSession?.remoteMediaClient?.setActiveTrackIDs([NSNumber(value: trackId)])
            result(nil)

        // ── setActiveTracks — subtitle + audio хоёуланг нэг дор ───────────
        // Flutter-с [subtitleId, audioId] хэлбэрийн массив ирнэ.
        // Хоосон массив бол бүх track-г унтраана.
        case "setActiveTracks":
            let rawIds = args?["trackIds"] as? [Int] ?? []
            let nsIds = rawIds.map { NSNumber(value: $0) }
            castSession?.remoteMediaClient?.setActiveTrackIDs(nsIds)
            result(nil)

        // ── Volume ─────────────────────────────────────────────────────────
        case "setVolume":
            let volume = args?["volume"] as? Double ?? 1.0
            castSession?.setDeviceVolume(Float(volume))
            result(nil)

        // ── Session ────────────────────────────────────────────────────────
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

    // ── Helper: build device list ──────────────────────────────────────────
    private func buildDeviceList(_ dm: GCKDiscoveryManager) -> [[String: Any]] {
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
        return devices
    }

    // ── loadQuality ────────────────────────────────────────────────────────
    private func loadQuality(args: [String: Any]?, result: @escaping FlutterResult) {
        guard
            let session = castSession,
            let client = session.remoteMediaClient,
            let urlStr = args?["url"] as? String,
            let url = URL(string: urlStr)
        else { result(false); return }

        let positionMs = args?["positionMs"] as? Int ?? 0
        let durationMs = args?["durationMs"] as? Int ?? 0
        let isLive = args?["isLive"] as? Bool ?? false
        let headers = args?["headers"] as? [String: String] ?? [:]

        let currentInfo = client.mediaStatus?.mediaInformation
        let currentActiveIds = client.mediaStatus?.activeTrackIDs

        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.contentType = currentInfo?.contentType ?? "application/x-mpegURL"
        builder.metadata = currentInfo?.metadata
        builder.mediaTracks = currentInfo?.mediaTracks
        builder.streamType = isLive ? .live : .buffered

        if !isLive && durationMs > 0 {
            builder.streamDuration = TimeInterval(durationMs) / 1000.0
        } else if !isLive, let currentDur = currentInfo?.streamDuration, currentDur > 0 {
            builder.streamDuration = currentDur
        }

        if !headers.isEmpty {
            builder.customData = ["headers": headers]
        }

        let loadOptions = GCKMediaLoadOptions()
        loadOptions.playPosition = TimeInterval(positionMs) / 1000.0
        loadOptions.autoplay = true
        loadOptions.activeTrackIDs = currentActiveIds

        client.loadMedia(builder.build(), with: loadOptions)
        result(true)
    }

        // ── loadMedia ──────────────────────────────────────────────────────────
    private func loadMedia(args: [String: Any]?, result: @escaping FlutterResult) {
    guard
        let session = castSession,
        let remoteMediaClient = session.remoteMediaClient,
        let urlStr = args?["url"] as? String,
        let url = URL(string: urlStr)
    else {
        result(false)
        return
    }

    let title        = args?["title"]        as? String ?? ""
    let description  = args?["description"]  as? String ?? ""
    let posterUrlStr = args?["posterUrl"]     as? String ?? ""
    let mimeType     = args?["mimeType"]      as? String ?? "application/x-mpegURL"
    let positionMs   = args?["positionMs"]    as? Int    ?? 0
    let durationMs   = args?["durationMs"]    as? Int    ?? 0
    let isLive       = args?["isLive"]        as? Bool   ?? false
    let releaseDate  = args?["releaseDate"]   as? String ?? ""
    let studio       = args?["studio"]        as? String ?? ""
    let httpHeaders     = args?["httpHeaders"]     as? [String: String] ?? [:]
    let subtitleHeaders = args?["subtitleHeaders"] as? [String: String] ?? [:]
    let selectedSubtitleId = args?["selectedSubtitleId"] as? Int
    let selectedAudioId    = args?["selectedAudioId"]    as? Int

    // ── Metadata ───────────────────────────────────────────────────────────
    let metadata = GCKMediaMetadata(metadataType: .movie)
    metadata.setString(title, forKey: kGCKMetadataKeyTitle)
    if !description.isEmpty {
        metadata.setString(description, forKey: kGCKMetadataKeySubtitle)
    }
    if !studio.isEmpty {
        metadata.setString(studio, forKey: kGCKMetadataKeyStudio)
    }
    if !posterUrlStr.isEmpty, let posterUrl = URL(string: posterUrlStr) {
        metadata.addImage(GCKImage(url: posterUrl, width: 480, height: 270))
    }
    if !releaseDate.isEmpty {
        let isoFormatter = ISO8601DateFormatter()
        if let _ = isoFormatter.date(from: releaseDate) {
            metadata.setString(releaseDate, forKey: kGCKMetadataKeyReleaseDate)
        }
    }

    // ── Subtitle tracks ────────────────────────────────────────────────────
    var tracks: [GCKMediaTrack] = []
    var activeTrackIDs: [NSNumber] = []

    let subtitleList = args?["availableSubtitles"] as? [[String: Any]] ?? []
    for sub in subtitleList {
        let trackId  = sub["id"]       as? Int    ?? 0
        let subUrl   = sub["url"]      as? String ?? ""
        let subLang  = sub["language"] as? String ?? "en"
        let subName  = sub["name"]     as? String ?? "Subtitle"
        let perSubHeaders = sub["headers"] as? [String: String] ?? subtitleHeaders
        guard !subUrl.isEmpty else { continue }
        var trackCustomData: [String: Any]? = nil
        if !perSubHeaders.isEmpty {
            trackCustomData = ["headers": perSubHeaders]
        }
        if let track = GCKMediaTrack(
            identifier: trackId,
            contentIdentifier: subUrl,
            contentType: "text/vtt",
            type: .text,
            textSubtype: .subtitles,
            name: subName,
            languageCode: subLang,
            customData: trackCustomData
        ) {
            tracks.append(track)
            if let selectedSubtitleId, selectedSubtitleId == trackId {
                activeTrackIDs.append(NSNumber(value: trackId))
            }
        }
    }

    // ── Audio tracks ───────────────────────────────────────────────────────
    let audioList = args?["availableAudioTracks"] as? [[String: Any]] ?? []
    for audio in audioList {
        let trackId = audio["id"]       as? Int    ?? 0
        let lang    = audio["language"] as? String ?? "und"
        let name    = audio["name"]     as? String ?? "Audio"
        if let track = GCKMediaTrack(
            identifier: trackId,
            contentIdentifier: nil,
            contentType: "audio/mp4",
            type: .audio,
            textSubtype: .unknown,
            name: name,
            languageCode: lang,
            customData: nil
        ) {
            tracks.append(track)
            if let selectedAudioId, selectedAudioId == trackId {
                activeTrackIDs.append(NSNumber(value: trackId))
            }
        }
    }

    // ── customData — header-г receiver-т дамжуулна ────────────────────────
    var customData: [String: Any] = [:]
    if !httpHeaders.isEmpty {
        customData["headers"] = httpHeaders
    }
    if !releaseDate.isEmpty { customData["releaseDate"] = releaseDate }
    if !studio.isEmpty      { customData["studio"]      = studio      }

    // ── MediaInformation ───────────────────────────────────────────────────
    let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: url)
    mediaInfoBuilder.contentType    = mimeType
    mediaInfoBuilder.metadata       = metadata
    mediaInfoBuilder.streamType     = isLive ? .live : .buffered

    if !isLive && durationMs > 0 {
        mediaInfoBuilder.streamDuration = TimeInterval(durationMs) / 1000.0
    }
    if !tracks.isEmpty {
        mediaInfoBuilder.mediaTracks = tracks
    }
    if !customData.isEmpty {
        mediaInfoBuilder.customData = customData
    }

    let mediaInfo = mediaInfoBuilder.build()

    // ── Load request ───────────────────────────────────────────────────────
    let requestDataBuilder = GCKMediaLoadRequestDataBuilder()
    requestDataBuilder.mediaInformation = mediaInfo
    requestDataBuilder.autoplay         = true
    requestDataBuilder.startTime        = TimeInterval(positionMs) / 1000.0

    // credentials-аар дамжуулна
    if !httpHeaders.isEmpty {
        if let authHeader = httpHeaders["Authorization"] {
            requestDataBuilder.credentials = authHeader
        }
        // Бүх header-г JSON болгон credentials-т хийнэ
        if let jsonData = try? JSONSerialization.data(withJSONObject: httpHeaders),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            requestDataBuilder.credentials = jsonStr
            requestDataBuilder.credentialsType = "headers"
        }
    }
    // ──────────────────────────────────────────────────────────────────────

    if !activeTrackIDs.isEmpty {
        requestDataBuilder.activeTrackIDs = activeTrackIDs
    }

    let requestData = requestDataBuilder.build()
    remoteMediaClient.loadMedia(with: requestData)
    result(true)
}

    // ── EventChannel ───────────────────────────────────────────────────────
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events

        guard GCKCastContext.isSharedInstanceInitialized() else {
            return nil
        }

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
        let activeIds = status.activeTrackIDs?.map { $0.intValue } ?? []

        let info: [String: Any] = [
            "type": "remoteState",
            "sessionState": stateStr,
            "positionMs": Int(positionSec * 1000),
            "durationMs": Int(durationSec * 1000),
            "isPlaying": status.playerState == .playing,
            "volume": castSession?.currentDeviceVolume ?? 1.0,
            "isMuted": castSession?.currentDeviceMuted ?? false,
            "activeTrackIds": activeIds,
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

    public func didInsert(_ device: GCKDevice, at index: UInt) {
        print("SenzuCast: device inserted = \(device.friendlyName ?? "?"), id=\(device.deviceID)")
        emitDeviceList()
    }

    public func didUpdate(_ device: GCKDevice, at index: UInt) {
        emitDeviceList()
    }

    public func didRemove(_ device: GCKDevice, at index: UInt) {
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