package dev.senzu.senzu_player

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadOptions
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class SenzuCastPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SessionManagerListener<CastSession> {

    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null

    private var loadedSubtitleTracks: List<Map<String, Any?>> = emptyList()
    private var loadedAudioTracks: List<Map<String, Any?>> = emptyList()
    private var lastLoadArgs: Map<String, Any?>? = null

    private var mediaRouterCallback: MediaRouter.Callback? = null
    private var isRouterCallbackRegistered = false

    private val castContext: CastContext?
        get() = try {
            CastContext.getSharedInstance(context)
        } catch (_: Exception) {
            null
        }

    private val castSession: CastSession?
        get() = castContext?.sessionManager?.currentCastSession

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>()
        val ctx = castContext

        if (ctx == null && call.method !in listOf("getCastState", "discoverDevices", "showDevicePicker")) {
            result.error(
                "NOT_INITIALIZED",
                "Cast not initialized. Call SenzuCastService.initCast() first.",
                null
            )
            return
        }

        try {
            when (call.method) {
                "discoverDevices"  -> discoverDevices(result)
                "connectToDevice"  -> connectToDevice(args, result)

                // Dialog нээхгүй. Discovery эхлүүлээд UI дээр devices event-ээр өгнө.
                "showDevicePicker" -> {
                    startRouteDiscovery()
                    emitDevices()
                    result.success(true)
                }

                "loadMedia"   -> loadMedia(args, result)
                "loadQuality" -> loadQuality(args, result)

                "play" -> {
                    castSession?.remoteMediaClient?.play()
                    result.success(null)
                }

                "pause" -> {
                    castSession?.remoteMediaClient?.pause()
                    result.success(null)
                }

                "stop" -> {
                    castSession?.remoteMediaClient?.stop()
                    result.success(null)
                }

                "seekTo" -> {
                    val positionMs = (args?.get("positionMs") as? Number)?.toLong() ?: 0L
                    castSession?.remoteMediaClient?.seek(positionMs)
                    result.success(null)
                }

                "setActiveTracks" -> {
                    val rawIds = (args?.get("trackIds") as? List<*>)
                        ?.mapNotNull { (it as? Number)?.toLong() }
                        ?: emptyList()
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
                    castSession?.volume = volume
                    emitRemoteState()
                    result.success(null)
                }

                "disconnect" -> {
                    ctx?.sessionManager?.endCurrentSession(true)
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

    private fun discoverDevices(result: MethodChannel.Result) {
        val ctx = castContext
        if (ctx == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            startRouteDiscovery()

            val router = MediaRouter.getInstance(context)
            val devices = buildDeviceListFromRouter(router)
            emitDevices()

            if (devices.isNotEmpty()) {
                result.success(devices)
                return
            }

            mainHandler.postDelayed({
                try {
                    val retryDevices = buildDeviceListFromRouter(router)
                    emitDevices()
                    result.success(retryDevices)
                } catch (_: Exception) {
                    result.success(emptyList<Map<String, Any?>>())
                }
            }, 1200)
        } catch (_: Exception) {
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private fun connectToDevice(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val deviceId = args?.get("deviceId") as? String ?: ""

        if (deviceId.isBlank()) {
            result.error("INVALID_DEVICE_ID", "Device ID is empty", null)
            return
        }

        try {
            startRouteDiscovery()

            val router = MediaRouter.getInstance(context)
            val targetRoute = router.routes.firstOrNull { route ->
                route.id == deviceId || route.name.toString() == deviceId
            }

            if (targetRoute != null) {
                mainHandler.post {
                    try {
                        router.selectRoute(targetRoute)
                        emitDevices()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CAST_CONNECT_ERROR", e.message, null)
                    }
                }
                return
            }

            result.error("DEVICE_NOT_FOUND", "Device $deviceId not found", null)
        } catch (e: Exception) {
            result.error("CAST_ERROR", e.message, null)
        }
    }

    private fun buildRouteSelector(): MediaRouteSelector {
        val appId = SenzuCastOptionsProvider.getAppId()
        return MediaRouteSelector.Builder()
            .addControlCategory(CastMediaControlIntent.categoryForCast(appId))
            .build()
    }

    private fun startRouteDiscovery() {
        val router = MediaRouter.getInstance(context)
        val selector = buildRouteSelector()

        if (mediaRouterCallback == null) {
            mediaRouterCallback = object : MediaRouter.Callback() {
                override fun onRouteAdded(router: MediaRouter, info: MediaRouter.RouteInfo) {
                    emitDevices()
                }

                override fun onRouteRemoved(router: MediaRouter, info: MediaRouter.RouteInfo) {
                    emitDevices()
                }

                override fun onRouteChanged(router: MediaRouter, info: MediaRouter.RouteInfo) {
                    emitDevices()
                }

                override fun onRouteSelected(
                    router: MediaRouter,
                    route: MediaRouter.RouteInfo,
                    reason: Int
                ) {
                    emitDevices()
                }

                override fun onRouteUnselected(
                    router: MediaRouter,
                    route: MediaRouter.RouteInfo,
                    reason: Int
                ) {
                    emitDevices()
                }
            }
        }

        if (!isRouterCallbackRegistered) {
            router.addCallback(
                selector,
                mediaRouterCallback!!,
                MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY
            )
            isRouterCallbackRegistered = true
        }
    }

    private fun stopRouteDiscovery() {
        if (!isRouterCallbackRegistered) return
        val cb = mediaRouterCallback ?: return

        try {
            MediaRouter.getInstance(context).removeCallback(cb)
        } catch (_: Exception) {
        }

        isRouterCallbackRegistered = false
    }

    private fun buildDeviceListFromRouter(router: MediaRouter): List<Map<String, Any?>> {
        val selector = buildRouteSelector()

        return router.routes
            .filter { route ->
                route.matchesSelector(selector) &&
                    !route.isDefault &&
                    route.name?.toString()?.isNotBlank() == true
            }
            .map { route ->
                mapOf(
                    "deviceId" to route.id,
                    "deviceName" to route.name.toString(),
                    "modelName" to (route.description?.toString() ?: "")
                )
            }
            .distinctBy { it["deviceId"] as String }
    }

    private fun loadMedia(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val client = castSession?.remoteMediaClient
        val url = args?.get("url") as? String

        if (client == null || url.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val title = args["title"] as? String ?: ""
        val description = args["description"] as? String ?: ""
        val posterUrl = args["posterUrl"] as? String ?: ""
        val mimeType = args["mimeType"] as? String ?: "application/x-mpegURL"
        val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val isLive = args["isLive"] as? Boolean ?: false
        val releaseDate = args["releaseDate"] as? String ?: ""
        val studio = args["studio"] as? String ?: ""
        val httpHeaders = args.toStringMap("httpHeaders")
        val subtitleHeaders = args.toStringMap("subtitleHeaders")
        val selectedSubId = (args["selectedSubtitleId"] as? Number)?.toLong()
        val selectedAudioId = (args["selectedAudioId"] as? Number)?.toLong()

        loadedSubtitleTracks = (args["availableSubtitles"] as? List<*>)
            ?.filterIsInstance<Map<String, Any?>>()
            ?: emptyList()

        loadedAudioTracks = (args["availableAudioTracks"] as? List<*>)
            ?.filterIsInstance<Map<String, Any?>>()
            ?: emptyList()

        lastLoadArgs = args

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, title)
            if (description.isNotEmpty()) putString(MediaMetadata.KEY_SUBTITLE, description)
            if (studio.isNotEmpty()) putString(MediaMetadata.KEY_STUDIO, studio)
            if (releaseDate.isNotEmpty()) putString(MediaMetadata.KEY_RELEASE_DATE, releaseDate)
            if (posterUrl.isNotEmpty()) addImage(WebImage(android.net.Uri.parse(posterUrl)))
        }

        val tracks = mutableListOf<MediaTrack>()
        val activeTrackIds = mutableListOf<Long>()

        for (sub in loadedSubtitleTracks) {
            buildSubtitleTrack(sub, subtitleHeaders)?.let { track ->
                tracks += track
                val id = (sub["id"] as? Number)?.toLong()
                if (selectedSubId != null && id == selectedSubId) {
                    activeTrackIds += selectedSubId
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
            if (studio.isNotEmpty()) put("studio", studio)
        }

        val mediaInfoBuilder = MediaInfo.Builder(url)
            .setStreamType(if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(mimeType)
            .setMetadata(metadata)

        if (!isLive && durationMs > 0) mediaInfoBuilder.setStreamDuration(durationMs)
        if (tracks.isNotEmpty()) mediaInfoBuilder.setMediaTracks(tracks)
        if (customData.length() > 0) mediaInfoBuilder.setCustomData(customData)

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
        val url = args?.get("url") as? String
        if (client == null || url.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val isLive = args["isLive"] as? Boolean ?: false
        val headers = args.toStringMap("headers")
        val activeIds = client.mediaStatus?.activeTrackIds?.toList() ?: emptyList()
        val currentInfo = client.mediaInfo

        val builder = MediaInfo.Builder(url)
            .setContentType(currentInfo?.contentType ?: "application/x-mpegURL")
            .setMetadata(currentInfo?.metadata)
            .setStreamType(if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)

        if (!isLive && durationMs > 0) {
            builder.setStreamDuration(durationMs)
        } else if (!isLive && (currentInfo?.streamDuration ?: 0) > 0) {
            builder.setStreamDuration(currentInfo!!.streamDuration)
        }

        if ((currentInfo?.mediaTracks?.isNotEmpty() == true)) {
            builder.setMediaTracks(currentInfo.mediaTracks)
        }

        if (headers.isNotEmpty()) {
            builder.setCustomData(JSONObject().apply {
                put("headers", JSONObject(headers))
            })
        }

        val options = MediaLoadOptions.Builder()
            .setAutoplay(true)
            .setPlayPosition(positionMs)
            .setActiveTrackIds(activeIds.toLongArray())
            .build()

        client.load(builder.build(), options)
        result.success(true)
    }

    private fun buildSubtitleTrack(
        sub: Map<String, Any?>,
        subtitleHeaders: Map<String, String>
    ): MediaTrack? {
        val trackId = (sub["id"] as? Number)?.toLong() ?: return null
        val url = sub["url"] as? String ?: return null
        val lang = sub["language"] as? String ?: "und"
        val name = sub["name"] as? String ?: "Subtitle"

        val builder = MediaTrack.Builder(trackId, MediaTrack.TYPE_TEXT)
            .setSubtype(MediaTrack.SUBTYPE_SUBTITLES)
            .setContentId(url)
            .setContentType("text/vtt")
            .setLanguage(lang)
            .setName(name)

        if (subtitleHeaders.isNotEmpty()) {
            builder.setCustomData(JSONObject().apply {
                put("headers", JSONObject(subtitleHeaders))
            })
        }

        return builder.build()
    }

    private fun buildAudioTrack(audio: Map<String, Any?>): MediaTrack? {
        val trackId = (audio["id"] as? Number)?.toLong() ?: return null
        val lang = audio["language"] as? String ?: "und"
        val name = audio["name"] as? String ?: "Audio"

        return MediaTrack.Builder(trackId, MediaTrack.TYPE_AUDIO)
            .setLanguage(lang)
            .setName(name)
            .build()
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val ctx = castContext ?: run {
            println("SenzuCast: onListen — CastContext not initialized yet. Call initCast() first.")
            return
        }

        try {
            ctx.sessionManager.removeSessionManagerListener(this, CastSession::class.java)
            ctx.sessionManager.addSessionManagerListener(this, CastSession::class.java)
            startRouteDiscovery()
            emitDevices()

            if (ctx.sessionManager.currentCastSession != null) {
                emitCastState("connected")
                startPolling()
            } else {
                emitCastState("notConnected")
            }
        } catch (e: Throwable) {
            println("SenzuCast: onListen error: ${e.message}")
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopPolling()
        try {
            castContext?.sessionManager?.removeSessionManagerListener(this, CastSession::class.java)
        } catch (_: Exception) {
        }
    }

    fun onCastInitialized() {
        val ctx = castContext ?: return
        try {
            ctx.sessionManager.removeSessionManagerListener(this, CastSession::class.java)
            ctx.sessionManager.addSessionManagerListener(this, CastSession::class.java)
            startRouteDiscovery()
            emitDevices()

            if (ctx.sessionManager.currentCastSession != null) {
                emitCastState("connected")
                startPolling()
            }
        } catch (e: Exception) {
            println("SenzuCast: onCastInitialized error: ${e.message}")
        }
    }

    private fun emitCastState(state: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "castState", "state" to state))
        }
    }

    private fun emitDevices() {
        try {
            val router = MediaRouter.getInstance(context)
            val devices = buildDeviceListFromRouter(router)
            mainHandler.post {
                eventSink?.success(mapOf("type" to "devices", "devices" to devices))
            }
        } catch (_: Exception) {
        }
    }

    private fun emitRemoteState() {
        val session = castSession ?: return
        val client = session.remoteMediaClient ?: return
        val status = client.mediaStatus ?: return

        val stateStr = when (status.playerState) {
            MediaStatus.PLAYER_STATE_PLAYING -> "playing"
            MediaStatus.PLAYER_STATE_PAUSED -> "paused"
            MediaStatus.PLAYER_STATE_BUFFERING -> "buffering"
            MediaStatus.PLAYER_STATE_LOADING -> "loading"
            else -> "idle"
        }

        val info = mapOf(
            "type" to "remoteState",
            "sessionState" to stateStr,
            "positionMs" to client.approximateStreamPosition,
            "durationMs" to (status.mediaInfo?.streamDuration ?: 0L),
            "isPlaying" to (status.playerState == MediaStatus.PLAYER_STATE_PLAYING),
            "volume" to session.volume,
            "isMuted" to session.isMute,
            "activeTrackIds" to (status.activeTrackIds?.map { it.toInt() } ?: emptyList<Int>())
        )

        mainHandler.post { eventSink?.success(info) }
    }

    private fun startPolling() {
        stopPolling()
        pollingRunnable = object : Runnable {
            override fun run() {
                emitRemoteState()
                mainHandler.postDelayed(this, 500)
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
        loadedAudioTracks = emptyList()
        lastLoadArgs = null
    }

    override fun onSessionStarting(session: CastSession) {
        emitCastState("connecting")
    }

    override fun onSessionStarted(session: CastSession, sessionId: String) {
        emitCastState("connected")
        emitDevices()
        startPolling()
    }

    override fun onSessionStartFailed(session: CastSession, error: Int) {
        emitCastState("notConnected")
    }

    override fun onSessionResuming(session: CastSession, sessionId: String) {
        emitCastState("connecting")
    }

    override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
        emitCastState("connected")
        emitDevices()
        startPolling()
    }

    override fun onSessionResumeFailed(session: CastSession, error: Int) {
        emitCastState("notConnected")
    }

    override fun onSessionEnding(session: CastSession) {}

    override fun onSessionEnded(session: CastSession, error: Int) {
        clearTrackCache()
        emitCastState("notConnected")
        stopPolling()
    }

    override fun onSessionSuspended(session: CastSession, reason: Int) {
        emitCastState("notConnected")
        stopPolling()
    }

    fun setActivity(act: Activity?) {
        activity = act
    }

    fun dispose() {
        stopPolling()
        stopRouteDiscovery()

        try {
            castContext?.sessionManager?.removeSessionManagerListener(this, CastSession::class.java)
        } catch (_: Exception) {
        }

        eventSink = null
        activity = null
    }
}

private fun Map<String, Any?>.toStringMap(key: String): Map<String, String> =
    (this[key] as? Map<*, *>)?.mapNotNull { (k, v) ->
        val ks = k as? String
        val vs = v as? String
        if (ks != null && vs != null) ks to vs else null
    }?.toMap() ?: emptyMap()