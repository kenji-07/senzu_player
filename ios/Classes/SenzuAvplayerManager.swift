import Flutter
import AVFoundation
import AVKit
import MediaPlayer

/// Manages a single AVPlayer instance, wires it to the Flutter
/// MethodChannel and EventChannel, and drives the [SenzuSurfaceViewFactory].
/// Supports: PiP, Now Playing Info Center, Background playback, FairPlay DRM.
@objc public class SenzuAVPlayerManager: NSObject {

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObserver: NSKeyValueObservation?

    // DRM
    private var drmManager: SenzuDrmManager?

    private var eventSink: FlutterEventSink?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    private var errorObserver: NSKeyValueObservation?

    // Metadata
    private var _title: String = ""
    private var _artist: String = ""
    private var _artworkUrl: String? = nil
    private var _isLive: Bool = false

    // PiP state
    private var _pipEnabled: Bool = false
    private var _pipActive: Bool = false

    // Polling interval
    private let positionIntervalSeconds = 0.2

    static var sharedPlayerLayer: AVPlayerLayer?

    private let messenger: FlutterBinaryMessenger

    // ── Now Playing throttle ───────────────────────────────────────────────────
    private var _lastNowPlayingUpdate: TimeInterval = 0
    private let _nowPlayingThrottleMs: TimeInterval = 1.0 // 1 second
    private var _cachedArtwork: MPMediaItemArtwork? = nil
    private var _cachedArtworkUrl: String? = nil
    private var _artworkFetchInProgress = false

    @objc public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
        configureAudioSession()
    }

    // ── Audio session ──────────────────────────────────────────────────────────
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowBluetooth, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal
        }
    }

    @objc public func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }

    // ── MethodCall dispatcher ──────────────────────────────────────────────────
    @objc public func handle(_ call: FlutterMethodCall,
                             result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "initialize":              initialize(args: args, result: result);         return true
        case "play":                    play(result: result);                            return true
        case "pause":                   pause(result: result);                           return true
        case "seekTo":                  seekTo(args: args, result: result);              return true
        case "setPlaybackSpeed":        setPlaybackSpeed(args: args, result: result);    return true
        case "setLooping":              setLooping(args: args, result: result);          return true
        case "dispose":                 disposePlayer(result: result);                   return true
        // Now Playing / Metadata
        case "setNowPlayingMetadata":   setNowPlayingMetadata(args: args, result: result); return true
        case "setNowPlayingState":      setNowPlayingState(args: args, result: result);  return true
        // PiP
        case "enablePip":               enablePip(result: result);                       return true
        case "disablePip":              disablePip(result: result);                      return true
        case "isPipSupported":          result(AVPictureInPictureController.isPictureInPictureSupported()); return true
        case "enterPip":                enterPip(result: result);                        return true
        case "exitPip":                 exitPip(result: result);                         return true
        default:                        return false
        }
    }

    // ── initialize ─────────────────────────────────────────────────────────────
    private func initialize(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let urlString = args?["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "BAD_ARGS", message: "url required", details: nil))
            return
        }
        let headers  = args?["headers"]  as? [String: String] ?? [:]
        let title    = args?["title"]    as? String ?? ""
        let artist   = args?["artist"]   as? String ?? ""
        let artwork  = args?["artwork"]  as? String
        let isLive   = args?["isLive"]   as? Bool ?? false

        // DRM config (optional)
        let drmConfig = SenzuFairPlayConfig(from: args)

        _title = title; _artist = artist; _artworkUrl = artwork; _isLive = isLive

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.releasePlayer()

            var options: [String: Any] = [:]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            let asset = AVURLAsset(url: url, options: options)

            // FairPlay DRM
            if let cfg = drmConfig {
                let mgr = SenzuDrmManager()
                mgr.onError = { [weak self] msg in
                    self?.emitError("DRM error: \(msg)")
                }
                mgr.attach(to: asset, config: cfg)
                self.drmManager = mgr
            }

            let item  = AVPlayerItem(asset: asset)
            self.playerItem = item

            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.automaticallyWaitsToMinimizeStalling = true
            self.player = avPlayer

            let layer = AVPlayerLayer(player: avPlayer)
            layer.videoGravity = .resizeAspect
            self.playerLayer = layer
            SenzuAVPlayerManager.sharedPlayerLayer = layer
            NotificationCenter.default.post(
                name: NSNotification.Name("SenzuPlayerLayerDidChange"),
                object: nil
            )

            self.attachObservers(item: item, player: avPlayer)
            self.setupPipIfEnabled(layer: layer)

            // Wait for ready state
            var readyObserver: NSKeyValueObservation?
            readyObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self else { return }
                if item.status == .readyToPlay {
                    readyObserver?.invalidate()
                    let durationMs = self.cmTimeToMs(item.asset.duration)
                    self.updateNowPlayingInfo()
                    result(["durationMs": durationMs])
                } else if item.status == .failed {
                    readyObserver?.invalidate()
                    result(FlutterError(
                        code: "INIT_ERROR",
                        message: item.error?.localizedDescription ?? "AVPlayer error",
                        details: nil))
                }
            }
        }
    }

    // ── Playback controls ──────────────────────────────────────────────────────
    private func play(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.play()
            self?.updateNowPlayingInfo()
            result(nil)
        }
    }

    private func pause(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.pause()
            self?.updateNowPlayingInfo()
            result(nil)
        }
    }

    private func seekTo(args: [String: Any]?, result: @escaping FlutterResult) {
        let posMs = args?["positionMs"] as? Double ?? 0.0
        let time  = CMTime(value: CMTimeValue(posMs), timescale: 1000)
        DispatchQueue.main.async { [weak self] in
            self?.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.updateNowPlayingInfo()
                result(nil)
            }
        }
    }

    private func setPlaybackSpeed(args: [String: Any]?, result: @escaping FlutterResult) {
        let speed = Float(args?["speed"] as? Double ?? 1.0)
        DispatchQueue.main.async { [weak self] in
            self?.player?.rate = speed
            result(nil)
        }
    }

    private func setLooping(args: [String: Any]?, result: @escaping FlutterResult) {
        let looping = args?["looping"] as? Bool ?? false
        DispatchQueue.main.async { [weak self] in
            guard let self, let item = self.playerItem else { result(nil); return }
            if let obs = self.itemEndObserver {
                NotificationCenter.default.removeObserver(obs)
                self.itemEndObserver = nil
            }
            if looping {
                self.itemEndObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item, queue: .main) { [weak self] _ in
                        self?.player?.seek(to: .zero)
                        self?.player?.play()
                    }
            }
            result(nil)
        }
    }

    // ── Now Playing Info Center ────────────────────────────────────────────────

    private func setNowPlayingMetadata(args: [String: Any]?, result: @escaping FlutterResult) {
        _title     = args?["title"]   as? String ?? _title
        _artist    = args?["artist"]  as? String ?? _artist
        _artworkUrl = args?["artwork"] as? String ?? _artworkUrl
        _isLive    = args?["isLive"]  as? Bool   ?? _isLive
        updateNowPlayingInfo()
        result(nil)
    }

    private func setNowPlayingState(args: [String: Any]?, result: @escaping FlutterResult) {
        updateNowPlayingInfo()
        result(nil)
    }

    @objc public func updateNowPlayingInfoPublic() { updateNowPlayingInfo() }

    private func updateNowPlayingInfo() {
    // Throttle: 1 секундэд нэг удаа л update хийнэ
    let now = Date().timeIntervalSince1970
    guard now - _lastNowPlayingUpdate >= _nowPlayingThrottleMs else { return }
    _lastNowPlayingUpdate = now

    guard let player, let item = playerItem else { return }

    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

    info[MPMediaItemPropertyTitle]  = _title.isEmpty  ? "SenzuPlayer" : _title
    info[MPMediaItemPropertyArtist] = _artist.isEmpty ? "" : _artist

    let posMs  = cmTimeToMs(player.currentTime())
    let durMs  = cmTimeToMs(item.duration)
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(posMs) / 1000.0
    info[MPMediaItemPropertyPlaybackDuration]         = _isLive ? 0.0 : Double(durMs) / 1000.0
    info[MPNowPlayingInfoPropertyPlaybackRate]        = Double(player.rate)
    info[MPNowPlayingInfoPropertyIsLiveStream]        = _isLive

    // Cached artwork байвал шууд ашиглана — fetch хийхгүй
    if let cached = _cachedArtwork, _cachedArtworkUrl == _artworkUrl {
        info[MPMediaItemPropertyArtwork] = cached
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        return
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    _fetchArtworkIfNeeded()
}

private func _fetchArtworkIfNeeded() {
    guard let artStr = _artworkUrl,
          !artStr.isEmpty,
          artStr != _cachedArtworkUrl,
          !_artworkFetchInProgress else { return }

    _artworkFetchInProgress = true
    let targetUrl = artStr

    // URL cache ашиглана: URLSession default cache policy
    var request = URLRequest(url: URL(string: targetUrl)!)
    request.cachePolicy = .returnCacheDataElseLoad // disk cache
    request.timeoutInterval = 10

    URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
        guard let self, let data, let image = UIImage(data: data) else {
            self?._artworkFetchInProgress = false
            return
        }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        DispatchQueue.main.async {
            self._cachedArtwork = artwork
            self._cachedArtworkUrl = targetUrl
            self._artworkFetchInProgress = false
            // Update info center with new artwork
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            updated[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
    }.resume()
}

// Source солигдоход cache цэвэрлэнэ
private func invalidateArtworkCache() {
    _cachedArtwork = nil
    _cachedArtworkUrl = nil
    _artworkFetchInProgress = false
}

    // ── Remote Command Center ──────────────────────────────────────────────────

    @objc public func setupRemoteCommands(eventSink: @escaping FlutterEventSink) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "play"])
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "pause"])
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.player?.rate == 0 {
                self.player?.play()
                eventSink(["type": "remote", "action": "play"])
            } else {
                self.player?.pause()
                eventSink(["type": "remote", "action": "pause"])
            }
            self.updateNowPlayingInfo()
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let cur = self.player?.currentTime() ?? .zero
            let target = CMTimeAdd(cur, CMTime(seconds: e.interval, preferredTimescale: 600))
            self.player?.seek(to: target)
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "skipForward", "interval": e.interval])
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let cur = self.player?.currentTime() ?? .zero
            let target = CMTimeSubtract(cur, CMTime(seconds: e.interval, preferredTimescale: 600))
            self.player?.seek(to: target)
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "skipBackward", "interval": e.interval])
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let target = CMTime(seconds: e.positionTime, preferredTimescale: 600)
            self.player?.seek(to: target)
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "seek", "positionSec": e.positionTime])
            return .success
        }
    }

    @objc public func teardownRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // ── Picture-in-Picture ─────────────────────────────────────────────────────

    private func setupPipIfEnabled(layer: AVPlayerLayer) {
        guard _pipEnabled,
              AVPictureInPictureController.isPictureInPictureSupported() else { return }
        pipController = AVPictureInPictureController(playerLayer: layer)
        pipController?.delegate = self
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        pipPossibleObserver = pipController?.observe(\.isPictureInPicturePossible, options: [.new]) {
            [weak self] ctrl, _ in
            self?.emitPipState(possible: ctrl.isPictureInPicturePossible)
        }
    }

    private func enablePip(result: @escaping FlutterResult) {
        _pipEnabled = true
        if let layer = playerLayer {
            setupPipIfEnabled(layer: layer)
        }
        result(nil)
    }

    private func disablePip(result: @escaping FlutterResult) {
        _pipEnabled = false
        pipController?.stopPictureInPicture()
        pipController = nil
        pipPossibleObserver?.invalidate()
        pipPossibleObserver = nil
        result(nil)
    }

    private func enterPip(result: @escaping FlutterResult) {
        guard let pip = pipController else {
            result(FlutterError(code: "PIP_NA", message: "PiP not configured", details: nil))
            return
        }
        DispatchQueue.main.async {
            pip.startPictureInPicture()
            result(nil)
        }
    }

    private func exitPip(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.pipController?.stopPictureInPicture()
            result(nil)
        }
    }

    private func emitPipState(possible: Bool) {
        eventSink?(["type": "pip", "isPossible": possible, "isActive": _pipActive] as [String: Any])
    }

    // ── Low-latency / Live ─────────────────────────────────────────────────────
    @objc public func setLowLatencyMode(targetMs: Int) {
        let targetSec = Double(targetMs) / 1000.0
        DispatchQueue.main.async { [weak self] in
            self?.playerItem?.preferredForwardBufferDuration = targetSec
            self?.player?.automaticallyWaitsToMinimizeStalling = false
        }
    }

    @objc public func getLiveLatency() -> Double {
        guard let item = playerItem, item.isPlaybackLikelyToKeepUp else { return -1 }
        let seekableRange = item.seekableTimeRanges.last?.timeRangeValue
        guard let end = seekableRange else { return -1 }
        let liveEdge   = CMTimeGetSeconds(CMTimeRangeGetEnd(end))
        let currentPos = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let latency    = liveEdge - currentPos
        return latency > 0 ? latency * 1000 : -1
    }

    // ── Audio tracks ───────────────────────────────────────────────────────────
    @objc public func getAudioTracks() -> [[String: Any]] {
        guard let item = playerItem else { return [] }
        var result: [[String: Any]] = []
        guard let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return [] }
        for (i, option) in g.options.enumerated() {
            let locale = option.locale?.languageCode ?? "und"
            let label  = option.displayName(with: Locale.current)
            result.append([
                "id":       "\(i)",
                "language": locale,
                "label":    label,
                "selected": item.currentMediaSelection.selectedMediaOption(in: g) == option
            ])
        }
        return result
    }

    @objc public func setAudioTrack(trackId: String) {
        guard let item = playerItem, let idx = Int(trackId) else { return }
        guard let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              idx < g.options.count else { return }
        DispatchQueue.main.async { item.select(g.options[idx], in: g) }
    }

    // ── Observers ──────────────────────────────────────────────────────────────
    private func attachObservers(item: AVPlayerItem, player: AVPlayer) {
        let interval = CMTime(seconds: positionIntervalSeconds, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] _ in
            self?.emitPlaybackState()
            self?.updateNowPlayingInfo()
        }

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                self?.emitError(item.error?.localizedDescription ?? "AVPlayerItem error")
            }
        }

        bufferObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) {
            [weak self] item, _ in
            self?.emitPlaybackState(isBuffering: item.isPlaybackBufferEmpty)
        }

        rateObserver = player.observe(\.rate, options: [.new]) {
            [weak self] _, _ in self?.emitPlaybackState()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailed(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item)
    }

    @objc private func playerItemFailed(_ notification: Notification) {
        let err = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        emitError(err?.localizedDescription ?? "AVPlayer playback failed")
    }

    @objc private func playerItemDidEnd(_ notification: Notification) {
        updateNowPlayingInfo()
    }

    // ── Event emission ─────────────────────────────────────────────────────────
    private func emitPlaybackState(isBuffering: Bool? = nil) {
        guard let player, let item = playerItem, let sink = eventSink else { return }
        let posMs   = cmTimeToMs(player.currentTime())
        let durMs   = cmTimeToMs(item.duration)
        let playing = player.rate != 0 && player.error == nil
        let buf     = isBuffering ?? item.isPlaybackBufferEmpty

        var bufferedRanges: [[String: Double]] = []
        for value in item.loadedTimeRanges {
            let range = value.timeRangeValue
            bufferedRanges.append([
                "start": Double(cmTimeToMs(range.start)),
                "end":   Double(cmTimeToMs(CMTimeRangeGetEnd(range)))
            ])
        }

        sink([
            "type":        "playback",
            "position":    posMs,
            "duration":    max(durMs, 0),
            "isPlaying":   playing,
            "isBuffering": buf,
            "buffered":    bufferedRanges,
            "error":       NSNull()
        ] as [String: Any])
    }

    private func emitError(_ message: String) {
        eventSink?([
            "type":        "playback",
            "position":    0,
            "duration":    0,
            "isPlaying":   false,
            "isBuffering": false,
            "buffered":    [] as [[String: Any]],
            "error":       message
        ] as [String: Any])
    }

    private func cmTimeToMs(_ time: CMTime) -> Int64 {
        guard time.isValid, !time.isIndefinite else { return 0 }
        return Int64(CMTimeGetSeconds(time) * 1000)
    }

    // ── Dispose ────────────────────────────────────────────────────────────────
    @objc public func disposePlayer(result: FlutterResult? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.releasePlayer()
            result?(nil)
        }
    }

    private func releasePlayer() {
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
        }
        timeObserver   = nil
        statusObserver?.invalidate();  statusObserver = nil
        bufferObserver?.invalidate();  bufferObserver = nil
        rateObserver?.invalidate();    rateObserver   = nil
        errorObserver?.invalidate();   errorObserver  = nil
        pipPossibleObserver?.invalidate(); pipPossibleObserver = nil
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        pipController?.stopPictureInPicture()
        pipController = nil
        drmManager?.invalidate()
        drmManager = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player      = nil
        playerItem  = nil
        playerLayer = nil
        SenzuAVPlayerManager.sharedPlayerLayer = nil
    }
}

// ── AVPictureInPictureControllerDelegate ──────────────────────────────────────
extension SenzuAVPlayerManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        _pipActive = true
        eventSink?(["type": "pip", "isPossible": true, "isActive": true] as [String: Any])
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        _pipActive = false
        eventSink?(["type": "pip", "isPossible": controller.isPictureInPicturePossible, "isActive": false] as [String: Any])
    }

    public func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}