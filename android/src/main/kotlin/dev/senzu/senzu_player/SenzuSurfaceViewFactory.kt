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

class SenzuSurfaceViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return SenzuHybridSurfaceView(context)
    }
}

class SenzuHybridSurfaceView(context: Context) : PlatformView {

    private val surfaceView = SurfaceView(context)

    companion object {
        var currentPlayer: ExoPlayer? = null
    }

    init {
        surfaceView.setZOrderMediaOverlay(false)
        surfaceView.setZOrderOnTop(false)

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                currentPlayer?.setVideoSurface(holder.surface)
            }

            override fun surfaceChanged(
                holder: SurfaceHolder,
                format: Int,
                width: Int,
                height: Int
            ) {
               
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                currentPlayer?.clearVideoSurface()
            }
        })
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        currentPlayer?.clearVideoSurface()
        surfaceView.holder.surface?.release()
    }
}

object SenzuSurfacePlatformView {
    var currentPlayer: ExoPlayer?
        get() = SenzuHybridSurfaceView.currentPlayer
        set(value) { SenzuHybridSurfaceView.currentPlayer = value }
}