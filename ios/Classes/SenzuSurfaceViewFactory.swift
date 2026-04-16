import Flutter
import UIKit
import AVFoundation

/// Registers "senzu_player/surface" as a native PlatformView.
///
/// The view hosts an [AVPlayerLayer] sourced from
/// [SenzuAVPlayerManager.sharedPlayerLayer]. Flutter renders this view
/// inside a [UiKitView] widget (see senzu_player.dart).
///
/// Creation params (passed from Dart via UiKitView.creationParams):
///   { } — reserved for future multi-player support.
public class SenzuSurfaceViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return SenzuPlayerLayerView(frame: frame)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// A UIView that hosts an [AVPlayerLayer].
///
/// The layer is obtained from [SenzuAVPlayerManager.sharedPlayerLayer]
/// which is set when [SenzuAVPlayerManager.initialize] runs. If the layer
/// is not yet available (race condition on cold start), it will be installed
/// via [SenzuAVPlayerManager.sharedPlayerLayerDidChange] notification.
public class SenzuPlayerLayerView: NSObject, FlutterPlatformView {

    private let containerView: _SenzuLayerHostView

    init(frame: CGRect) {
        containerView = _SenzuLayerHostView(frame: frame)
        super.init()
    }

    public func view() -> UIView { containerView }
}

/// Internal UIView subclass that owns the AVPlayerLayer.
final class _SenzuLayerHostView: UIView {

    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        installLayerIfAvailable()

        // Listen for when the manager creates a new player layer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerLayerDidChange),
            name: NSNotification.Name("SenzuPlayerLayerDidChange"),
            object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func installLayerIfAvailable() {
        guard let layer = SenzuAVPlayerManager.sharedPlayerLayer else { return }
        installLayer(layer)
    }

    private func installLayer(_ l: AVPlayerLayer) {
        playerLayer?.removeFromSuperlayer()
        playerLayer = l
        l.frame = bounds
        l.videoGravity = .resizeAspect
        self.layer.addSublayer(l)
    }

    @objc private func playerLayerDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.installLayerIfAvailable()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if playerLayer == nil { installLayerIfAvailable() } 
        playerLayer?.frame = bounds
    }
}