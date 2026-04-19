package dev.senzu.senzu_player

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

// ─────────────────────────────────────────────────────────────────────────────
// SenzuExoPlayerManager
// Central manager for ExoPlayer playback on Android.
// Dispatches Flutter method calls, drives the media session and PiP managers,
// and emits playback events to Flutter via an EventChannel.EventSink.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manages a single [ExoPlayer] instance for the SenzuPlayer Flutter plugin.
 *
 * Responsibilities:
 * - Parsing and handling all playback-related Flutter method calls.
 * - Building the ExoPlayer with optional Widevine DRM.
 * - Coordinating [SenzuMediaSessionManager] and [SenzuPipManager].
 * - Emitting playback state events at 200ms intervals during active playback.
 * - Exposing audio-track selection and live-latency APIs.
 *
 * @param context         Application context.
 * @param messenger       Flutter binary messenger (currently reserved for future use).
 * @param textureRegistry Flutter texture registry (reserved; PlatformView is used instead).
 */
@UnstableApi
class SenzuExoPlayerManager(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry
) {

    // ── Player state ───────────────────────────────────────────────────────

    private var player: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Sub-managers ───────────────────────────────────────────────────────

    private var mediaSessionManager: SenzuMediaSessionManager? = null
    var pipManager: SenzuPipManager? = null

    // ── Position polling ───────────────────────────────────────────────────

    /** Interval between position-update events emitted to Flutter (ms). */
    private val positionPollMs = 200L
    private var positionRunnable: Runnable? = null

    // ── Activity binding ───────────────────────────────────────────────────

    /**
     * Attaches (or detaches) the foreground [Activity].
     * Lazily creates [SenzuPipManager] and [SenzuMediaSessionManager] on first attach.
     */
    fun setActivity(act: Activity?) {
        activity = act
        if (act != null) {
            if (pipManager == null)           pipManager           = SenzuPipManager { activity }
            if (mediaSessionManager == null)  mediaSessionManager  = SenzuMediaSessionManager(context) { activity }
        }
    }

    // ── EventSink ──────────────────────────────────────────────────────────

    /**
     * Sets the Flutter event sink. Propagated to sub-managers so they can
     * emit their own event types (remote commands, PiP state).
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        mediaSessionManager?.setEventSink(sink)
        pipManager?.setEventSink(sink)
    }

    // ── MethodCall dispatcher ──────────────────────────────────────────────

    /**
     * Attempts to handle a Flutter method call.
     * Returns true if the call was handled, false if unknown (caller should try next).
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        val args = call.arguments as? Map<*, *>
        return when (call.method) {
            "initialize"            -> { initialize(args, result);                                    true }
            "play"                  -> { play(result);                                                true }
            "pause"                 -> { pause(result);                                               true }
            "seekTo"                -> { seekTo(args, result);                                        true }
            "setPlaybackSpeed"      -> { setPlaybackSpeed(args, result);                              true }
            "setLooping"            -> { setLooping(args, result);                                    true }
            "dispose"               -> { disposePlayer(result);                                       true }
            "setNowPlayingMetadata" -> { setNowPlayingMetadata(args, result);                         true }
            "setNowPlayingEnabled"  -> { setNowPlayingEnabled(args, result);                          true }
            "isPipSupported"        -> { result.success(pipManager?.isSupported() ?: false);          true }
            "enablePip"             -> { pipManager?.enable();  result.success(null);                 true }
            "disablePip"            -> { pipManager?.disable(); result.success(null);                 true }
            "enterPip"              -> { enterPip(result);                                            true }
            "exitPip"               -> { pipManager?.exit();    result.success(null);                 true }
            "checkDrmSupport"       -> { checkDrmSupport(args, result);                               true }
            else                    -> false
        }
    }

    // ── Initialise ─────────────────────────────────────────────────────────

    /**
     * Builds an [ExoPlayer] with optional Widevine DRM and custom HTTP headers,
     * prepares the media item, and resolves [result] with the content duration
     * once [Player.STATE_READY] is reached.
     *
     * Buffer config: min 15s | max 50s | min-for-play 2.5s | min-for-rebuffer 5s.
     */
    private fun initialize(args: Map<*, *>?, result: MethodChannel.Result) {
        val url = args?.get("url") as? String
            ?: run { result.error("BAD_ARGS", "url required", null); return }

        @Suppress("UNCHECKED_CAST")
        val headers   = (args["headers"] as? Map<String, String>) ?: emptyMap()
        val drmConfig = SenzuWidevineConfig.from(args)

        mainHandler.post {
            releasePlayerInternal()

            val selector = DefaultTrackSelector(context)
            trackSelector = selector

            val dataSourceFactory = DefaultHttpDataSource.Factory()
                .setDefaultRequestProperties(headers)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(15_000)
                .setAllowCrossProtocolRedirects(true)

            val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory).apply {
                if (drmConfig != null) {
                    setDrmSessionManagerProvider { SenzuDrmManager.build(drmConfig) }
                }
            }

            val loadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(15_000, 50_000, 2_500, 5_000)
                .build()

            val exo = ExoPlayer.Builder(context)
                .setTrackSelector(selector)
                .setMediaSourceFactory(mediaSourceFactory)
                .setLoadControl(loadControl)
                .build()

            // Make the surface view aware of this player
            SenzuSurfacePlatformView.currentPlayer = exo

            // Ongoing playback listener
            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    when (state) {
                        Player.STATE_READY     -> emitPlaybackState()
                        Player.STATE_BUFFERING -> emitPlaybackState(isBuffering = true)
                        Player.STATE_ENDED     -> emitPlaybackState(isPlaying = false)
                        else                   -> Unit
                    }
                }
                override fun onIsPlayingChanged(playing: Boolean) {
                    if (playing) startPositionPolling() else stopPositionPolling()
                    emitPlaybackState()
                    syncMediaSession()
                }
                override fun onPlayerError(error: PlaybackException) {
                    stopPositionPolling()
                    emitError(error.message ?: "ExoPlayer error")
                }
            })

            val mediaItem = if (drmConfig != null) {
                SenzuDrmManager.buildMediaItem(url, drmConfig)
            } else {
                MediaItem.fromUri(url)
            }

            exo.setMediaItem(mediaItem)
            exo.prepare()

            // One-shot listener that resolves the Flutter result when ready
            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_READY) {
                        exo.removeListener(this)
                        // textureId omitted — PlatformView is used for rendering
                        result.success(mapOf("durationMs" to exo.duration.coerceAtLeast(0L)))
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
        mainHandler.post { player?.play(); syncMediaSession(); result.success(null) }
    }

    private fun pause(result: MethodChannel.Result) {
        mainHandler.post { player?.pause(); syncMediaSession(); result.success(null) }
    }

    private fun seekTo(args: Map<*, *>?, result: MethodChannel.Result) {
        val posMs = (args?.get("positionMs") as? Number)?.toLong() ?: 0L
        mainHandler.post { player?.seekTo(posMs); syncMediaSession(); result.success(null) }
    }

    private fun setPlaybackSpeed(args: Map<*, *>?, result: MethodChannel.Result) {
        val speed = (args?.get("speed") as? Double)?.toFloat() ?: 1.0f
        mainHandler.post { player?.setPlaybackSpeed(speed); result.success(null) }
    }

    private fun setLooping(args: Map<*, *>?, result: MethodChannel.Result) {
        val looping = args?.get("looping") as? Boolean ?: false
        mainHandler.post {
            player?.repeatMode = if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            result.success(null)
        }
    }

    // ── Now Playing ────────────────────────────────────────────────────────

    private fun setNowPlayingMetadata(args: Map<*, *>?, result: MethodChannel.Result) {
        mediaSessionManager?.setMetadata(args)
        result.success(null)
    }

    private fun setNowPlayingEnabled(args: Map<*, *>?, result: MethodChannel.Result) {
        val enabled = args?.get("enabled") as? Boolean ?: true
        if (enabled) mediaSessionManager?.enable() else mediaSessionManager?.disable()
        result.success(null)
    }

    /** Pushes the current ExoPlayer state to the media session. */
    private fun syncMediaSession() {
        val exo = player ?: return
        mediaSessionManager?.updatePlaybackState(
            posMs   = exo.currentPosition.coerceAtLeast(0L),
            durMs   = exo.duration.coerceAtLeast(0L),
            playing = exo.isPlaying,
            speed   = exo.playbackParameters.speed
        )
    }

    // ── Picture-in-Picture ─────────────────────────────────────────────────

    private fun enterPip(result: MethodChannel.Result) {
        val success = pipManager?.enter() ?: false
        if (success) result.success(null)
        else result.error("PIP_NA", "PiP not supported or not enabled", null)
    }

    // ── DRM ────────────────────────────────────────────────────────────────

    private fun checkDrmSupport(args: Map<*, *>?, result: MethodChannel.Result) {
        val type = args?.get("type") as? String ?: "widevine"
        result.success(
            when (type.lowercase()) {
                "widevine" -> SenzuDrmManager.isWidevineSupported()
                else       -> false
            }
        )
    }

    // ── Low-latency / Live ─────────────────────────────────────────────────

    /**
     * Adjusts the live target offset for the current media item.
     * No-op if the current item is not a live stream.
     */
    fun setLowLatencyMode(targetMs: Int) {
        mainHandler.post {
            player?.let { exo ->
                if (!exo.isCurrentMediaItemLive) return@let
                val item = exo.currentMediaItem ?: return@let
                exo.replaceMediaItem(
                    exo.currentMediaItemIndex,
                    item.buildUpon()
                        .setLiveConfiguration(
                            MediaItem.LiveConfiguration.Builder()
                                .setTargetOffsetMs(targetMs.toLong())
                                .setMinOffsetMs(500L)
                                .setMaxOffsetMs(targetMs.toLong() * 2)
                                .build()
                        )
                        .build()
                )
            }
        }
    }

    /** Returns the current live offset in milliseconds, or -1 if not a live stream. */
    fun getLiveLatency(): Long =
        player?.let { if (it.isCurrentMediaItemLive) it.currentLiveOffset else -1L } ?: -1L

    // ── Audio tracks ───────────────────────────────────────────────────────

    /**
     * Returns a list of available audio tracks with id, language, label,
     * and selected state. The track ID encodes group hash + track index for
     * deterministic selection via [setAudioTrack].
     */
    fun getAudioTracks(): List<Map<String, Any>> {
        val exo = player ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        for (group in exo.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                result += mapOf(
                    "id"       to "${group.mediaTrackGroup.hashCode()}_$i",
                    "language" to (format.language ?: "und"),
                    "label"    to (format.label    ?: "Audio ${result.size + 1}"),
                    "selected" to group.isTrackSelected(i)
                )
            }
        }
        return result
    }

    /**
     * Selects an audio track by the ID returned from [getAudioTracks].
     * The ID format is `{groupHash}_{trackIndex}`.
     */
    fun setAudioTrack(trackId: String) {
        val exo      = player       ?: return
        val selector = trackSelector ?: return
        val parts    = trackId.split("_")
        if (parts.size < 2) return
        val groupHash = parts[0].toIntOrNull() ?: return
        val trackIdx  = parts[1].toIntOrNull() ?: return

        for (group in exo.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            if (group.mediaTrackGroup.hashCode() != groupHash) continue
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setOverrideForType(
                    androidx.media3.common.TrackSelectionOverride(group.mediaTrackGroup, trackIdx)
                )
                .build()
            return
        }
    }

    // ── Event emission ─────────────────────────────────────────────────────

    /**
     * Emits a `playback` event to Flutter.
     * [isPlaying] defaults to [ExoPlayer.isPlaying] when null.
     */
    private fun emitPlaybackState(
        isPlaying: Boolean? = null,
        isBuffering: Boolean = false
    ) {
        val exo  = player    ?: return
        val sink = eventSink ?: return
        val actualPlaying = isPlaying ?: exo.isPlaying
        val buffered = listOf(mapOf("start" to 0L, "end" to exo.bufferedPosition))

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
                syncMediaSession()
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

    /** Disposes the current player and resolves the Flutter result. */
    fun disposePlayer(result: MethodChannel.Result? = null) {
        mainHandler.post { releasePlayerInternal(); result?.success(null) }
    }

    /** Full teardown called from [SenzuPlayerPlugin.onDetachedFromEngine]. */
    fun dispose() {
        mainHandler.post {
            mediaSessionManager?.teardown()
            releasePlayerInternal()
        }
    }

    private fun releasePlayerInternal() {
        stopPositionPolling()
        mediaSessionManager?.teardown()
        player?.release()
        player        = null
        trackSelector = null
    }
}