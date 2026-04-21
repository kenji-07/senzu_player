package dev.senzu.senzu_player

import android.content.Context
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class SenzuSurfaceViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return SenzuSurfacePlatformView(context)
    }
}

class SenzuSurfacePlatformView(context: Context) : PlatformView, SurfaceHolder.Callback {

    companion object {
        var currentPlayer: ExoPlayer? = null
    }

    private val surfaceView: SurfaceView = SurfaceView(context)

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = surfaceView
    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        currentPlayer?.clearVideoSurface()
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        currentPlayer?.setVideoSurface(holder.surface)
    }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
      
    }
    override fun surfaceDestroyed(holder: SurfaceHolder) {
        currentPlayer?.clearVideoSurface()
    }
}