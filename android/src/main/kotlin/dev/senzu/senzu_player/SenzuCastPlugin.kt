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

class SenzuCastPlugin(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null

    // iOS-той нийцүүлэх cache
    private var loadedSubtitleTracks: List<Map<String, Any?>> = emptyList()
    private var loadedAudioTracks: List<Map<String, Any?>> = emptyList()
    private var lastLoadArgs: Map<String, Any?>? = null

    private val castContext: CastContext by lazy { CastContext.getSharedInstance(context) }
    private val sessionManager: SessionManager
        get() = castContext.sessionManager

    private val castSession: CastSession?
        get() = sessionManager.currentCastSession

    companion object {
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

                val dm = castContext.discoveryManager
                dm.startDiscovery()
                println("SenzuCast: Plugin registered, discovery started")
            } catch (e: Throwable) {
                println("SenzuCast: WARNING - CastContext not initialized: ${e.message}")
            }

            return instance
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>()

        try {
            when (call.method) {
                "discoverDevices" -> discoverDevices(result)
                "connectToDevice" -> connectToDevice(args, result)
                "showDevicePicker" -> {
                    // Android дээр native cast button/dialog ихэвчлэн Flutter UI талаас хийгддэг.
                    // iOS-тэй API parity хадгалахын тулд no-op success буцааж байна.
                    result.success(true)
                }

                "loadMedia" -> loadMedia(args, result)
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
                    val rawIds = (args?.get("trackIds") as? List<*>)?.mapNotNull {
                        (it as? Number)?.toLong()
                    } ?: emptyList()
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
                    val state = if (castSession != null) "connected" else "notConnected"
                    result.success(state)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("CAST_ERROR", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Discovery
    // ─────────────────────────────────────────────────────────────────────────────

    private fun discoverDevices(result: MethodChannel.Result) {
        val dm: DiscoveryManager = castContext.discoveryManager
        dm.startDiscovery()

        if (dm.deviceCount == 0) {
            mainHandler.postDelayed({
                result.success(buildDeviceList(dm))
            }, 1000)
        } else {
            result.success(buildDeviceList(dm))
        }
    }

    private fun connectToDevice(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val deviceId = args?.get("deviceId") as? String ?: ""
        val dm = castContext.discoveryManager

        var found = false
        for (i in 0 until dm.deviceCount) {
            val device = dm.getDeviceAtIndex(i)
            if (device?.deviceId == deviceId) {
                found = true
                sessionManager.startSession(device)
                result.success(null)
                break
            }
        }

        if (!found) {
            result.error("DEVICE_NOT_FOUND", "Device $deviceId not found", null)
        }
    }

    private fun buildDeviceList(dm: DiscoveryManager): List<Map<String, Any?>> {
        val devices = mutableListOf<Map<String, Any?>>()

        for (i in 0 until dm.deviceCount) {
            val d = dm.getDeviceAtIndex(i) ?: continue
            devices += mapOf(
                "deviceId" to d.deviceId,
                "deviceName" to (d.friendlyName ?: "Unknown"),
                "modelName" to (d.modelName ?: ""),
            )
        }

        return devices
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Load media
    // ─────────────────────────────────────────────────────────────────────────────

    private fun loadMedia(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val session = castSession
        val client = session?.remoteMediaClient
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
        val httpHeaders = (args["httpHeaders"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String
            val v = it.value as? String
            if (k != null && v != null) k to v else null
        }?.toMap() ?: emptyMap()

        val subtitleHeaders = (args["subtitleHeaders"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String
            val v = it.value as? String
            if (k != null && v != null) k to v else null
        }?.toMap() ?: emptyMap()

        val selectedSubtitleId = (args["selectedSubtitleId"] as? Number)?.toLong()
        val selectedAudioId = (args["selectedAudioId"] as? Number)?.toLong()

        loadedSubtitleTracks =
            ((args["availableSubtitles"] as? List<*>)?.mapNotNull { it as? Map<String, Any?> })
                ?: emptyList()
        loadedAudioTracks =
            ((args["availableAudioTracks"] as? List<*>)?.mapNotNull { it as? Map<String, Any?> })
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
            val track = buildSubtitleTrack(sub, subtitleHeaders)
            if (track != null) {
                tracks += track
                val id = (sub["id"] as? Number)?.toLong()
                if (selectedSubtitleId != null && id == selectedSubtitleId) {
                    activeTrackIds += selectedSubtitleId
                }
                println("SenzuCast: subtitle track id=${track.id}")
            }
        }

        for (audio in loadedAudioTracks) {
            val track = buildAudioTrack(audio)
            if (track != null) {
                tracks += track
                val id = (audio["id"] as? Number)?.toLong()
                if (selectedAudioId != null && id == selectedAudioId) {
                    activeTrackIds += selectedAudioId
                }
                println("SenzuCast: audio track id=${track.id}")
            }
        }

        val customData = JSONObject().apply {
            if (httpHeaders.isNotEmpty()) put("headers", JSONObject(httpHeaders))
            if (releaseDate.isNotEmpty()) put("releaseDate", releaseDate)
            if (studio.isNotEmpty()) put("studio", studio)
        }

        val mediaInfoBuilder = MediaInfo.Builder(url)
            .setStreamType(
                if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED
            )
            .setContentType(mimeType)
            .setMetadata(metadata)

        if (!isLive && durationMs > 0) {
            mediaInfoBuilder.setStreamDuration(durationMs)
        }

        if (tracks.isNotEmpty()) {
            mediaInfoBuilder.setMediaTracks(tracks)
            println("SenzuCast: loadMedia with ${tracks.size} tracks total")
        }

        if (customData.length() > 0) {
            mediaInfoBuilder.setCustomData(customData)
        }

        val mediaInfo = mediaInfoBuilder.build()
        val optionsBuilder = MediaLoadOptions.Builder()
            .setAutoplay(true)
            .setPlayPosition(positionMs)

        if (activeTrackIds.isNotEmpty()) {
            optionsBuilder.setActiveTrackIds(activeTrackIds.toLongArray())
        }

        client.load(mediaInfo, optionsBuilder.build())
        result.success(true)
    }

    private fun loadQuality(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val session = castSession
        val client = session?.remoteMediaClient
        val url = args?.get("url") as? String

        if (session == null || client == null || url.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val isLive = args["isLive"] as? Boolean ?: false
        val headers = (args["headers"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String
            val v = it.value as? String
            if (k != null && v != null) k to v else null
        }?.toMap() ?: emptyMap()

        val currentInfo = client.mediaInfo
        val activeIds = client.mediaStatus?.activeTrackIds?.toList() ?: emptyList()

        val builder = MediaInfo.Builder(url)
            .setContentType(currentInfo?.contentType ?: "application/x-mpegURL")
            .setMetadata(currentInfo?.metadata)
            .setStreamType(
                if (isLive) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED
            )

        if (!isLive && durationMs > 0) {
            builder.setStreamDuration(durationMs)
        } else if (!isLive && currentInfo != null && currentInfo.streamDuration > 0) {
            builder.setStreamDuration(currentInfo.streamDuration)
        }

        val existingTracks = currentInfo?.mediaTracks
        if (!existingTracks.isNullOrEmpty()) {
            builder.setMediaTracks(existingTracks)
            println("SenzuCast: loadQuality — carried over ${existingTracks.size} tracks")
        } else {
            val rebuiltTracks = mutableListOf<MediaTrack>()
            loadedSubtitleTracks.forEach { sub ->
                buildSubtitleTrack(sub, emptyMap())?.let { rebuiltTracks += it }
            }
            loadedAudioTracks.forEach { audio ->
                buildAudioTrack(audio)?.let { rebuiltTracks += it }
            }
            if (rebuiltTracks.isNotEmpty()) {
                builder.setMediaTracks(rebuiltTracks)
                println("SenzuCast: loadQuality — rebuilt ${rebuiltTracks.size} tracks from cache")
            }
        }

        if (headers.isNotEmpty()) {
            builder.setCustomData(JSONObject().put("headers", JSONObject(headers)))
        }

        val mediaInfo = builder.build()

        val request = client.load(
            mediaInfo,
            MediaLoadOptions.Builder()
                .setAutoplay(true)
                .setPlayPosition(positionMs)
                .build()
        )

        request.setResultCallback { status ->
            if (status.isSuccess && activeIds.isNotEmpty()) {
                mainHandler.postDelayed({
                    client.setActiveMediaTracks(activeIds.toLongArray())
                    println("SenzuCast: loadQuality — restored active tracks: $activeIds")
                }, 500)
            }
        }

        result.success(true)
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Track helpers
    // ─────────────────────────────────────────────────────────────────────────────

    private fun buildSubtitleTrack(
        sub: Map<String, Any?>,
        defaultHeaders: Map<String, String>,
    ): MediaTrack? {
        val trackId = (sub["id"] as? Number)?.toLong() ?: return null
        val subUrl = sub["url"] as? String ?: return null
        val lang = sub["language"] as? String ?: "en"
        val name = sub["name"] as? String ?: "Subtitle"

        val perSubHeaders = (sub["headers"] as? Map<*, *>)?.mapNotNull {
            val k = it.key as? String
            val v = it.value as? String
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

    private fun buildAudioTrack(audio: Map<String, Any?>): MediaTrack? {
        val trackId = (audio["id"] as? Number)?.toLong() ?: return null
        val lang = audio["language"] as? String ?: "und"
        val name = audio["name"] as? String ?: "Audio"

        return MediaTrack.Builder(trackId, MediaTrack.TYPE_AUDIO)
            .setLanguage(lang)
            .setName(name)
            .build()
    }

    private fun currentActiveTrackIds(): List<Long> {
        return castSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toList() ?: emptyList()
    }

    private fun currentActiveAudioIds(): List<Long> {
        val audioIds = loadedAudioTracks.mapNotNull { (it["id"] as? Number)?.toLong() }.toSet()
        return currentActiveTrackIds().filter { it in audioIds }
    }

    private fun currentActiveSubtitleIds(): List<Long> {
        val subtitleIds = loadedSubtitleTracks.mapNotNull { (it["id"] as? Number)?.toLong() }.toSet()
        return currentActiveTrackIds().filter { it in subtitleIds }
    }

    private fun setActiveTracks(trackIds: List<Long>) {
        val client = castSession?.remoteMediaClient ?: return
        client.setActiveMediaTracks(trackIds.toLongArray())
        println("SenzuCast: setActiveTracks -> $trackIds")
    }

    private fun setSubtitleTrack(trackId: Long) {
        if (trackId < 0) return
        val client = castSession?.remoteMediaClient ?: return

        val ids = mutableListOf<Long>()
        ids += trackId
        ids += currentActiveAudioIds()

        client.setActiveMediaTracks(ids.toLongArray())
        println("SenzuCast: setSubtitleTrack $trackId, activeIds=$ids")
    }

    private fun setAudioTrack(trackId: Long) {
        if (trackId < 0) return
        val client = castSession?.remoteMediaClient ?: return

        val ids = mutableListOf<Long>()
        ids += trackId
        ids += currentActiveSubtitleIds()

        client.setActiveMediaTracks(ids.toLongArray())
        println("SenzuCast: setAudioTrack $trackId, activeIds=$ids")
    }

    private fun disableSubtitles() {
        val client = castSession?.remoteMediaClient ?: return
        val audioIds = currentActiveAudioIds()
        client.setActiveMediaTracks(audioIds.toLongArray())
        println("SenzuCast: disableSubtitles, keeping audio tracks: $audioIds")
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Event channel
    // ─────────────────────────────────────────────────────────────────────────────

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

    private fun emitCastState(state: String) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "type" to "castState",
                    "state" to state,
                )
            )
        }
    }

    private fun emitDevices() {
        val devices = buildDeviceList(castContext.discoveryManager)
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "type" to "devices",
                    "devices" to devices,
                )
            )
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
            "activeTrackIds" to (status.activeTrackIds?.map { it.toInt() } ?: emptyList<Int>()),
        )

        mainHandler.post {
            eventSink?.success(info)
        }
    }

    private fun startPolling() {
        stopPolling()

        pollingRunnable = object : Runnable {
            override fun run() {
                emitRemoteState()
                mainHandler.postDelayed(this, 200)
            }
        }

        pollingRunnable?.let { mainHandler.post(it) }
    }

    private fun stopPolling() {
        pollingRunnable?.let { mainHandler.removeCallbacks(it) }
        pollingRunnable = null
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Session listener
    // ─────────────────────────────────────────────────────────────────────────────

    private val thisListener = this

    init {
        // discovery event-үүдийг polling/device refresh-р нөхөж байна
    }

    @Suppress("OVERRIDE_DEPRECATION")
    private fun clearTrackCache() {
        loadedSubtitleTracks = emptyList()
        loadedAudioTracks = emptyList()
        lastLoadArgs = null
    }

    // SessionManagerListener<Session>
    override fun onSessionStarting(session: Session) {
        println("SenzuCast: session will start")
        emitCastState("connecting")
    }

    override fun onSessionStarted(session: Session, sessionId: String) {
        println("SenzuCast: session started")
        emitCastState("connected")
        emitDevices()
        startPolling()
    }

    override fun onSessionStartFailed(session: Session, error: Int) {
        println("SenzuCast: session failed to start, error=$error")
        emitCastState("notConnected")
    }

    override fun onSessionResuming(session: Session, sessionId: String) {
        println("SenzuCast: session resuming")
        emitCastState("connecting")
    }

    override fun onSessionResumed(session: Session, wasSuspended: Boolean) {
        println("SenzuCast: session resumed")
        emitCastState("connected")
        startPolling()
    }

    override fun onSessionResumeFailed(session: Session, error: Int) {
        println("SenzuCast: session resume failed, error=$error")
        emitCastState("notConnected")
    }

    override fun onSessionEnding(session: Session) {}

    override fun onSessionEnded(session: Session, error: Int) {
        println("SenzuCast: session ended, error=$error")
        clearTrackCache()
        emitCastState("notConnected")
        stopPolling()
    }

    override fun onSessionSuspended(session: Session, reason: Int) {
        println("SenzuCast: session suspended, reason=$reason")
        emitCastState("notConnected")
        stopPolling()
    }
}