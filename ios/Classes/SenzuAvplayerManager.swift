import Flutter
import AVFoundation
import AVKit
import MediaPlayer

// ─────────────────────────────────────────────────────────────────────────────
// SenzuAVPlayerManager
// Manages a single AVPlayer instance on iOS.  Wires it to the Flutter
// MethodChannel / EventChannel, drives Now Playing / Lock Screen controls,
// and supports Picture-in-Picture, FairPlay DRM, HDR, and audio tracks.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Central AVPlayer manager for the SenzuPlayer Flutter plugin on iOS.
 *
 * Key design decisions:
 * - All UIKit/AVKit mutations run on the main thread via `DispatchQueue.main.async`.
 * - KVO observers use `NSKeyValueObservation` tokens stored as properties so they
 *   are automatically invalidated on dealloc.
 * - The `NotificationCenter` memory-pressure observer uses a token to prevent leaks.
 * - Now Playing info updates are throttled to 1 Hz to avoid lock-screen jank.
 * - Album artwork is fetched off the main thread, cached by URL, and posted back.
 * - `isPlaybackLikelyToKeepUp` KVO is observed alongside `isPlaybackBufferEmpty`
 *   for more accurate buffering state reporting to Flutter.
 *
 * @param messenger  Flutter binary messenger used to create sub-channels if needed.
 */
@objc public class SenzuAVPlayerManager: NSObject {

    // ── Player objects ─────────────────────────────────────────────────────

    private var player:        AVPlayer?
    private var playerItem:    AVPlayerItem?
    private var playerLayer:   AVPlayerLayer?
    private var pipController: AVPictureInPictureController?

    // ── DRM ────────────────────────────────────────────────────────────────

    private var drmManager: SenzuDrmManager?

    // ── Flutter event sink ─────────────────────────────────────────────────

    private var eventSink: FlutterEventSink?

    // ── KVO / notification observers ──────────────────────────────────────

    private var timeObserver:           Any?
    private var statusObserver:         NSKeyValueObservation?
    private var bufferObserver:         NSKeyValueObservation?
    /// Complements bufferObserver for accurate buffering state
    private var likelyToKeepUpObserver: NSKeyValueObservation?
    private var rateObserver:           NSKeyValueObservation?
    private var itemEndObserver:        NSObjectProtocol?
    private var errorObserver:          NSKeyValueObservation?
    private var pipPossibleObserver:    NSKeyValueObservation?
    private var memoryPressureObserver: NSObjectProtocol?

    // ── Metadata ───────────────────────────────────────────────────────────

    private var _title:     String  = ""
    private var _artist:    String  = ""
    private var _artworkUrl: String? = nil
    private var _isLive:    Bool    = false

    // ── PiP state ──────────────────────────────────────────────────────────

    private var _pipEnabled: Bool = false
    private var _pipActive:  Bool = false

    // ── Now Playing throttle ───────────────────────────────────────────────

    private var _lastNowPlayingUpdate: TimeInterval = 0
    /// Minimum seconds between Now Playing info updates (prevents lock-screen jank)
    private let _nowPlayingThrottleMs: TimeInterval = 1.0
    private var _cachedArtwork:         MPMediaItemArtwork? = nil
    private var _cachedArtworkUrl:      String?             = nil
    private var _artworkFetchInProgress = false

    // ── Misc ───────────────────────────────────────────────────────────────

    /// Shared reference consumed by SenzuSurfaceViewFactory / _SenzuLayerHostView
    static var sharedPlayerLayer: AVPlayerLayer?

    private let messenger: FlutterBinaryMessenger

    /// Position polling interval — 200ms gives smooth seek feedback without
    /// excessive CPU usage.
    private let positionIntervalSeconds = 0.2

    // ── Initialiser ────────────────────────────────────────────────────────

    @objc public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
        configureAudioSession()
        setupMemoryPressureObserver()
    }

    // ── Audio session ──────────────────────────────────────────────────────

    /**
     * Configures the AVAudioSession for background playback with AirPlay,
     * Bluetooth A2DP, and standard Bluetooth output options.
     */
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal: audio session failure must not crash the player
        }
    }

    /**
     * Registers a memory-pressure observer that shrinks the forward buffer
     * to 5 seconds when the system sends a low-memory warning, preventing
     * OOM kills on constrained devices.
     */
    private func setupMemoryPressureObserver() {
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let item = self.playerItem else { return }
            item.preferredForwardBufferDuration = 5.0
        }
    }

    // ── EventSink ──────────────────────────────────────────────────────────

    @objc public func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }

    // ── MethodCall dispatcher ─────────────────────────────────────────────

    /**
     * Attempts to handle a Flutter method call.
     * Returns `true` if the call was handled, `false` if unknown.
     */
    @objc public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) -> Bool {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "initialize":            initialize(args: args, result: result);            return true
        case "play":                  play(result: result);                              return true
        case "pause":                 pause(result: result);                             return true
        case "seekTo":                seekTo(args: args, result: result);                return true
        case "setPlaybackSpeed":      setPlaybackSpeed(args: args, result: result);      return true
        case "setLooping":            setLooping(args: args, result: result);            return true
        case "dispose":               disposePlayer(result: result);                     return true
        case "setNowPlayingMetadata": setNowPlayingMetadata(args: args, result: result); return true
        case "setNowPlayingState":    setNowPlayingState(args: args, result: result);    return true
        case "enablePip":             enablePip(result: result);                         return true
        case "disablePip":            disablePip(result: result);                        return true
        case "isPipSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())
            return true
        case "enterPip":              enterPip(result: result);                          return true
        case "exitPip":               exitPip(result: result);                           return true
        default:                      return false
        }
    }

    // ── Initialize ────────────────────────────────────────────────────────

    /**
     * Creates a new AVPlayer for the given URL with optional HTTP headers,
     * FairPlay DRM, resolution cap, and peak bitrate limit.
     * Resolves the Flutter result with `{"durationMs": Int}` once
     * `AVPlayerItem.status` reaches `.readyToPlay`.
     *
     * Buffer configuration:
     * - VOD: 30s forward buffer, stall-avoidance enabled.
     * - Live: 3s forward buffer, stall-avoidance disabled (play at edge).
     */
    private func initialize(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let urlString = args?["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "BAD_ARGS", message: "url required", details: nil))
            return
        }

        let headers     = args?["headers"]    as? [String: String] ?? [:]
        let title       = args?["title"]      as? String ?? ""
        let artist      = args?["artist"]     as? String ?? ""
        let artwork     = args?["artwork"]    as? String
        let isLive      = args?["isLive"]     as? Bool   ?? false
        let maxWidth    = args?["maxWidth"]   as? Int
        let maxHeight   = args?["maxHeight"]  as? Int
        let peakBitrate = args?["peakBitRate"] as? Double ?? 0

        let drmConfig = (args?["drm"] as? [String: Any]).flatMap {
            SenzuFairPlayConfig(from: ["drm": $0])
        }

        _title = title; _artist = artist; _artworkUrl = artwork; _isLive = isLive

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.releasePlayer()
            self.invalidateArtworkCache()

            // Build AVURLAsset with optional custom HTTP headers
            var options: [String: Any] = [:]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            options[AVURLAssetAllowsCellularAccessKey] = true

            let asset = AVURLAsset(url: url, options: options)

            // Attach FairPlay DRM if configured
            if let cfg = drmConfig {
                let mgr = SenzuDrmManager()
                mgr.onError = { [weak self] msg in self?.emitError("DRM error: \(msg)") }
                mgr.attach(to: asset, config: cfg)
                self.drmManager = mgr
            }

            let item = AVPlayerItem(asset: asset)

            // Forward buffer: 3s for live (minimise latency), 30s for VOD
            item.preferredForwardBufferDuration = isLive ? 3.0 : 30.0

            // Resolution cap — avoids decoding higher resolution than the display
            if let w = maxWidth, let h = maxHeight {
                item.preferredMaximumResolution = CGSize(width: w, height: h)
            }

            // Peak bitrate cap — 0 means AVPlayer selects automatically
            item.preferredPeakBitRate = peakBitrate

            self.playerItem = item

            let avPlayer = AVPlayer(playerItem: item)
            // For live streams: play at the live edge; disable stall-avoidance
            avPlayer.automaticallyWaitsToMinimizeStalling = !isLive

            // Disable AirPlay mirroring for DRM content
            if drmConfig != nil { avPlayer.allowsExternalPlayback = false }

            self.player = avPlayer

            // Create and share the player layer
            let layer = AVPlayerLayer(player: avPlayer)
            layer.videoGravity = .resizeAspect
            self.playerLayer = layer
            SenzuAVPlayerManager.sharedPlayerLayer = layer

            // Enable HDR on supported displays (iOS 17+)
            if #available(iOS 17.0, *) {
                if UIScreen.main.currentEDRHeadroom > 1.0 {
                    layer.wantsExtendedDynamicRangeContent = true
                }
            }

            // Notify _SenzuLayerHostView to pick up the new layer
            NotificationCenter.default.post(
                name: NSNotification.Name("SenzuPlayerLayerDidChange"),
                object: nil
            )

            self.attachObservers(item: item, player: avPlayer)
            self.setupPipIfEnabled(layer: layer)

            // One-shot KVO observer that resolves the Flutter result
            var readyObserver: NSKeyValueObservation?
            readyObserver = item.observe(\.status, options: [.new]) {
                [weak self, weak item] _, _ in
                guard let self, let item else { readyObserver?.invalidate(); return }

                if item.status == .readyToPlay {
                    readyObserver?.invalidate(); readyObserver = nil
                    let durationMs = self.cmTimeToMs(item.asset.duration)
                    self.updateNowPlayingInfo()
                    result(["durationMs": durationMs])
                } else if item.status == .failed {
                    readyObserver?.invalidate(); readyObserver = nil
                    result(FlutterError(
                        code: "INIT_ERROR",
                        message: item.error?.localizedDescription ?? "AVPlayer error",
                        details: nil))
                }
            }
        }
    }

    // ── Playback controls ─────────────────────────────────────────────────

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

    /**
     * Seeks to the given position with zero tolerance for scrub-bar accuracy.
     */
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
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    self?.player?.seek(to: .zero)
                    self?.player?.play()
                }
            }
            result(nil)
        }
    }

    // ── Now Playing ───────────────────────────────────────────────────────

    private func setNowPlayingMetadata(args: [String: Any]?, result: @escaping FlutterResult) {
        let newArtworkUrl = args?["artwork"] as? String
        
        _title      = args?["title"]   as? String ?? _title
        _artist     = args?["artist"]  as? String ?? _artist
        _artworkUrl = args?["artwork"] as? String ?? _artworkUrl
        _isLive     = args?["isLive"]  as? Bool   ?? _isLive

        if newArtworkUrl != _artworkUrl {
            _cachedArtwork         = nil
            _cachedArtworkUrl      = nil
            _artworkFetchInProgress = false
            _artworkUrl            = newArtworkUrl
            _lastNowPlayingUpdate   = 0
        }
        updateNowPlayingInfo()
        fetchArtworkIfNeeded()
        result(nil)
    }

    private func setNowPlayingState(args: [String: Any]?, result: @escaping FlutterResult) {
        updateNowPlayingInfo()
        result(nil)
    }

    @objc public func updateNowPlayingInfoPublic() { updateNowPlayingInfo() }

    /**
     * Writes the current playback state and metadata to [MPNowPlayingInfoCenter].
     * Throttled to [_nowPlayingThrottleMs] to prevent unnecessary lock-screen redraws.
     * Artwork is written immediately from cache if the URL matches; otherwise fetched
     * asynchronously.
     */
    private func updateNowPlayingInfo() {
        let now = Date().timeIntervalSince1970
        guard now - _lastNowPlayingUpdate >= _nowPlayingThrottleMs else { return }
        _lastNowPlayingUpdate = now

        guard let player, let item = playerItem else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle]  = _title.isEmpty ? "SenzuPlayer" : _title
        info[MPMediaItemPropertyArtist] = _artist
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(cmTimeToMs(player.currentTime())) / 1000.0
        info[MPMediaItemPropertyPlaybackDuration]         = _isLive ? 0.0 : Double(cmTimeToMs(item.duration)) / 1000.0
        info[MPNowPlayingInfoPropertyPlaybackRate]        = Double(player.rate)
        info[MPNowPlayingInfoPropertyIsLiveStream]        = _isLive

        if let cached = _cachedArtwork, _cachedArtworkUrl == _artworkUrl {
            info[MPMediaItemPropertyArtwork] = cached
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        fetchArtworkIfNeeded()
    }

    // ── Artwork fetch ──────────────────────────────────────────────────────

    /**
     * Fetches the artwork image from [_artworkUrl] in the background if the URL
     * has changed.  Uses `.returnCacheDataElseLoad` to avoid redundant downloads.
     * On success, caches the [MPMediaItemArtwork] and updates the Now Playing info.
     */
    private func fetchArtworkIfNeeded() {
        guard
            let artStr = _artworkUrl,
            !artStr.isEmpty,
            artStr != _cachedArtworkUrl,
            !_artworkFetchInProgress
        else { return }

        _artworkFetchInProgress = true
        var request = URLRequest(url: URL(string: artStr)!)
        request.cachePolicy   = .returnCacheDataElseLoad
        request.timeoutInterval = 10

        let targetUrl = artStr
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else {
                self?._artworkFetchInProgress = false
                return
            }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async {
                self._cachedArtwork         = artwork
                self._cachedArtworkUrl      = targetUrl
                self._artworkFetchInProgress = false
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                updated[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }.resume()
    }

    private func invalidateArtworkCache() {
        _cachedArtwork         = nil
        _cachedArtworkUrl      = nil
        _artworkFetchInProgress = false
    }

    // ── Remote Command Center ─────────────────────────────────────────────

    /**
     * Registers handlers for hardware and lock-screen transport controls.
     * Each command emits a remote-control event to Flutter via [eventSink].
     * Must be called after the event stream is active.
     */
    @objc public func setupRemoteCommands(eventSink: @escaping FlutterEventSink) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play(); self?.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "play"])
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause(); self?.updateNowPlayingInfo()
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

        center.skipForwardCommand.isEnabled          = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let cur = self.player?.currentTime() ?? .zero
            self.player?.seek(to: CMTimeAdd(cur, CMTime(seconds: e.interval, preferredTimescale: 600)))
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "skipForward", "interval": e.interval])
            return .success
        }

        center.skipBackwardCommand.isEnabled          = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let cur = self.player?.currentTime() ?? .zero
            self.player?.seek(to: CMTimeSubtract(cur, CMTime(seconds: e.interval, preferredTimescale: 600)))
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "skipBackward", "interval": e.interval])
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.player?.seek(to: CMTime(seconds: e.positionTime, preferredTimescale: 600))
            self.updateNowPlayingInfo()
            eventSink(["type": "remote", "action": "seek", "positionSec": e.positionTime])
            return .success
        }
    }

    /** Removes all remote command handlers and clears Now Playing info. */
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

    // ── Picture-in-Picture ────────────────────────────────────────────────

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
        if let layer = playerLayer { setupPipIfEnabled(layer: layer) }
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
        DispatchQueue.main.async { pip.startPictureInPicture(); result(nil) }
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

    // ── Low-latency / Live ────────────────────────────────────────────────

    /**
     * Configures the player for low-latency live streaming.
     * Sets the forward buffer to [targetMs] ms and disables stall-avoidance.
     */
    @objc public func setLowLatencyMode(targetMs: Int) {
        let targetSec = Double(targetMs) / 1000.0
        DispatchQueue.main.async { [weak self] in
            self?.playerItem?.preferredForwardBufferDuration = targetSec
            self?.player?.automaticallyWaitsToMinimizeStalling = false
        }
    }

    /**
     * Returns the live edge latency in milliseconds, or -1 if unavailable.
     */
    @objc public func getLiveLatency() -> Double {
        guard let item = playerItem, item.isPlaybackLikelyToKeepUp else { return -1 }
        guard let end = item.seekableTimeRanges.last?.timeRangeValue else { return -1 }
        let liveEdge   = CMTimeGetSeconds(CMTimeRangeGetEnd(end))
        let currentPos = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let latency    = liveEdge - currentPos
        return latency > 0 ? latency * 1000 : -1
    }

    // ── Audio tracks ──────────────────────────────────────────────────────

    /** Returns available audio tracks for the current item. */
    @objc public func getAudioTracks() -> [[String: Any]] {
        guard let item = playerItem else { return [] }
        guard let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return [] }
        return g.options.enumerated().map { (i, option) in [
            "id":       "\(i)",
            "language": option.locale?.languageCode ?? "und",
            "label":    option.displayName(with: Locale.current),
            "selected": item.currentMediaSelection.selectedMediaOption(in: g) == option
        ]}
    }

    /** Selects an audio track by its string index. */
    @objc public func setAudioTrack(trackId: String) {
        guard let item = playerItem, let idx = Int(trackId) else { return }
        guard let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              idx < g.options.count else { return }
        DispatchQueue.main.async { item.select(g.options[idx], in: g) }
    }

    // ── KVO / notification observers ──────────────────────────────────────

    /**
     * Attaches all KVO and notification observers for the given player and item.
     * - Periodic time observer at 200ms for position updates.
     * - KVO on status, bufferEmpty, likelyToKeepUp, rate.
     * - Notifications for playback-failed and did-play-to-end.
     */
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

        // Observe both bufferEmpty AND likelyToKeepUp for accurate buffering state
        bufferObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) {
            [weak self] item, _ in
            self?.emitPlaybackState(isBuffering: item.isPlaybackBufferEmpty)
        }

        likelyToKeepUpObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) {
            [weak self] item, _ in
            if item.isPlaybackLikelyToKeepUp {
                self?.emitPlaybackState(isBuffering: false)
            }
        }

        rateObserver = player.observe(\.rate, options: [.new]) {
            [weak self] _, _ in self?.emitPlaybackState()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(playerItemFailed(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime, object: item)

        NotificationCenter.default.addObserver(
            self, selector: #selector(playerItemDidEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    @objc private func playerItemFailed(_ notification: Notification) {
        let err = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        emitError(err?.localizedDescription ?? "AVPlayer playback failed")
    }

    @objc private func playerItemDidEnd(_ notification: Notification) {
        updateNowPlayingInfo()
    }

    // ── Event emission ─────────────────────────────────────────────────────

    /**
     * Emits a `playback` event to Flutter.
     * [isBuffering] uses both `isPlaybackBufferEmpty` and `!isPlaybackLikelyToKeepUp`
     * when not explicitly provided, giving more accurate buffering feedback.
     */
    private func emitPlaybackState(isBuffering: Bool? = nil) {
        guard let player, let item = playerItem, let sink = eventSink else { return }

        let posMs   = cmTimeToMs(player.currentTime())
        let durMs   = cmTimeToMs(item.duration)
        let playing = player.rate != 0 && player.error == nil
        let buf     = isBuffering ?? (item.isPlaybackBufferEmpty && !item.isPlaybackLikelyToKeepUp)

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

    // ── Utilities ─────────────────────────────────────────────────────────

    private func cmTimeToMs(_ time: CMTime) -> Int64 {
        guard time.isValid, !time.isIndefinite else { return 0 }
        return Int64(CMTimeGetSeconds(time) * 1000)
    }

    // ── Dispose ───────────────────────────────────────────────────────────

    @objc public func disposePlayer(result: FlutterResult? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.releasePlayer()
            result?(nil)
        }
    }

    private func releasePlayer() {
        if let obs = timeObserver, let p = player { p.removeTimeObserver(obs) }
        timeObserver              = nil
        statusObserver?.invalidate();            statusObserver = nil
        bufferObserver?.invalidate();            bufferObserver = nil
        likelyToKeepUpObserver?.invalidate();    likelyToKeepUpObserver = nil
        rateObserver?.invalidate();              rateObserver = nil
        errorObserver?.invalidate();             errorObserver = nil
        pipPossibleObserver?.invalidate();       pipPossibleObserver = nil

        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        if let obs = memoryPressureObserver {
            NotificationCenter.default.removeObserver(obs)
            memoryPressureObserver = nil
        }

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

    deinit {
        if let obs = memoryPressureObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVPictureInPictureControllerDelegate
// ─────────────────────────────────────────────────────────────────────────────

extension SenzuAVPlayerManager: AVPictureInPictureControllerDelegate {

    public func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        _pipActive = true
        eventSink?(["type": "pip", "isPossible": true, "isActive": true] as [String: Any])
    }

    public func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        _pipActive = false
        eventSink?(["type": "pip",
                    "isPossible": controller.isPictureInPicturePossible,
                    "isActive": false] as [String: Any])
    }

    public func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}