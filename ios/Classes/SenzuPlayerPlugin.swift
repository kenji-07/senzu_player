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
// ӨӨРЧЛӨЛТ (flutter_chrome_cast загварыг дуурайсан):
// - GCKCastContext native тал дээр initialize хийхгүй болсон
// - "initCast" method channel нэмэгдсэн
//   Flutter тал дээрээс SenzuCastService.initCast() дуудахад
//   native тал GCKCastContext-г kDefaultApplicationId-р initialize хийнэ
// ─────────────────────────────────────────────────────────────────────────────

public class SenzuPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var avManager: SenzuAVPlayerManager?
    private static var screenProtector: ScreenProtectorKit?
    private var eventSink: FlutterEventSink?
    private var isStreamActive = false

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

        // Cast channels — GCKCastContext-г энд initialize хийхгүй.
        // Flutter тал дээрээс "initCast" method дуудагдах үед initialize хийнэ.
        let castMethod = FlutterMethodChannel(
            name: "senzu_player/cast",
            binaryMessenger: registrar.messenger())
        let castEvent = FlutterEventChannel(
            name: "senzu_player/cast_events",
            binaryMessenger: registrar.messenger())
        SenzuCastPlugin.register(with: registrar, method: castMethod, event: castEvent)

        DispatchQueue.main.async {
            let kit = ScreenProtectorKit(window: SenzuPlayerPlugin.keyWindow())
            kit.setRootViewResolver(SenzuRootViewResolver())
            ScreenProtectorKit.initial(with: kit.window?.rootViewController?.view)
            SenzuPlayerPlugin.screenProtector = kit
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        if avManager?.handle(call, result: result) == true { return }

        switch call.method {

        // ── Cast initialize ────────────────────────────────────────────────
        // flutter_chrome_cast загварыг дуурайж Flutter тал дээрээс
        // appId дамжуулан GCKCastContext-г initialize хийнэ.
        // appId дамжуулаагүй бол kGCKDefaultMediaReceiverApplicationID ашиглана.
        case "initCast":
            let appId = args?["appId"] as? String ?? kGCKDefaultMediaReceiverApplicationID
            DispatchQueue.main.async {
                if !GCKCastContext.isSharedInstanceInitialized() {
                    let criteria = GCKDiscoveryCriteria(applicationID: appId)
                    let options  = GCKCastOptions(discoveryCriteria: criteria)
                    options.physicalVolumeButtonsWillControlDeviceVolume = true
                    options.startDiscoveryAfterFirstTapOnCastButton      = false
                    GCKCastContext.setSharedInstanceWith(options)
                    GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
                    print("SenzuPlayer: GCKCastContext initialized with appId=\(appId)")
                } else {
                    print("SenzuPlayer: GCKCastContext already initialized, skipping")
                }
                SenzuCastPlugin.setupAfterInit()
                result(nil)
            }

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

    // ── EventChannel ──────────────────────────────────────────────────────

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        if isStreamActive { NotificationCenter.default.removeObserver(self) }
        self.eventSink = events
        isStreamActive = true
        avManager?.setEventSink(events)
        avManager?.setupRemoteCommands(eventSink: events)

        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIDevice.batteryStateDidChangeNotification, object: nil)

        try? AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(
            self, selector: #selector(volumeChanged(_:)),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
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

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

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