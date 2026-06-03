import Flutter
import UIKit
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// SenzuSurfaceViewFactory / SenzuPlayerLayerView / _SenzuLayerHostView
// Exposes a native AVPlayerLayer to Flutter via the Platform View API.
// The player layer is owned by SenzuAVPlayerManager; the host view only
// inserts it as a sublayer and keeps a weak reference.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Flutter [FlutterPlatformViewFactory] that vends [SenzuPlayerLayerView] instances.
 * Registered under the view type `senzu_player/surface`.
 */
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
        FlutterStandardMessageCodec.sharedInstance()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuPlayerLayerView — FlutterPlatformView wrapper
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Thin [FlutterPlatformView] that wraps [_SenzuLayerHostView].
 * All layout and layer management logic lives in the host view.
 */
public class SenzuPlayerLayerView: NSObject, FlutterPlatformView {

    private let containerView: _SenzuLayerHostView

    init(frame: CGRect) {
        // UIView subclasses must be created on the main thread
        assert(Thread.isMainThread, "SenzuPlayerLayerView must be created on main thread")
        containerView = _SenzuLayerHostView(frame: frame)
        super.init()
    }

    public func view() -> UIView { containerView }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SenzuLayerHostView — UIView that hosts the AVPlayerLayer
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Private UIView subclass that installs the [AVPlayerLayer] produced by
 * [SenzuAVPlayerManager] as its bottom-most sublayer.
 *
 * Design notes:
 * - Holds only a `weak` reference to the layer because [SenzuAVPlayerManager]
 *   owns the layer's lifetime.
 * - Observes `SenzuPlayerLayerDidChange` to react to player re-creation without
 *   strong coupling.
 * - Uses a token-based [NotificationCenter] observer to prevent retain cycles
 *   and memory leaks.
 * - Disables CATransaction implicit animations during frame updates to prevent
 *   flicker and layout artifacts.
 */
final class _SenzuLayerHostView: UIView {

    // Weak reference: the manager owns the AVPlayerLayer, not this view
    private weak var playerLayer: AVPlayerLayer?
    private var notificationToken: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        assert(Thread.isMainThread)
        installLayerIfAvailable()

        // Token-based observer prevents retain cycles.
        // Delivered on .main so UIKit calls are always on the correct thread.
        notificationToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SenzuPlayerLayerDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.installLayerIfAvailable()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // ── Layer installation ─────────────────────────────────────────────────

    /**
     * Installs the current shared player layer if one is available and is
     * not already the installed layer.  Guards against unnecessary reinstalls
     * that would cause flicker.
     */
    private func installLayerIfAvailable() {
        assert(Thread.isMainThread, "installLayerIfAvailable must run on main thread")
        guard let layer = SenzuAVPlayerManager.sharedPlayerLayer else { return }
        // Avoid reinstalling the same layer — prevents flicker and layout churn
        if playerLayer === layer { return }
        installLayer(layer)
    }

    private func installLayer(_ l: AVPlayerLayer) {
        // Remove the previous layer from the hierarchy
        playerLayer?.removeFromSuperlayer()
        playerLayer = l

        l.videoGravity = .resizeAspect
        // Set frame synchronously — do not wait for layoutSubviews for correct
        // initial sizing
        l.frame = bounds
        // Insert at index 0 so Flutter content can be rendered above the video
        self.layer.insertSublayer(l, at: 0)
    }

    // ── Layout ─────────────────────────────────────────────────────────────

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let layer = playerLayer else {
            // No layer yet — try again after the manager has been initialised
            installLayerIfAvailable()
            return
        }

        // Disable implicit CATransaction animations to prevent resize artifacts
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = bounds
        CATransaction.commit()
    }
}