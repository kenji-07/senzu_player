package dev.senzu.senzu_player

import android.content.Context
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class SenzuCastPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var castContext: CastContext? = null
    private var currentSession: CastSession? = null
    private var pollingRunnable: Runnable? = null

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

    fun init() {
        mainHandler.post {
            try {
                castContext = CastContext.getSharedInstance(context)
                castContext?.sessionManager?.addSessionManagerListener(
                    sessionListener, CastSession::class.java
                )
                currentSession = castContext?.sessionManager?.currentCastSession
            } catch (e: Exception) {
                android.util.Log.e("SenzuCast", "Cast init failed: ${e.message}")
            }
        }
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showDevicePicker" -> {
                // MediaRouter dialog нээнэ
                mainHandler.post {
                    val fragmentManager =
                        (context as? androidx.fragment.app.FragmentActivity)
                            ?.supportFragmentManager
                    fragmentManager?.let {
                        androidx.mediarouter.app.MediaRouteChooserDialogFragment()
                            .show(it, "SenzuCastPicker")
                    }
                }
                result.success(null)
            }
            "loadMedia" -> {
                val args = call.arguments as? Map<*, *>
                loadMedia(args, result)
            }
            "play"  -> { currentSession?.remoteMediaClient?.play();   result.success(null) }
            "pause" -> { currentSession?.remoteMediaClient?.pause();  result.success(null) }
            "stop"  -> { currentSession?.remoteMediaClient?.stop();   result.success(null) }
            "seekTo" -> {
                val posMs = (call.arguments as? Map<*, *>)
                    ?.get("positionMs") as? Int ?: 0
                currentSession?.remoteMediaClient?.seek(
                    RemoteMediaClient.SeekOptions.Builder()
                        .setPosition(posMs.toLong())
                        .build()
                )
                result.success(null)
            }
            "disconnect" -> {
                castContext?.sessionManager?.endCurrentSession(true)
                result.success(null)
            }
            "getCastState" -> {
                val state = if (currentSession != null) "connected" else "notConnected"
                result.success(state)
            }
            else -> result.notImplemented()
        }
    }

    private fun loadMedia(args: Map<*, *>?, result: MethodChannel.Result) {
        val session = currentSession
        if (session == null) {
            result.success(false)
            return
        }
        val url         = args?.get("url")         as? String ?: return result.success(false)
        val title       = args["title"]             as? String ?: ""
        val description = args["description"]       as? String ?: ""
        val posterUrl   = args["posterUrl"]         as? String ?: ""
        val mimeType    = args["mimeType"]          as? String ?: "video/mp4"
        val positionMs  = (args["positionMs"]       as? Int)?.toLong() ?: 0L
        val subtitleUrl = args["subtitleUrl"]       as? String ?: ""
        val subtitleLang= args["subtitleLanguage"]  as? String ?: "en"

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE,    title)
            putString(MediaMetadata.KEY_SUBTITLE, description)
        }

        // Subtitle track
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
            .setMediaTracks(tracks)
            .build()

        val loadRequest = MediaLoadRequestData.Builder()
            .setMediaInfo(mediaInfo)
            .setCurrentTime(positionMs)
            .setAutoplay(true)
            .setActiveTrackIds(if (tracks.isNotEmpty()) longArrayOf(1L) else null)
            .build()

        session.remoteMediaClient?.load(loadRequest)
            ?.setResultCallback { result.success(true) }
            ?: result.success(false)
    }

    // ── Event emission ─────────────────────────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        init()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopPolling()
    }

    private fun emitCastState(state: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "castState", "state" to state))
        }
    }

    private fun emitRemoteState() {
        val client = currentSession?.remoteMediaClient ?: return
        val status = client.mediaStatus ?: return
        val info   = mapOf(
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

    // ── Position polling (200ms) ───────────────────────────────────────────
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
}