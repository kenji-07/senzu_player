package dev.senzu.senzu_player

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// ─────────────────────────────────────────────────────────────────────────────
// SenzuSurfaceViewFactory / SenzuSurfacePlatformView
// Provides a native Android SurfaceView to Flutter via the Platform View API.
// The ExoPlayer instance is wired to the surface through the companion object
// so the player can be attached/detached without coupling to the view lifecycle.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Flutter [PlatformViewFactory] that creates [SenzuSurfacePlatformView] instances.
 * Registered under the view type `senzu_player/surface`.
 */
class SenzuSurfaceViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return SenzuSurfacePlatformView(context)
    }
}

/**
 * A [PlatformView] that hosts a [SurfaceView] and connects it to
 * [SenzuSurfacePlatformView.currentPlayer] via [SurfaceHolder.Callback].
 *
 * The active [ExoPlayer] is stored in [currentPlayer] by [SenzuExoPlayerManager]
 * so that the surface can attach/detach transparently across view recycling.
 */
class SenzuSurfacePlatformView(context: Context) : PlatformView, SurfaceHolder.Callback {

    companion object {
        /**
         * The currently active [ExoPlayer] to bind to new surfaces.
         * Set by [SenzuExoPlayerManager] when a player is initialised or released.
         */
        var currentPlayer: ExoPlayer? = null
    }

    private val surfaceView: SurfaceView = SurfaceView(context)

    init {
        surfaceView.holder.addCallback(this)
    }

    // ── PlatformView ───────────────────────────────────────────────────────

    override fun getView(): View = surfaceView

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        currentPlayer?.clearVideoSurface()
    }

    // ── SurfaceHolder.Callback ─────────────────────────────────────────────

    /** Called when the surface is ready — attach it to the current player. */
    override fun surfaceCreated(holder: SurfaceHolder) {
        currentPlayer?.setVideoSurface(holder.surface)
    }

    /** ExoPlayer adapts to size changes automatically; no action needed. */
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = Unit

    /** Called when the surface is about to be destroyed — detach from player. */
    override fun surfaceDestroyed(holder: SurfaceHolder) {
        currentPlayer?.clearVideoSurface()
    }
}