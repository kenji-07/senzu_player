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
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class SenzuCastPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    SessionManagerListener<CastSession> {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null

    private var loadedSubtitleTracks: List<Map<String, Any?>> = emptyList()
    private var loadedAudioTracks: List<Map<String, Any?>> = emptyList()
    private var lastLoadArgs: Map<String, Any?>? = null

    private val castContext: CastContext by lazy { CastContext.getSharedInstance(context) }
    private val castSession: CastSession?
        get() = castContext.sessionManager.currentCastSession

    // ── MethodChannel ──────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>()
        try {
            when (call.method) {
                "discoverDevices"  -> discoverDevices(result)
                "connectToDevice"  -> connectToDevice(args, result)
                "showDevicePicker" -> result.success(true)
                "loadMedia"        -> loadMedia(args, result)
                "loadQuality"      -> loadQuality(args, result)
                "play"   -> { castSession?.remoteMediaClient?.play();  result.success(null) }
                "pause"  -> { castSession?.remoteMediaClient?.pause(); result.success(null) }
                "stop"   -> { castSession?.remoteMediaClient?.stop();  result.success(null) }
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
                "disableSubtitles" -> { disableSubtitles(); result.success(null) }
                "setAudioTrack" -> {
                    val trackId = (args?.get("trackId") as? Number)?.toLong() ?: -1L
                    setAudioTrack(trackId)
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = (args?.get("volume") as? Number)?.toDouble() ?: 1.0
                    castSession?.volume = volume
                    emitRemoteState()
                    result.success(null)
                }
                "disconnect" -> {
                    castContext.sessionManager.endCurrentSession(true)
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

    // ── Discovery ──────────────────────────────────────────────────────────

    private fun discoverDevices(result: MethodChannel.Result) {
        try {
            val router = androidx.mediarouter.media.MediaRouter.getInstance(context)
            val devices = buildDeviceListFromRouter(router)
            if (devices.isEmpty()) {
                mainHandler.postDelayed({
                    result.success(buildDeviceListFromRouter(router))
                }, 1000)
            } else {
                result.success(devices)
            }
        } catch (e: Exception) {
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private fun connectToDevice(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val deviceId = args?.get("deviceId") as? String ?: ""
        try {
            val router = androidx.mediarouter.media.MediaRouter.getInstance(context)
            for (route in router.routes) {
                if (route.id == deviceId) {
                    router.selectRoute(route)
                    result.success(null)
                    return
                }
            }
            result.error("DEVICE_NOT_FOUND", "Device $deviceId not found", null)
        } catch (e: Exception) {
            result.error("CAST_ERROR", e.message, null)
        }
    }

    private fun buildDeviceListFromRouter(
    router: androidx.mediarouter.media.MediaRouter
): List<Map<String, Any?>> {
    val appId = "519C9F80" // SenzuCastOptionsProvider-тай таарах appId
    val selector = androidx.mediarouter.media.MediaRouteSelector.Builder()
        .addControlCategory(
            com.google.android.gms.cast.CastMediaControlIntent.categoryForCast(appId)
        )
        .build()
    return router.routes
        .filter { route ->
            route.matchesSelector(selector) &&
            route.id != "DEFAULT_ROUTE_ID" &&
            !route.isDefault
        }
        .map { route ->
            mapOf(
                "deviceId"   to route.id,
                "deviceName" to route.name,
                "modelName"  to (route.description ?: ""),
            )
        }
}

    // ── Media loading ──────────────────────────────────────────────────────

    private fun loadMedia(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val client = castSession?.remoteMediaClient
        val url    = args?.get("url") as? String
        if (client == null || url.isNullOrEmpty()) { result.success(false); return }

        val title           = args["title"]       as? String  ?: ""
        val description     = args["description"] as? String  ?: ""
        val posterUrl       = args["posterUrl"]   as? String  ?: ""
        val mimeType        = args["mimeType"]    as? String  ?: "application/x-mpegURL"
        val positionMs      = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val durationMs      = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val isLive          = args["isLive"]      as? Boolean ?: false
        val releaseDate     = args["releaseDate"] as? String  ?: ""
        val studio          = args["studio"]      as? String  ?: ""
        val httpHeaders     = args.toStringMap("httpHeaders")
        val subtitleHeaders = args.toStringMap("subtitleHeaders")
        val selectedSubId   = (args["selectedSubtitleId"] as? Number)?.toLong()
        val selectedAudioId = (args["selectedAudioId"]    as? Number)?.toLong()

        loadedSubtitleTracks = (args["availableSubtitles"]   as? List<*>)
            ?.filterIsInstance<Map<String, Any?>>() ?: emptyList()
        loadedAudioTracks    = (args["availableAudioTracks"] as? List<*>)
            ?.filterIsInstance<Map<String, Any?>>() ?: emptyList()
        lastLoadArgs = args

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, title)
            if (description.isNotEmpty()) putString(MediaMetadata.KEY_SUBTITLE, description)
            if (studio.isNotEmpty())      putString(MediaMetadata.KEY_STUDIO, studio)
            if (releaseDate.isNotEmpty()) putString(MediaMetadata.KEY_RELEASE_DATE, releaseDate)
            if (posterUrl.isNotEmpty())   addImage(WebImage(android.net.Uri.parse(posterUrl)))
        }

        val tracks         = mutableListOf<MediaTrack>()
        val activeTrackIds = mutableListOf<Long>()

        for (sub in loadedSubtitleTracks) {
            buildSubtitleTrack(sub, subtitleHeaders)?.let { track ->
                tracks += track
                val id = (sub["id"] as? Number)?.toLong()
                if (selectedSubId != null && id == selectedSubId) activeTrackIds += selectedSubId
            }
        }
        for (audio in loadedAudioTracks) {
            buildAudioTrack(audio)?.let { track ->
                tracks += track
                val id = (audio["id"] as? Number)?.toLong()
                if (selectedAudioId != null && id == selectedAudioId) activeTrackIds += selectedAudioId
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

    private fun loadQuality(args: Map<String, Any?>?, result: MethodChannel.Result) {
    val client = castSession?.remoteMediaClient
    val url    = args?.get("url") as? String
    if (client == null || url.isNullOrEmpty()) { result.success(false); return }

    val positionMs  = (args["positionMs"] as? Number)?.toLong() ?: 0L
    val durationMs  = (args["durationMs"] as? Number)?.toLong() ?: 0L
    val isLive      = args["isLive"]      as? Boolean ?: false
    val headers     = args.toStringMap("headers")
    val activeIds   = client.mediaStatus?.activeTrackIds?.toList() ?: emptyList()
    val currentInfo = client.mediaInfo

    val builder = MediaInfo.Builder(url)
        .setContentType(currentInfo?.contentType ?: "application/x-mpegURL")
        .setMetadata(currentInfo?.metadata)
        .setStreamType(if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)

    if (!isLive && durationMs > 0) builder.setStreamDuration(durationMs)
    else if (!isLive && (currentInfo?.streamDuration ?: 0) > 0)
        builder.setStreamDuration(currentInfo!!.streamDuration)

    val existingTracks = currentInfo?.mediaTracks
    if (!existingTracks.isNullOrEmpty()) builder.setMediaTracks(existingTracks)

    if (headers.isNotEmpty()) {
        builder.setCustomData(JSONObject().put("headers", JSONObject(headers)))
    }

    val pendingResult = client.load(
        builder.build(),
        MediaLoadOptions.Builder().setAutoplay(true).setPlayPosition(positionMs).build()
    )

    // isSuccess → setResultCallback дотор RemoteMediaClient.MediaChannelResult ашиглана
    if (activeIds.isNotEmpty()) {
        pendingResult.setResultCallback { mediaChannelResult ->
            if (mediaChannelResult.status.isSuccess && activeIds.isNotEmpty()) {
                mainHandler.postDelayed({
                    client.setActiveMediaTracks(activeIds.toLongArray())
                }, 500)
            }
        }
    }

    result.success(true)
}

    // ── Track helpers ──────────────────────────────────────────────────────

    private fun buildSubtitleTrack(sub: Map<String, Any?>, defaultHeaders: Map<String, String>): MediaTrack? {
        val trackId = (sub["id"]  as? Number)?.toLong() ?: return null
        val subUrl  = sub["url"]  as? String            ?: return null
        val lang    = sub["language"] as? String        ?: "en"
        val name    = sub["name"]     as? String        ?: "Subtitle"
        val perSubHeaders = (sub["headers"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String; val v = it.value as? String
            if (k != null && v != null) k to v else null
        }?.toMap() ?: defaultHeaders

        val builder = MediaTrack.Builder(trackId, MediaTrack.TYPE_TEXT)
            .setContentId(subUrl).setContentType("text/vtt")
            .setSubtype(MediaTrack.SUBTYPE_SUBTITLES).setLanguage(lang).setName(name)
        if (perSubHeaders.isNotEmpty())
            builder.setCustomData(JSONObject().put("headers", JSONObject(perSubHeaders)))
        return builder.build()
    }

    private fun buildAudioTrack(audio: Map<String, Any?>): MediaTrack? {
        val trackId = (audio["id"]      as? Number)?.toLong() ?: return null
        val lang    = audio["language"] as? String            ?: "und"
        val name    = audio["name"]     as? String            ?: "Audio"
        return MediaTrack.Builder(trackId, MediaTrack.TYPE_AUDIO)
            .setLanguage(lang).setName(name).build()
    }

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

    private fun setActiveTracks(trackIds: List<Long>) {
        castSession?.remoteMediaClient?.setActiveMediaTracks(trackIds.toLongArray())
    }

    private fun setSubtitleTrack(trackId: Long) {
        if (trackId < 0) return
        val ids = mutableListOf(trackId) + currentActiveAudioIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(ids.toLongArray())
    }

    private fun setAudioTrack(trackId: Long) {
        if (trackId < 0) return
        val ids = mutableListOf(trackId) + currentActiveSubtitleIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(ids.toLongArray())
    }

    private fun disableSubtitles() {
        val audioIds = currentActiveAudioIds()
        castSession?.remoteMediaClient?.setActiveMediaTracks(audioIds.toLongArray())
    }

    // ── EventChannel ──────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        try {
            castContext.sessionManager.addSessionManagerListener(this, CastSession::class.java)
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
        mainHandler.post { eventSink?.success(mapOf("type" to "castState", "state" to state)) }
    }

    private fun emitDevices() {
        try {
            val router  = androidx.mediarouter.media.MediaRouter.getInstance(context)
            val devices = buildDeviceListFromRouter(router)
            mainHandler.post { eventSink?.success(mapOf("type" to "devices", "devices" to devices)) }
        } catch (_: Exception) {}
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

    // ── Polling ────────────────────────────────────────────────────────────

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

    private fun clearTrackCache() {
        loadedSubtitleTracks = emptyList()
        loadedAudioTracks    = emptyList()
        lastLoadArgs         = null
    }

    // ── SessionManagerListener<CastSession> ───────────────────────────────

    override fun onSessionStarting(session: CastSession)                              { emitCastState("connecting") }
    override fun onSessionStarted(session: CastSession, sessionId: String)            { emitCastState("connected");    emitDevices(); startPolling() }
    override fun onSessionStartFailed(session: CastSession, error: Int)               { emitCastState("notConnected") }
    override fun onSessionResuming(session: CastSession, sessionId: String)           { emitCastState("connecting") }
    override fun onSessionResumed(session: CastSession, wasSuspended: Boolean)        { emitCastState("connected");    startPolling() }
    override fun onSessionResumeFailed(session: CastSession, error: Int)              { emitCastState("notConnected") }
    override fun onSessionEnding(session: CastSession)                                {}
    override fun onSessionEnded(session: CastSession, error: Int)                     { clearTrackCache(); emitCastState("notConnected"); stopPolling() }
    override fun onSessionSuspended(session: CastSession, reason: Int)                { emitCastState("notConnected"); stopPolling() }

    // ── Cleanup ────────────────────────────────────────────────────────────

    fun dispose() {
        stopPolling()
        try {
            castContext.sessionManager.removeSessionManagerListener(this, CastSession::class.java)
        } catch (_: Exception) {}
        eventSink = null
    }

    fun setActivity(act: android.app.Activity?) { /* reserved */ }
}

private fun Map<String, Any?>.toStringMap(key: String): Map<String, String> =
    (this[key] as? Map<*, *>)?.mapNotNull { (k, v) ->
        val ks = k as? String; val vs = v as? String
        if (ks != null && vs != null) ks to vs else null
    }?.toMap() ?: emptyMap()