import Flutter
import UIKit
import AVKit
import MediaPlayer
import AVFoundation
import Network
import VideoToolbox
import ScreenProtectorKit
import GoogleCast

// ─────────────────────────────────────────────────────────────────────────────
// SenzuPlayerPlugin — root Flutter plugin class for SenzuPlayer on iOS
//
// Channel layout:
//   senzu_player/native        — playback & device method channel
//   senzu_player/events        — playback & device event channel
//   senzu_player/cast          — Cast method channel
//   senzu_player/cast_events   — Cast event channel
//   senzu_player/surface       — Platform View (AVPlayerLayer host)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Root [FlutterPlugin] for SenzuPlayer on iOS.
 *
 * Delegates all AVPlayer operations to [SenzuAVPlayerManager] and Google Cast
 * operations to [SenzuCastPlugin].  Handles device-level APIs directly:
 * screen protection, wakelock, volume, brightness, battery, network, HDR,
 * codec detection, low-latency live, and audio-track selection.
 */
public class SenzuPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // ── Sub-managers ───────────────────────────────────────────────────────

    private var avManager: SenzuAVPlayerManager?
    private static var screenProtector: ScreenProtectorKit?

    // ── EventChannel state ─────────────────────────────────────────────────

    private var eventSink: FlutterEventSink?
    /// Tracks whether the Flutter event stream is currently active to prevent
    /// "No active stream" errors from stale observers.
    private var isStreamActive = false

    // ── Registration ───────────────────────────────────────────────────────

    public static func register(with registrar: FlutterPluginRegistrar) {
        let method = FlutterMethodChannel(
            name: "senzu_player/native",
            binaryMessenger: registrar.messenger())
        let instance = SenzuPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: method)

        let event = FlutterEventChannel(
            name: "senzu_player/events",
            binaryMessenger: registrar.messenger())
        event.setStreamHandler(instance)

        instance.avManager = SenzuAVPlayerManager(messenger: registrar.messenger())

        registrar.register(
            SenzuSurfaceViewFactory(messenger: registrar.messenger()),
            withId: "senzu_player/surface")

        // ── Google Cast SDK initialisation ────────────────────────────────
        // Initialise inside the plugin to avoid coupling the host app's
        // AppDelegate.  Guard against duplicate initialisation on hot restart.
        DispatchQueue.main.async {
            if !GCKCastContext.isSharedInstanceInitialized() {
                let criteria = GCKDiscoveryCriteria(
                    applicationID: kGCKDefaultMediaReceiverApplicationID)
                let options = GCKCastOptions(discoveryCriteria: criteria)
                options.physicalVolumeButtonsWillControlDeviceVolume = true
                options.startDiscoveryAfterFirstTapOnCastButton      = false
                GCKCastContext.setSharedInstanceWith(options)
                GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
                print("SenzuPlayer: GCKCastContext initialized successfully")
            } else {
                print("SenzuPlayer: GCKCastContext already initialized, skipping")
            }

            // Register Cast channels after the context is ready
            let castMethod = FlutterMethodChannel(
                name: "senzu_player/cast",
                binaryMessenger: registrar.messenger())
            let castEvent = FlutterEventChannel(
                name: "senzu_player/cast_events",
                binaryMessenger: registrar.messenger())
            SenzuCastPlugin.register(with: registrar, method: castMethod, event: castEvent)
        }

        // ── Screen protection ─────────────────────────────────────────────
        DispatchQueue.main.async {
            let kit = ScreenProtectorKit(window: SenzuPlayerPlugin.keyWindow())
            kit.setRootViewResolver(SenzuRootViewResolver())
            ScreenProtectorKit.initial(with: kit.window?.rootViewController?.view)
            SenzuPlayerPlugin.screenProtector = kit
        }
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        // Delegate all playback calls to the AV manager first
        if avManager?.handle(call, result: result) == true { return }

        switch call.method {

        // ── Screen protection ──────────────────────────────────────────────
        case "enableSecureMode":
            DispatchQueue.main.async {
                SenzuPlayerPlugin.screenProtector?.enabledPreventScreenshot()
                SenzuPlayerPlugin.screenProtector?.enabledPreventScreenRecording()
            }
            result(nil)

        case "disableSecureMode":
            DispatchQueue.main.async {
                SenzuPlayerPlugin.screenProtector?.disablePreventScreenshot()
                SenzuPlayerPlugin.screenProtector?.disablePreventScreenRecording()
            }
            result(nil)

        // ── Wakelock ───────────────────────────────────────────────────────
        case "enableWakelock":
            UIApplication.shared.isIdleTimerDisabled = true;  result(nil)
        case "disableWakelock":
            UIApplication.shared.isIdleTimerDisabled = false; result(nil)

        // ── Volume ─────────────────────────────────────────────────────────
        case "getVolume":
            result(Double(AVAudioSession.sharedInstance().outputVolume))
        case "setVolume":
            if let v = args?["volume"] as? Double { SenzuVolume.set(Float(v)) }
            result(nil)

        // ── Brightness ─────────────────────────────────────────────────────
        case "getBrightness":
            result(Double(UIScreen.main.brightness))
        case "setBrightness":
            if let b = args?["brightness"] as? Double {
                DispatchQueue.main.async { UIScreen.main.brightness = CGFloat(b) }
            }
            result(nil)

        // ── Battery ────────────────────────────────────────────────────────
        case "getBatteryLevel":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let lvl = UIDevice.current.batteryLevel
            result(lvl < 0 ? -1 : Int(lvl * 100))
        case "getBatteryState":
            UIDevice.current.isBatteryMonitoringEnabled = true
            result(SenzuBattery.stateString(UIDevice.current.batteryState))

        // ── Network ────────────────────────────────────────────────────────
        case "getNetworkType":
            let monitor = NWPathMonitor()
            let queue   = DispatchQueue(label: "dev.senzu.network")
            let fr      = result
            monitor.pathUpdateHandler = { path in
                let type: String
                if path.status == .satisfied {
                    type = path.usesInterfaceType(.wifi) ? "wifi" : "cellular"
                } else { type = "none" }
                monitor.cancel()
                DispatchQueue.main.async { fr(type) }
            }
            monitor.start(queue: queue)

        // ── HDR ────────────────────────────────────────────────────────────
        case "isHdrSupported":
            if #available(iOS 16.0, *) {
                result(UIScreen.main.currentEDRHeadroom > 1.0)
            } else { result(false) }
        case "enableHdrIfSupported":
            result(nil)

        // ── Low-latency / Live ─────────────────────────────────────────────
        case "setLowLatencyMode":
            let targetMs = args?["targetMs"] as? Int ?? 2000
            avManager?.setLowLatencyMode(targetMs: targetMs)
            result(nil)
        case "getLiveLatency":
            result(avManager?.getLiveLatency() ?? -1)

        // ── Audio tracks ───────────────────────────────────────────────────
        case "getAudioTracks":
            result(avManager?.getAudioTracks() ?? [])
        case "setAudioTrack":
            let trackId = args?["trackId"] as? String ?? ""
            avManager?.setAudioTrack(trackId: trackId)
            result(nil)

        // ── Codec support ──────────────────────────────────────────────────
        case "checkCodecSupport":
            let codec = args?["codec"] as? String ?? ""
            var supported = false
            if codec == "hevc" || codec == "h265" {
                if #available(iOS 11.0, *) {
                    supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
                }
            } else if codec == "av1" {
                if #available(iOS 16.0, *) {
                    supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
                }
            } else {
                supported = true
            }
            result(supported)

        // ── Now Playing ────────────────────────────────────────────────────
        case "setNowPlayingEnabled":
            let enabled = args?["enabled"] as? Bool ?? true
            if enabled {
                avManager?.updateNowPlayingInfoPublic()
                if let sink = self.eventSink {
                    avManager?.setupRemoteCommands(eventSink: sink)
                }
            } else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                avManager?.teardownRemoteCommands()
            }
            result(nil)

        // ── PiP ────────────────────────────────────────────────────────────
        case "isPipSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── EventChannel — FlutterStreamHandler ───────────────────────────────

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        // Remove stale observers if the stream is re-opened (e.g. hot restart)
        if isStreamActive { NotificationCenter.default.removeObserver(self) }

        self.eventSink = events
        isStreamActive = true
        avManager?.setEventSink(events)
        avManager?.setupRemoteCommands(eventSink: events)

        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIDevice.batteryStateDidChangeNotification, object: nil)

        // System volume monitoring
        try? AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(
            self, selector: #selector(volumeChanged(_:)),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil)

        // Audio session interruption (e.g. phone call)
        NotificationCenter.default.addObserver(
            self, selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)

        // Audio route changes (e.g. headphones unplugged)
        NotificationCenter.default.addObserver(
            self, selector: #selector(audioRouteChanged(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil)

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        guard isStreamActive else { return nil }
        isStreamActive = false
        NotificationCenter.default.removeObserver(self)
        avManager?.teardownRemoteCommands()
        avManager?.setEventSink(nil)
        eventSink = nil
        return nil
    }

    // ── Notification handlers ──────────────────────────────────────────────

    @objc private func batteryChanged() {
        guard isStreamActive else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        let lvl = UIDevice.current.batteryLevel
        eventSink?([
            "type":  "battery",
            "level": lvl < 0 ? -1 : Int(lvl * 100),
            "state": SenzuBattery.stateString(UIDevice.current.batteryState),
        ] as [String: Any])
    }

    @objc private func volumeChanged(_ n: Notification) {
        guard isStreamActive else { return }
        let vol = AVAudioSession.sharedInstance().outputVolume
        eventSink?(["type": "volume", "value": Double(vol)] as [String: Any])
    }

    @objc private func audioSessionInterrupted(_ n: Notification) {
        guard isStreamActive else { return }
        guard
            let info    = n.userInfo,
            let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type    = AVAudioSession.InterruptionType(rawValue: typeVal)
        else { return }
        eventSink?(["type": "audioInterruption", "interrupted": type == .began] as [String: Any])
    }

    @objc private func audioRouteChanged(_ n: Notification) {
        guard isStreamActive else { return }
        guard
            let info      = n.userInfo,
            let reasonVal = info[AVAudioSessionRouteChangeReasonKey] as? UInt
        else { return }
        if reasonVal == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
            eventSink?(["type": "audioRouteChange", "reason": "deviceUnavailable"] as [String: Any])
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuRootViewResolver
// Provides the Flutter root view to ScreenProtectorKit without coupling
// the plugin to a concrete view controller type.
// ─────────────────────────────────────────────────────────────────────────────

final class SenzuRootViewResolver: ScreenProtectorRootViewResolving {

    func resolveRootView() -> UIView? {
        guard Thread.isMainThread else { return nil }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return nil }
        guard let flutterVC = scene.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? FlutterViewController
        else { return nil }
        return flutterVC.view
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuVolume — system volume setter via MPVolumeView slider
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sets the system media volume by manipulating the hidden MPVolumeView slider.
 * The view is placed far off-screen so it is never visible to the user.
 */
class SenzuVolume {

    private static var slider: UISlider?

    static func set(_ v: Float) {
        DispatchQueue.main.async {
            if slider == nil {
                let vv = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
                let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })
                window?.addSubview(vv)
                slider = vv.subviews.compactMap { $0 as? UISlider }.first
            }
            slider?.value = v
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuBattery — UIDevice.BatteryState to string converter
// ─────────────────────────────────────────────────────────────────────────────

class SenzuBattery {
    static func stateString(_ s: UIDevice.BatteryState) -> String {
        switch s {
        case .charging:  return "charging"
        case .full:      return "full"
        case .unplugged: return "discharging"
        default:         return "unknown"
        }
    }
}