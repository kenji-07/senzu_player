// ios/Classes/SenzuSurfaceViewFactory.swift — full refactor

import Flutter
import UIKit
import AVFoundation

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

public class SenzuPlayerLayerView: NSObject, FlutterPlatformView {
    private let containerView: _SenzuLayerHostView

    init(frame: CGRect) {
        // IMPORTANT: UIView subclass-ийг main thread дээр үүсгэнэ
        assert(Thread.isMainThread, "SenzuPlayerLayerView must be created on main thread")
        containerView = _SenzuLayerHostView(frame: frame)
        super.init()
    }

    public func view() -> UIView { containerView }
}

final class _SenzuLayerHostView: UIView {
    // Weak reference: AVPlayerLayer-г manager эзэмшдэг, view биш
    private weak var playerLayer: AVPlayerLayer?
    private var notificationToken: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        // Main thread guarantee: installLayerIfAvailable main-д л ажиллана
        assert(Thread.isMainThread)
        installLayerIfAvailable()

        // Token-based observer — removeObserver дуудахад token ашиглана
        // (object-based observer memory leak-ийн эх болдог)
        notificationToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SenzuPlayerLayerDidChange"),
            object: nil,
            queue: .main  // Main queue-д direct deliver — DispatchQueue.main.async шаардлагагүй
        ) { [weak self] _ in
            // [weak self]: retain cycle-ээс сэргийлнэ
            self?.installLayerIfAvailable()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        // Token-based observer цэвэрлэнэ
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func installLayerIfAvailable() {
        // Precondition: main thread шаардлагатай (UIKit contract)
        assert(Thread.isMainThread, "installLayerIfAvailable must run on main thread")

        guard let layer = SenzuAVPlayerManager.sharedPlayerLayer else { return }

        // Same layer байвал reinstall хийхгүй — флicker болон layout хойшлолтоос сэргийлнэ
        if playerLayer === layer { return }

        installLayer(layer)
    }

    private func installLayer(_ l: AVPlayerLayer) {
        // Хуучин layer-г sublayer-ийн жагсаалтаас хасна
        playerLayer?.removeFromSuperlayer()
        playerLayer = l

        l.videoGravity = .resizeAspect
        // Frame-г bounds-д synchronously тохируулна
        // (layoutSubviews-г хүлээхгүйгээр шууд correct size өгнө)
        l.frame = bounds
        self.layer.insertSublayer(l, at: 0) // addSublayer биш insertSublayer(at:0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let layer = playerLayer else {
            // layoutSubviews үед layer байхгүй бол дахин оролдоно
            installLayerIfAvailable()
            return
        }
        // CATransaction: layout animation-г disable хийнэ
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = bounds
        CATransaction.commit()
    }
}