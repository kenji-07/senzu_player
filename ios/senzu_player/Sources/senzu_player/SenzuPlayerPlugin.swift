import Flutter
import UIKit
import AVKit
import MediaPlayer
import AVFoundation
import Network
import VideoToolbox
#if canImport(ScreenProtectorKit)
import ScreenProtectorKit
#endif
#if canImport(GoogleCast)
import GoogleCast
#endif

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
#if canImport(ScreenProtectorKit)
    private static var screenProtector: ScreenProtectorKit?
#endif
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

        let downloadMethod = FlutterMethodChannel(
            name: "senzu_player/downloader",
            binaryMessenger: registrar.messenger())
        downloadMethod.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "startDownload":
                let id = args?["id"] as? String ?? ""
                let url = args?["url"] as? String ?? ""
                let headers = args?["headers"] as? [String: String] ?? [:]
                let drmConfig = args?["drmConfig"] as? [String: Any] ?? [:]
                let title = args?["title"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.startDownload(id: id, urlString: url, headers: headers, drmConfig: drmConfig, title: title)
                }
                result(nil)
            case "pauseDownload":
                let id = args?["id"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.pauseDownload(id: id)
                }
                result(nil)
            case "resumeDownload":
                let id = args?["id"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.resumeDownload(id: id)
                }
                result(nil)
            case "cancelDownload":
                let id = args?["id"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.cancelDownload(id: id)
                }
                result(nil)
            case "deleteDownload":
                let id = args?["id"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.deleteDownload(id: id)
                }
                result(nil)
            case "notifyLicenseExpired":
                let id = args?["id"] as? String ?? ""
                let title = args?["title"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.notifyLicenseExpired(id: id, title: title)
                }
                result(nil)
            case "requestNotificationPermission":
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.requestNotificationPermission()
                }
                result(nil)
            case "setNotificationLocales":
                let downloadCompleteTitle = args?["downloadCompleteTitle"] as? String ?? ""
                let downloadCompleteBody = args?["downloadCompleteBody"] as? String ?? ""
                let downloadFailedTitle = args?["downloadFailedTitle"] as? String ?? ""
                let downloadFailedBody = args?["downloadFailedBody"] as? String ?? ""
                let licenseExpiredTitle = args?["licenseExpiredTitle"] as? String ?? ""
                let licenseExpiredBody = args?["licenseExpiredBody"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    SenzuDownloadManager.shared.setNotificationLocales(
                        completeTitle: downloadCompleteTitle, completeBody: downloadCompleteBody,
                        failedTitle: downloadFailedTitle, failedBody: downloadFailedBody,
                        expiredTitle: licenseExpiredTitle, expiredBody: licenseExpiredBody
                    )
                }
                result(nil)
            case "resolveBookmark":
                // Flutter passes the "bookmark:<base64>" string stored in SQLite.
                // Returns the resolved absolute file path, or nil/null if stale.
                let bookmarkString = args?["bookmark"] as? String ?? ""
                if #available(iOS 10.0, *) {
                    if let url = SenzuDownloadManager.resolveBookmark(bookmarkString) {
                        result(url.path)
                    } else {
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "checkFileExists":
                // Check whether a local path (after bookmark resolution) still exists on disk.
                let path = args?["path"] as? String ?? ""
                result(FileManager.default.fileExists(atPath: path))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        let downloadEvent = FlutterEventChannel(
            name: "senzu_player/downloader_events",
            binaryMessenger: registrar.messenger())
        downloadEvent.setStreamHandler(SenzuDownloadStreamHandler())

#if canImport(ScreenProtectorKit)
        DispatchQueue.main.async {
            let kit = ScreenProtectorKit(window: SenzuPlayerPlugin.keyWindow())
            kit.setRootViewResolver(SenzuRootViewResolver())
            ScreenProtectorKit.initial(with: kit.window?.rootViewController?.view)
            SenzuPlayerPlugin.screenProtector = kit
        }
#endif
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
#if canImport(GoogleCast)
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
#else
            result(nil) // Cast SPM build-д дэмжигдэхгүй
#endif

        // ── Screen protection ──────────────────────────────────────────────
        case "enableSecureMode":
#if canImport(ScreenProtectorKit)
            DispatchQueue.main.async {
                SenzuPlayerPlugin.screenProtector?.enabledPreventScreenshot()
                SenzuPlayerPlugin.screenProtector?.enabledPreventScreenRecording()
            }
#endif
            result(nil)

        case "disableSecureMode":
#if canImport(ScreenProtectorKit)
            DispatchQueue.main.async {
                SenzuPlayerPlugin.screenProtector?.disablePreventScreenshot()
                SenzuPlayerPlugin.screenProtector?.disablePreventScreenRecording()
            }
#endif
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

        case "launchUrl":
            let url = args?["url"] as? String ?? ""
            SenzuUrlLauncher.launchUrl(url) { success in
                result(success)
            }

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

#if canImport(ScreenProtectorKit)
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
#endif

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