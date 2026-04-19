package dev.senzu.senzu_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadOptions
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.DiscoveryManager
import com.google.android.gms.cast.framework.Session
import com.google.android.gms.cast.framework.SessionManager
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// ─────────────────────────────────────────────────────────────────────────────
// SenzuCastPlugin (Android)
// Bridges the Flutter Cast API to the Google Cast SDK on Android.
// Handles device discovery, session management, media loading, track
// selection, and emits cast/remote-state events to Flutter.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Android implementation of the Senzu Cast plugin.
 *
 * Implements both [MethodChannel.MethodCallHandler] and [EventChannel.StreamHandler]
 * as well as [SessionManagerListener] to mirror the iOS GCKSessionManagerListener.
 *
 * @param context        Application context.
 * @param methodChannel  Flutter method channel (`senzu_player/cast`).
 * @param eventChannel   Flutter event channel (`senzu_player/cast_events`).
 */
class SenzuCastPlugin(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    // ── Internal state ─────────────────────────────────────────────────────

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null

    // Track cache for quality-switch and track-selection continuity
    private var loadedSubtitleTracks: List<Map<String, Any?>> = emptyList()
    private var loadedAudioTracks: List<Map<String, Any?>> = emptyList()
    private var lastLoadArgs: Map<String, Any?>? = null

    // ── Cast SDK accessors ─────────────────────────────────────────────────

    private val castContext: CastContext by lazy { CastContext.getSharedInstance(context) }
    private val sessionManager: SessionManager get() = castContext.sessionManager
    private val castSession: CastSession? get() = sessionManager.currentCastSession

    // ── Registration ───────────────────────────────────────────────────────

    companion object {
        /**
         * Creates and registers a [SenzuCastPlugin] instance on both channels,
         * then starts Cast device discovery.
         */
        fun register(
            context: Context,
            methodChannel: MethodChannel,
            eventChannel: EventChannel,
        ): SenzuCastPlugin {
            val instance = SenzuCastPlugin(context, methodChannel, eventChannel)
            methodChannel.setMethodCallHandler(instance)
            eventChannel.setStreamHandler(instance)

            try {
                val castContext = CastContext.getSharedInstance(context)
                castContext.sessionManager.addSessionManagerListener(
                    instance,
                    Session::class.java,
                )
                castContext.discoveryManager.startDiscovery()
                println("SenzuCast: Plugin registered, discovery started")
            } catch (e: Throwable) {
                println("SenzuCast: WARNING - CastContext not initialized: ${e.message}")
            }

            return instance
        }
    }

    // ── MethodChannel handler ──────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>()

        try {
            when (call.method) {
                "discoverDevices"  -> discoverDevices(result)
                "connectToDevice"  -> connectToDevice(args, result)

                // Android uses a native Cast button/dialog managed from Flutter UI.
                // This no-op keeps API parity with iOS showDevicePicker.
                "showDevicePicker" -> result.success(true)

                "loadMedia"        -> loadMedia(args, result)
                "loadQuality"      -> loadQuality(args, result)

                "play"  -> { castSession?.remoteMediaClient?.play();  result.success(null) }
                "pause" -> { castSession?.remoteMediaClient?.pause(); result.success(null) }
                "stop"  -> { castSession?.remoteMediaClient?.stop();  result.success(null) }

                "seekTo" -> {
                    val positionMs = (args?.get("positionMs") as? Number)?.toLong() ?: 0L
                    castSession?.remoteMediaClient?.seek(positionMs)
                    result.success(null)
                }

                "setActiveTracks" -> {
                    val rawIds = (args?.get("trackIds") as? List<*>)
                        ?.mapNotNull { (it as? Number)?.toLong() } ?: emptyList()
                    setActiveTracks(rawIds)
                    result.success(null)
                }

                "setSubtitleTrack" -> {
                    val trackId = (args?.get("trackId") as? Number)?.toLong() ?: -1L
                    setSubtitleTrack(trackId)
                    result.success(null)
                }

                "disableSubtitles" -> {
                    disableSubtitles()
                    result.success(null)
                }

                "setAudioTrack" -> {
                    val trackId = (args?.get("trackId") as? Number)?.toLong() ?: -1L
                    setAudioTrack(trackId)
                    result.success(null)
                }

                "setVolume" -> {
                    val volume = (args?.get("volume") as? Number)?.toDouble() ?: 1.0
                    castSession?.setVolume(volume)
                    emitRemoteState()
                    result.success(null)
                }

                "disconnect" -> {
                    sessionManager.endCurrentSession(true)
                    result.success(null)
                }

                "getCastState" -> {
                    result.success(if (castSession != null) "connected" else "notConnected")
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("CAST_ERROR", e.message, null)
        }
    }

    // ── Device discovery ───────────────────────────────────────────────────

    /**
     * Starts discovery and returns the current device list.
     * Delays 1 second if no devices are found immediately.
     */
    private fun discoverDevices(result: MethodChannel.Result) {
        val dm: DiscoveryManager = castContext.discoveryManager
        dm.startDiscovery()

        if (dm.deviceCount == 0) {
            mainHandler.postDelayed({ result.success(buildDeviceList(dm)) }, 1000)
        } else {
            result.success(buildDeviceList(dm))
        }
    }

    /** Connects to a Cast device by its device ID. */
    private fun connectToDevice(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val deviceId = args?.get("deviceId") as? String ?: ""
        val dm = castContext.discoveryManager

        for (i in 0 until dm.deviceCount) {
            val device = dm.getDeviceAtIndex(i)
            if (device?.deviceId == deviceId) {
                sessionManager.startSession(device)
                result.success(null)
                return
            }
        }

        result.error("DEVICE_NOT_FOUND", "Device $deviceId not found", null)
    }

    /** Converts [DiscoveryManager] results into a list of Flutter-friendly maps. */
    private fun buildDeviceList(dm: DiscoveryManager): List<Map<String, Any?>> =
        (0 until dm.deviceCount).mapNotNull { dm.getDeviceAtIndex(it) }.map { d ->
            mapOf(
                "deviceId"   to d.deviceId,
                "deviceName" to (d.friendlyName ?: "Unknown"),
                "modelName"  to (d.modelName   ?: ""),
            )
        }

    // ── Media loading ──────────────────────────────────────────────────────

    /**
     * Loads a new media item on the Cast receiver with optional subtitle/audio
     * tracks and a starting position.
     */
    private fun loadMedia(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val session = castSession
        val client  = session?.remoteMediaClient
        val url     = args?.get("url") as? String

        if (client == null || url.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val title              = args["title"]       as? String  ?: ""
        val description        = args["description"] as? String  ?: ""
        val posterUrl          = args["posterUrl"]   as? String  ?: ""
        val mimeType           = args["mimeType"]    as? String  ?: "application/x-mpegURL"
        val positionMs         = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val durationMs         = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val isLive             = args["isLive"]      as? Boolean ?: false
        val releaseDate        = args["releaseDate"] as? String  ?: ""
        val studio             = args["studio"]      as? String  ?: ""
        val httpHeaders        = args.toStringMap("httpHeaders")
        val subtitleHeaders    = args.toStringMap("subtitleHeaders")
        val selectedSubtitleId = (args["selectedSubtitleId"] as? Number)?.toLong()
        val selectedAudioId    = (args["selectedAudioId"]    as? Number)?.toLong()

        loadedSubtitleTracks =
            (args["availableSubtitles"]   as? List<*>)?.filterIsInstance<Map<String, Any?>>() ?: emptyList()
        loadedAudioTracks =
            (args["availableAudioTracks"] as? List<*>)?.filterIsInstance<Map<String, Any?>>() ?: emptyList()
        lastLoadArgs = args

        // Build metadata
        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, title)
            if (description.isNotEmpty()) putString(MediaMetadata.KEY_SUBTITLE, description)
            if (studio.isNotEmpty())      putString(MediaMetadata.KEY_STUDIO, studio)
            if (releaseDate.isNotEmpty()) putString(MediaMetadata.KEY_RELEASE_DATE, releaseDate)
            if (posterUrl.isNotEmpty())   addImage(WebImage(android.net.Uri.parse(posterUrl)))
        }

        // Build tracks
        val tracks         = mutableListOf<MediaTrack>()
        val activeTrackIds = mutableListOf<Long>()

        for (sub in loadedSubtitleTracks) {
            buildSubtitleTrack(sub, subtitleHeaders)?.let { track ->
                tracks += track
                val id = (sub["id"] as? Number)?.toLong()
                if (selectedSubtitleId != null && id == selectedSubtitleId) {
                    activeTrackIds += selectedSubtitleId
                }
            }
        }

        for (audio in loadedAudioTracks) {
            buildAudioTrack(audio)?.let { track ->
                tracks += track
                val id = (audio["id"] as? Number)?.toLong()
                if (selectedAudioId != null && id == selectedAudioId) {
                    activeTrackIds += selectedAudioId
                }
            }
        }

        val customData = JSONObject().apply {
            if (httpHeaders.isNotEmpty()) put("headers", JSONObject(httpHeaders))
            if (releaseDate.isNotEmpty()) put("releaseDate", releaseDate)
            if (studio.isNotEmpty())      put("studio", studio)
        }

        val mediaInfoBuilder = MediaInfo.Builder(url)
            .setStreamType(if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(mimeType)
            .setMetadata(metadata)

        if (!isLive && durationMs > 0) mediaInfoBuilder.setStreamDuration(durationMs)
        if (tracks.isNotEmpty())       mediaInfoBuilder.setMediaTracks(tracks)
        if (customData.length() > 0)   mediaInfoBuilder.setCustomData(customData)

        val optionsBuilder = MediaLoadOptions.Builder()
            .setAutoplay(true)
            .setPlayPosition(positionMs)

        if (activeTrackIds.isNotEmpty()) {
            optionsBuilder.setActiveTrackIds(activeTrackIds.toLongArray())
        }

        client.load(mediaInfoBuilder.build(), optionsBuilder.build())
        result.success(true)
    }

    /**
     * Reloads the current media at a new URL (quality switch) while preserving
     * metadata, tracks, and active track selection.
     */
    private fun loadQuality(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val session    = castSession
        val client     = session?.remoteMediaClient
        val url        = args?.get("url") as? String

        if (session == null || client == null || url.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val positionMs = (args["positionMs"] as? Number)?.toLong()  ?: 0L
        val durationMs = (args["durationMs"] as? Number)?.toLong()  ?: 0L
        val isLive     = args["isLive"]      as? Boolean            ?: false
        val headers    = args.toStringMap("headers")

        val currentInfo = client.mediaInfo
        val activeIds   = client.mediaStatus?.activeTrackIds?.toList() ?: emptyList()

        val builder = MediaInfo.Builder(url)
            .setContentType(currentInfo?.contentType ?: "application/x-mpegURL")
            .setMetadata(currentInfo?.metadata)
            .setStreamType(if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)

        if (!isLive && durationMs > 0) {
            builder.setStreamDuration(durationMs)
        } else if (!isLive && (currentInfo?.streamDuration ?: 0) > 0) {
            builder.setStreamDuration(currentInfo!!.streamDuration)
        }

        // Carry over existing tracks, or rebuild from cache
        val existingTracks = currentInfo?.mediaTracks
        if (!existingTracks.isNullOrEmpty()) {
            builder.setMediaTracks(existingTracks)
        } else {
            val rebuiltTracks = mutableListOf<MediaTrack>()
            loadedSubtitleTracks.forEach { buildSubtitleTrack(it, emptyMap())?.let { t -> rebuiltTracks += t } }
            loadedAudioTracks.forEach    { buildAudioTrack(it)?.let            { t -> rebuiltTracks += t } }
            if (rebuiltTracks.isNotEmpty()) builder.setMediaTracks(rebuiltTracks)
        }

        if (headers.isNotEmpty()) {
            builder.setCustomData(JSONObject().put("headers", JSONObject(headers)))
        }

        val request = client.load(
            builder.build(),
            MediaLoadOptions.Builder()
                .setAutoplay(true)
                .setPlayPosition(positionMs)
                .build()
        )

        // Restore active tracks 500ms after load to ensure the receiver is ready
        request.setResultCallback { status ->
            if (status.isSuccess && activeIds.isNotEmpty()) {
                mainHandler.postDelayed({
                    client.setActiveMediaTracks(activeIds.toLongArray())
                }, 500)
            }
        }

        result.success(true)
    }

    // ── Track helpers ──────────────────────────────────────────────────────

    /** Builds a subtitle [MediaTrack] from a Flutter track descriptor map. */
    private fun buildSubtitleTrack(
        sub: Map<String, Any?>,
        defaultHeaders: Map<String, String>,
    ): MediaTrack? {
        val trackId = (sub["id"] as? Number)?.toLong() ?: return null
        val subUrl  = sub["url"] as? String            ?: return null
        val lang    = sub["language"] as? String       ?: "en"
        val name    = sub["name"]     as? String       ?: "Subtitle"

        val perSubHeaders = (sub["headers"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String; val v = it.value as? String
            if (k != null && v != null) k to v else null
        }?.toMap() ?: defaultHeaders

        val builder = MediaTrack.Builder(trackId, MediaTrack.TYPE_TEXT)
            .setContentId(subUrl)
            .setContentType("text/vtt")
            .setSubtype(MediaTrack.SUBTYPE_SUBTITLES)
            .setLanguage(lang)
            .setName(name)

        if (perSubHeaders.isNotEmpty()) {
            builder.setCustomData(JSONObject().put("headers", JSONObject(perSubHeaders)))
        }

        return builder.build()
    }

    /** Builds an audio [MediaTrack] from a Flutter track descriptor map. */
    private fun buildAudioTrack(audio: Map<String, Any?>): MediaTrack? {
        val trackId = (audio["id"]       as? Number)?.toLong() ?: return null
        val lang    = audio["language"]  as? String            ?: "und"
        val name    = audio["name"]      as? String            ?: "Audio"

        return MediaTrack.Builder(trackId, MediaTrack.TYPE_AUDIO)
            .setLanguage(lang)
            .setName(name)
            .build()
    }

    // ── Active track management ────────────────────────────────────────────

    private fun currentActiveTrackIds(): List<Long> =
        castSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toList() ?: emptyList()

    private fun currentActiveAudioIds(): List<Long> {
        val audioIds = loadedAudioTracks.mapNotNull { (it["id"] as? Number)?.toLong() }.toSet()
        return currentActiveTrackIds().filter { it in audioIds }
    }

    private fun currentActiveSubtitleIds(): List<Long> {
        val subtitleIds = loadedSubtitleTracks.mapNotNull { (it["id"] as? Number)?.toLong() }.toSet()
        return currentActiveTrackIds().filter { it in subtitleIds }
    }

    /** Replaces the full active track list with the provided IDs. */
    private fun setActiveTracks(trackIds: List<Long>) {
        castSession?.remoteMediaClient?.setActiveMediaTracks(trackIds.toLongArray())
    }

    /** Activates a subtitle track while preserving the currently active audio track. */
    private fun setSubtitleTrack(trackId: Long) {
        if (trackId < 0) return
        val ids = mutableListOf(trackId) + currentActiveAudioIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(ids.toLongArray())
    }

    /** Activates an audio track while preserving the currently active subtitle track. */
    private fun setAudioTrack(trackId: Long) {
        if (trackId < 0) return
        val ids = mutableListOf(trackId) + currentActiveSubtitleIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(ids.toLongArray())
    }

    /** Deactivates all subtitle tracks while keeping the active audio track. */
    private fun disableSubtitles() {
        val audioIds = currentActiveAudioIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(audioIds.toLongArray())
    }

    // ── EventChannel ──────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        try {
            sessionManager.addSessionManagerListener(this, Session::class.java)
            castContext.discoveryManager.startDiscovery()
        } catch (e: Throwable) {
            println("SenzuCast: onListen error: ${e.message}")
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopPolling()
    }

    // ── Event emission ─────────────────────────────────────────────────────

    private fun emitCastState(state: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "castState", "state" to state))
        }
    }

    private fun emitDevices() {
        val devices = buildDeviceList(castContext.discoveryManager)
        mainHandler.post {
            eventSink?.success(mapOf("type" to "devices", "devices" to devices))
        }
    }

    private fun emitRemoteState() {
        val session = castSession ?: return
        val client  = session.remoteMediaClient ?: return
        val status  = client.mediaStatus ?: return

        val stateStr = when (status.playerState) {
            MediaStatus.PLAYER_STATE_PLAYING   -> "playing"
            MediaStatus.PLAYER_STATE_PAUSED    -> "paused"
            MediaStatus.PLAYER_STATE_BUFFERING -> "buffering"
            MediaStatus.PLAYER_STATE_LOADING   -> "loading"
            else                               -> "idle"
        }

        val info = mapOf(
            "type"           to "remoteState",
            "sessionState"   to stateStr,
            "positionMs"     to client.approximateStreamPosition,
            "durationMs"     to (status.mediaInfo?.streamDuration ?: 0L),
            "isPlaying"      to (status.playerState == MediaStatus.PLAYER_STATE_PLAYING),
            "volume"         to session.volume,
            "isMuted"        to session.isMute,
            "activeTrackIds" to (status.activeTrackIds?.map { it.toInt() } ?: emptyList<Int>()),
        )

        mainHandler.post { eventSink?.success(info) }
    }

    // ── Polling (200ms) ────────────────────────────────────────────────────

    private fun startPolling() {
        stopPolling()
        pollingRunnable = object : Runnable {
            override fun run() {
                emitRemoteState()
                mainHandler.postDelayed(this, 200)
            }
        }
        mainHandler.post(pollingRunnable!!)
    }

    private fun stopPolling() {
        pollingRunnable?.let { mainHandler.removeCallbacks(it) }
        pollingRunnable = null
    }

    // ── Track cache helpers ────────────────────────────────────────────────

    private fun clearTrackCache() {
        loadedSubtitleTracks = emptyList()
        loadedAudioTracks    = emptyList()
        lastLoadArgs         = null
    }

    // ── SessionManagerListener<Session> ───────────────────────────────────

    override fun onSessionStarting(session: Session)                              { emitCastState("connecting") }
    override fun onSessionStarted(session: Session, sessionId: String)            { emitCastState("connected");    emitDevices(); startPolling() }
    override fun onSessionStartFailed(session: Session, error: Int)               { emitCastState("notConnected") }
    override fun onSessionResuming(session: Session, sessionId: String)           { emitCastState("connecting") }
    override fun onSessionResumed(session: Session, wasSuspended: Boolean)        { emitCastState("connected");    startPolling() }
    override fun onSessionResumeFailed(session: Session, error: Int)              { emitCastState("notConnected") }
    override fun onSessionEnding(session: Session)                                {}
    override fun onSessionEnded(session: Session, error: Int)                     { clearTrackCache(); emitCastState("notConnected"); stopPolling() }
    override fun onSessionSuspended(session: Session, reason: Int)                { emitCastState("notConnected"); stopPolling() }

    // ── Cleanup ────────────────────────────────────────────────────────────

    /** Called from [SenzuPlayerPlugin.onDetachedFromEngine]. */
    fun dispose() {
        stopPolling()
        eventSink = null
    }

    // ── Activity binding (forwarded from SenzuPlayerPlugin) ───────────────

    fun setActivity(act: android.app.Activity?) {
        // Reserved for future activity-dependent Cast UI features
    }
}

// ── Extension helpers ──────────────────────────────────────────────────────────

/** Extracts a nested String map from a raw method-channel argument map. */
private fun Map<String, Any?>.toStringMap(key: String): Map<String, String> =
    (this[key] as? Map<*, *>)?.mapNotNull { (k, v) ->
        val ks = k as? String; val vs = v as? String
        if (ks != null && vs != null) ks to vs else null
    }?.toMap() ?: emptyMap()