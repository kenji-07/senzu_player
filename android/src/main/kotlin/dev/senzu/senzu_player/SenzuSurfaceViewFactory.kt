package dev.senzu.senzu_player

import android.content.Context
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Registers "senzu_player/surface" as a native PlatformView.
 *
 * The view is a SurfaceView whose Surface is handed to ExoPlayer by
 * [SenzuExoPlayerManager]. Flutter renders this view inside an
 * [AndroidView] widget (see senzu_video_surface.dart).
 *
 * Creation params (passed from Dart via AndroidView.creationParams):
 *   { "textureId": <long> }   — reserved for future multi-player support.
 */
class SenzuSurfaceViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return SenzuSurfacePlatformView(context)
    }
}

/**
 * Thin PlatformView wrapper around a SurfaceView.
 *
 * [SenzuExoPlayerManager.initialize] calls [ExoPlayer.setVideoSurface]
 * with the Surface from the texture entry, so the ExoPlayer output is
 * already wired up before this view appears. The SurfaceView here is
 * used when FLAG_SECURE (DRM) requires a real SurfaceView rather than
 * a TextureView/SurfaceTexture.
 *
 * For non-secure playback the texture-based path is used automatically
 * by ExoPlayer; this SurfaceView acts as the DRM fallback surface.
 */
class SenzuSurfacePlatformView(context: Context) : PlatformView {

    private val surfaceView: SurfaceView = SurfaceView(context).apply {
        // Keep the surface alive behind other views so ExoPlayer can
        // render into it even when overlays (subtitles, controls) are on top.
        holder.setType(android.view.SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        // Surface is managed by ExoPlayer; nothing extra to release here.
    }
}