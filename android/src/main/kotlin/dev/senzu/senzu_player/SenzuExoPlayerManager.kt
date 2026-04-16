package dev.senzu.senzu_player

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackGroup
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

@UnstableApi
class SenzuExoPlayerManager(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry
) {
    private var player: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Polling interval for position updates (ms)
    private val positionPollMs = 200L
    private var positionRunnable: Runnable? = null

    // ── Public surface texture id (used by SurfaceViewFactory) ───────────
    val textureId: Long get() = textureEntry.id()

    fun setActivity(act: Activity?) { activity = act }
    fun setEventSink(sink: EventChannel.EventSink?) { eventSink = sink }

    // ── MethodCall dispatcher ──────────────────────────────────────────────
    // Returns true if the call was handled here, false if plugin should continue.
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        val args = call.arguments as? Map<*, *>
        return when (call.method) {
            "initialize"        -> { initialize(args, result); true }
            "play"              -> { play(result);             true }
            "pause"             -> { pause(result);            true }
            "seekTo"            -> { seekTo(args, result);     true }
            "setPlaybackSpeed"  -> { setPlaybackSpeed(args, result); true }
            "setLooping"        -> { setLooping(args, result); true }
            "dispose"           -> { dispose(result);          true }
            else                -> false
        }
    }

    // ── initialize ─────────────────────────────────────────────────────────
    private fun initialize(args: Map<*, *>?, result: MethodChannel.Result) {
        val url     = args?.get("url") as? String ?: run { result.error("BAD_ARGS", "url required", null); return }
        val headers = (args["headers"] as? Map<*, *>)
            ?.entries?.associate { (k, v) -> k.toString() to v.toString() }
            ?: emptyMap()

        mainHandler.post {
            releasePlayer()

            val selector = DefaultTrackSelector(context)
            trackSelector = selector

            val dataSourceFactory = DefaultHttpDataSource.Factory()
                .setDefaultRequestProperties(headers)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(15_000)
                .setAllowCrossProtocolRedirects(true)

            val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)

            val loadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    /* minBufferMs          */ 15_000,
                    /* maxBufferMs          */ 50_000,
                    /* bufferForPlaybackMs  */ 2_500,
                    /* bufferForPlaybackAfterRebufferMs */ 5_000
                )
                .build()

            val exo = ExoPlayer.Builder(context)
                .setTrackSelector(selector)
                .setMediaSourceFactory(mediaSourceFactory)
                .setLoadControl(loadControl)
                .build()

            // Attach surface texture so PlatformView can render
            val surface = android.view.Surface(textureEntry.surfaceTexture())
            exo.setVideoSurface(surface)

            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    when (state) {
                        Player.STATE_READY    -> emitPlaybackState()
                        Player.STATE_BUFFERING -> emitPlaybackState(isBuffering = true)
                        Player.STATE_ENDED    -> emitPlaybackState(isPlaying = false)
                        else                  -> Unit
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) startPositionPolling() else stopPositionPolling()
                    emitPlaybackState()
                }

                override fun onPlayerError(error: PlaybackException) {
                    stopPositionPolling()
                    emitError(error.message ?: "ExoPlayer error")
                }
            })

            val mediaItem = MediaItem.fromUri(url)
            exo.setMediaItem(mediaItem)
            exo.prepare()

            // Wait for ready to return duration
            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_READY) {
                        exo.removeListener(this)
                        result.success(mapOf(
                            "durationMs" to exo.duration.coerceAtLeast(0L),
                            "textureId"  to textureId
                        ))
                    }
                }
                override fun onPlayerError(error: PlaybackException) {
                    exo.removeListener(this)
                    result.error("INIT_ERROR", error.message, null)
                }
            })

            player = exo
        }
    }

    // ── Playback controls ──────────────────────────────────────────────────
    private fun play(result: MethodChannel.Result) {
        mainHandler.post {
            player?.play()
            result.success(null)
        }
    }

    private fun pause(result: MethodChannel.Result) {
        mainHandler.post {
            player?.pause()
            result.success(null)
        }
    }

    private fun seekTo(args: Map<*, *>?, result: MethodChannel.Result) {
        val posMs = (args?.get("positionMs") as? Number)?.toLong() ?: 0L
        mainHandler.post {
            player?.seekTo(posMs)
            result.success(null)
        }
    }

    private fun setPlaybackSpeed(args: Map<*, *>?, result: MethodChannel.Result) {
        val speed = (args?.get("speed") as? Double)?.toFloat() ?: 1.0f
        mainHandler.post {
            player?.setPlaybackSpeed(speed)
            result.success(null)
        }
    }

    private fun setLooping(args: Map<*, *>?, result: MethodChannel.Result) {
        val looping = args?.get("looping") as? Boolean ?: false
        mainHandler.post {
            player?.repeatMode = if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            result.success(null)
        }
    }

    // ── Low-latency / Live ─────────────────────────────────────────────────
    fun setLowLatencyMode(targetMs: Int) {
        mainHandler.post {
            player?.let { exo ->
                val params = exo.trackSelectionParameters.buildUpon()
                    .setMaxVideoBitrate(Int.MAX_VALUE)
                    .build()
                exo.trackSelectionParameters = params
                // LiveConfiguration target offset
                if (exo.isCurrentMediaItemLive) {
                    exo.updateCurrentPlaybackLocally(
                        exo.currentPosition,
                        exo.playbackParameters,
                        /* resetToDefaultPosition = */ false
                    )
                }
            }
        }
    }

    fun getLiveLatency(): Long {
        return player?.let { exo ->
            if (exo.isCurrentMediaItemLive) {
                exo.currentLiveOffset
            } else -1L
        } ?: -1L
    }

    // ── Audio tracks ───────────────────────────────────────────────────────
    fun getAudioTracks(): List<Map<String, Any>> {
        val exo = player ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        val tracks = exo.currentTracks
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                result.add(mapOf(
                    "id"       to "${group.hashCode()}_$i",
                    "language" to (format.language ?: "und"),
                    "label"    to (format.label    ?: "Audio ${result.size + 1}"),
                    "selected" to group.isTrackSelected(i)
                ))
            }
        }
        return result
    }

    fun setAudioTrack(trackId: String) {
        val exo      = player ?: return
        val selector = trackSelector ?: return
        val parts    = trackId.split("_")
        if (parts.size < 2) return
        val groupHash = parts[0].toIntOrNull() ?: return
        val trackIdx  = parts[1].toIntOrNull() ?: return

        val tracks = exo.currentTracks
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            if (group.mediaTrackGroup.hashCode() != groupHash) continue
            val override = androidx.media3.common.TrackSelectionOverride(group.mediaTrackGroup, trackIdx)
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setOverrideForType(override)
                .build()
            return
        }
    }

    // ── Event emission ─────────────────────────────────────────────────────
    private fun emitPlaybackState(
        isPlaying: Boolean? = null,
        isBuffering: Boolean = false
    ) {
        val exo  = player ?: return
        val sink = eventSink ?: return
        val actualPlaying = isPlaying ?: exo.isPlaying
        val buffered = buildList {
            for (i in 0 until exo.bufferedPercentage / 10) {
                // Approximate single range from 0 to buffered position
            }
            add(mapOf("start" to 0L, "end" to exo.bufferedPosition))
        }
        mainHandler.post {
            sink.success(mapOf(
                "type"        to "playback",
                "position"    to exo.currentPosition.coerceAtLeast(0L),
                "duration"    to exo.duration.coerceAtLeast(0L),
                "isPlaying"   to actualPlaying,
                "isBuffering" to (exo.playbackState == Player.STATE_BUFFERING || isBuffering),
                "buffered"    to buffered,
                "error"       to null
            ))
        }
    }

    private fun emitError(message: String) {
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(mapOf(
                "type"        to "playback",
                "position"    to 0L,
                "duration"    to 0L,
                "isPlaying"   to false,
                "isBuffering" to false,
                "buffered"    to emptyList<Map<String, Long>>(),
                "error"       to message
            ))
        }
    }

    // ── Position polling ───────────────────────────────────────────────────
    private fun startPositionPolling() {
        stopPositionPolling()
        positionRunnable = object : Runnable {
            override fun run() {
                emitPlaybackState()
                mainHandler.postDelayed(this, positionPollMs)
            }
        }
        mainHandler.postDelayed(positionRunnable!!, positionPollMs)
    }

    private fun stopPositionPolling() {
        positionRunnable?.let { mainHandler.removeCallbacks(it) }
        positionRunnable = null
    }

    // ── Dispose ────────────────────────────────────────────────────────────
    fun dispose(result: MethodChannel.Result? = null) {
        mainHandler.post {
            releasePlayer()
            textureEntry.release()
            result?.success(null)
        }
    }

    private fun releasePlayer() {
        stopPositionPolling()
        player?.release()
        player = null
        trackSelector = null
    }
}