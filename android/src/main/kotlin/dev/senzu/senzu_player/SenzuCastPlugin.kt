package dev.senzu.senzu_player

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.fragment.app.FragmentActivity
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SenzuCastPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Activity reference — setActivity() via plugin binding
    private var activity: Activity? = null

    private var castContext: CastContext? = null
    private var currentSession: CastSession? = null
    private var pollingRunnable: Runnable? = null
    private var initialized = false

    // ── Activity binding ──────────────────────────────────────────────────
    fun setActivity(act: Activity?) {
        activity = act
        if (act != null && !initialized) {
            initCast()
        }
    }

    // ── CastContext init — main thread шаардлагатай ───────────────────────
    private fun initCast() {
        mainHandler.post {
            try {
                val cc = CastContext.getSharedInstance(context)
                castContext = cc
                initialized = true

                // Одоо хүчинтэй session байвал авна
                val existing = cc.sessionManager.currentCastSession
                if (existing != null) {
                    currentSession = existing
                    emitCastState("connected")
                    startPolling()
                }

                cc.sessionManager.addSessionManagerListener(
                    sessionListener, CastSession::class.java
                )
            } catch (e: Exception) {
                android.util.Log.w("SenzuCast", "Cast init skipped: ${e.message}")
                // Cast SDK байхгүй эсвэл Google Play Services дэмжихгүй
            }
        }
    }

    // ── Session Listener ──────────────────────────────────────────────────
    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) {
            currentSession = session
            emitCastState("connected")
            startPolling()
        }
        override fun onSessionEnded(session: CastSession, error: Int) {
            currentSession = null
            stopPolling()
            emitCastState("notConnected")
        }
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
            currentSession = session
            emitCastState("connected")
            startPolling()
        }
        override fun onSessionStarting(session: CastSession) {
            emitCastState("connecting")
        }
        override fun onSessionStartFailed(session: CastSession, error: Int) {
            emitCastState("notConnected")
        }
        override fun onSessionEnding(session: CastSession) {}
        override fun onSessionResuming(session: CastSession, sessionId: String) {}
        override fun onSessionResumeFailed(session: CastSession, error: Int) {}
        override fun onSessionSuspended(session: CastSession, reason: Int) {}
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Cast SDK инициализ болоогүй бол зарим command-г gracefully handle хийнэ
        when (call.method) {
            "showDevicePicker" -> showDevicePicker(result)
            "loadMedia"        -> loadMedia(call.arguments as? Map<*, *>, result)
            "play"             -> { currentSession?.remoteMediaClient?.play();  result.success(null) }
            "pause"            -> { currentSession?.remoteMediaClient?.pause(); result.success(null) }
            "stop"             -> { currentSession?.remoteMediaClient?.stop();  result.success(null) }
            "seekTo"           -> {
                val posMs = (call.arguments as? Map<*, *>)?.get("positionMs") as? Int ?: 0
                currentSession?.remoteMediaClient?.seek(
                    RemoteMediaClient.SeekOptions.Builder()
                        .setPosition(posMs.toLong())
                        .build()
                )
                result.success(null)
            }
            "disconnect" -> {
                mainHandler.post {
                    castContext?.sessionManager?.endCurrentSession(true)
                }
                result.success(null)
            }
            "getCastState" -> {
                val state = if (currentSession != null) "connected" else "notConnected"
                result.success(state)
            }
            else -> result.notImplemented()
        }
    }

    // ── Device Picker ─────────────────────────────────────────────────────
    private fun showDevicePicker(result: MethodChannel.Result) {
        mainHandler.post {
            val act = activity
            if (act == null) {
                result.error("NO_ACTIVITY", "Activity not available", null)
                return@post
            }
            try {
                val cc = castContext ?: run {
                    // Lazy init хийнэ
                    CastContext.getSharedInstance(context).also {
                        castContext = it
                        initialized = true
                        it.sessionManager.addSessionManagerListener(
                            sessionListener, CastSession::class.java
                        )
                    }
                }

                if (act is FragmentActivity) {
                    // MediaRouteChooserDialog нь FragmentActivity шаардана
                    val dialog = androidx.mediarouter.app.MediaRouteChooserDialogFragment()
                    dialog.routeSelector = cc.mergedSelector ?: run {
                        result.error("NO_SELECTOR", "Cast selector not ready", null)
                        return@post
                    }
                    dialog.show(act.supportFragmentManager, "SenzuCastPicker")
                    result.success(null)
                } else {
                    // Fallback: system cast dialog
                    cc.sessionManager.startSession(act, null)
                    result.success(null)
                }
            } catch (e: Exception) {
                result.error("CAST_ERROR", e.message, null)
            }
        }
    }

    // ── Load Media ────────────────────────────────────────────────────────
    private fun loadMedia(args: Map<*, *>?, result: MethodChannel.Result) {
        val session = currentSession
        if (session == null) {
            result.error("NO_SESSION", "Cast session not connected", null)
            return
        }

        val url          = args?.get("url")            as? String ?: run { result.success(false); return }
        val title        = args["title"]                as? String ?: ""
        val description  = args["description"]          as? String ?: ""
        val mimeType     = args["mimeType"]             as? String ?: resolveMime(url)
        val positionMs   = ((args["positionMs"]         as? Number)?.toLong()) ?: 0L
        val subtitleUrl  = args["subtitleUrl"]          as? String ?: ""
        val subtitleLang = args["subtitleLanguage"]     as? String ?: "en"

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE,    title)
            putString(MediaMetadata.KEY_SUBTITLE, description)
        }

        val tracks = mutableListOf<MediaTrack>()
        if (subtitleUrl.isNotEmpty()) {
            tracks.add(
                MediaTrack.Builder(1L, MediaTrack.TYPE_TEXT)
                    .setName("Subtitle")
                    .setSubtype(MediaTrack.SUBTYPE_SUBTITLES)
                    .setContentId(subtitleUrl)
                    .setContentType("text/vtt")
                    .setLanguage(subtitleLang)
                    .build()
            )
        }

        val mediaInfo = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(mimeType)
            .setMetadata(metadata)
            .apply { if (tracks.isNotEmpty()) setMediaTracks(tracks) }
            .build()

        val loadRequest = MediaLoadRequestData.Builder()
            .setMediaInfo(mediaInfo)
            .setCurrentTime(positionMs)
            .setAutoplay(true)
            .apply {
                if (tracks.isNotEmpty()) setActiveTrackIds(longArrayOf(1L))
            }
            .build()

        mainHandler.post {
            session.remoteMediaClient?.load(loadRequest)
                ?.setResultCallback { result.success(true) }
                ?: result.success(false)
        }
    }

    private fun resolveMime(url: String) = when {
        url.contains(".m3u8") -> "application/x-mpegURL"
        url.contains(".mpd")  -> "application/dash+xml"
        url.contains(".mp4")  -> "video/mp4"
        else                  -> "video/mp4"
    }

    // ── EventChannel StreamHandler ────────────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Activity байвал init хийнэ, үгүй бол setActivity() дуудагдах үед хийнэ
        if (activity != null && !initialized) {
            initCast()
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopPolling()
    }

    // ── Event helpers ─────────────────────────────────────────────────────
    private fun emitCastState(state: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "castState", "state" to state))
        }
    }

    private fun emitRemoteState() {
        val client = currentSession?.remoteMediaClient ?: return
        val status = client.mediaStatus ?: return
        val info = mapOf(
            "type"         to "remoteState",
            "sessionState" to when (status.playerState) {
                RemoteMediaClient.PLAYER_STATE_PLAYING   -> "playing"
                RemoteMediaClient.PLAYER_STATE_PAUSED    -> "paused"
                RemoteMediaClient.PLAYER_STATE_BUFFERING -> "buffering"
                RemoteMediaClient.PLAYER_STATE_LOADING   -> "loading"
                else                                     -> "idle"
            },
            "positionMs"   to client.approximateStreamPosition,
            "durationMs"   to (status.mediaInfo?.streamDuration ?: 0L),
            "isPlaying"    to (status.playerState == RemoteMediaClient.PLAYER_STATE_PLAYING),
            "volume"       to (currentSession?.volume ?: 1.0),
            "isMuted"      to (currentSession?.isMute ?: false),
        )
        mainHandler.post { eventSink?.success(info) }
    }

    // ── Polling ───────────────────────────────────────────────────────────
    private fun startPolling() {
        stopPolling()
        pollingRunnable = object : Runnable {
            override fun run() {
                emitRemoteState()
                mainHandler.postDelayed(this, 200L)
            }
        }
        mainHandler.postDelayed(pollingRunnable!!, 200L)
    }

    private fun stopPolling() {
        pollingRunnable?.let { mainHandler.removeCallbacks(it) }
        pollingRunnable = null
    }

    // ── Cleanup ───────────────────────────────────────────────────────────
    fun dispose() {
        stopPolling()
        try {
            castContext?.sessionManager?.removeSessionManagerListener(
                sessionListener, CastSession::class.java
            )
        } catch (_: Exception) {}
        eventSink = null
        activity = null
    }
}