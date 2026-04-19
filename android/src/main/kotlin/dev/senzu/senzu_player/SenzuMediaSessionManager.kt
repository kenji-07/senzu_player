package dev.senzu.senzu_player

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.plugin.common.EventChannel
import java.net.URL
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────────────────────
// SenzuMediaSessionManager
// Manages Android Now Playing / Lock Screen controls via MediaSession and
// a persistent media notification in the notification shade.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manages a [MediaSessionCompat] and its associated media notification.
 *
 * Responsibilities:
 * - Creating and activating a [MediaSessionCompat].
 * - Reflecting playback state and metadata on the lock screen.
 * - Posting a media-style notification with transport actions.
 * - Forwarding remote control commands (play, pause, seek, etc.) to Flutter
 *   via [EventChannel.EventSink].
 * - Caching album artwork fetched from a remote URL.
 *
 * @param context     Application context.
 * @param getActivity Lambda that returns the current foreground [Activity], or null.
 */
class SenzuMediaSessionManager(
    private val context: Context,
    private val getActivity: () -> Activity?
) {

    // ── MediaSession state ─────────────────────────────────────────────────

    private var mediaSession: MediaSessionCompat? = null
    private var eventSink: EventChannel.EventSink? = null
    private var enabled: Boolean = false

    // ── Metadata ───────────────────────────────────────────────────────────

    private var title: String = ""
    private var artist: String = ""
    private var artworkUrl: String? = null
    private var isLive: Boolean = false
    private var durationMs: Long = 0L

    // ── Playback state ─────────────────────────────────────────────────────

    private var positionMs: Long = 0L
    private var isPlaying: Boolean = false
    private var playbackSpeed: Float = 1.0f

    // ── Artwork cache ──────────────────────────────────────────────────────

    private var cachedArtwork: Bitmap? = null
    private var cachedArtworkUrl: String? = null
    private val artworkExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Constants ──────────────────────────────────────────────────────────

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "senzu_player_media"
        private const val NOTIFICATION_ID = 1001
        private const val SESSION_TAG = "SenzuPlayer"
    }

    // ── Public API ─────────────────────────────────────────────────────────

    /** Attaches the Flutter event sink used to forward remote commands. */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * Enables the media session and shows the media notification.
     * Initialises the session if not yet created.
     */
    fun enable() {
        enabled = true
        if (mediaSession == null) initSession()
        updateMetadata()
        updatePlaybackState()
        showNotification()
    }

    /**
     * Disables the media session and removes the media notification.
     */
    fun disable() {
        enabled = false
        teardown()
    }

    /**
     * Updates title, artist, artwork URL, and live-stream flag from Dart args.
     * Triggers an artwork fetch if the URL has changed.
     */
    fun setMetadata(args: Map<*, *>?) {
        title      = args?.get("title")   as? String ?: title
        artist     = args?.get("artist")  as? String ?: artist
        artworkUrl = args?.get("artwork") as? String ?: artworkUrl
        isLive     = args?.get("isLive")  as? Boolean ?: isLive

        if (enabled) {
            updateMetadata()
            fetchArtworkIfNeeded { updateMetadata(); if (enabled) showNotification() }
        }
    }

    /**
     * Syncs playback position, duration, playing state, and speed.
     * Called periodically by [SenzuExoPlayerManager] during playback.
     */
    fun updatePlaybackState(
        posMs: Long = positionMs,
        durMs: Long = durationMs,
        playing: Boolean = isPlaying,
        speed: Float = playbackSpeed
    ) {
        positionMs    = posMs
        durationMs    = durMs
        isPlaying     = playing
        playbackSpeed = speed

        if (!enabled) return
        updateMetadata()
        updatePlaybackStateInternal()
        if (enabled) showNotification()
    }

    // ── Session initialisation ─────────────────────────────────────────────

    /** Creates and activates a new [MediaSessionCompat] with transport callbacks. */
    private fun initSession() {
        val session = MediaSessionCompat(context, SESSION_TAG)
        mediaSession = session

        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                eventSink?.success(mapOf("type" to "remote", "action" to "play"))
            }
            override fun onPause() {
                eventSink?.success(mapOf("type" to "remote", "action" to "pause"))
            }
            override fun onSkipToNext() {
                eventSink?.success(mapOf("type" to "remote", "action" to "skipForward", "interval" to 15.0))
            }
            override fun onSkipToPrevious() {
                eventSink?.success(mapOf("type" to "remote", "action" to "skipBackward", "interval" to 15.0))
            }
            override fun onSeekTo(pos: Long) {
                eventSink?.success(mapOf("type" to "remote", "action" to "seek", "positionSec" to pos / 1000.0))
            }
            override fun onFastForward() {
                eventSink?.success(mapOf("type" to "remote", "action" to "skipForward", "interval" to 15.0))
            }
            override fun onRewind() {
                eventSink?.success(mapOf("type" to "remote", "action" to "skipBackward", "interval" to 15.0))
            }
            override fun onStop() {
                eventSink?.success(mapOf("type" to "remote", "action" to "pause"))
            }
        })

        session.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        session.isActive = true
        createNotificationChannel()
    }

    // ── Metadata / state helpers ───────────────────────────────────────────

    /** Pushes current title, artist, duration, and artwork to the session. */
    private fun updateMetadata() {
        val session = mediaSession ?: return
        val builder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE,  title.ifEmpty { "SenzuPlayer" })
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, if (isLive) -1L else durationMs)

        cachedArtwork?.let {
            builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it)
        }

        session.setMetadata(builder.build())
    }

    /** Pushes the current playback state (playing/paused, position, speed) to the session. */
    private fun updatePlaybackStateInternal() {
        val session = mediaSession ?: return
        val actions = (PlaybackStateCompat.ACTION_PLAY
            or PlaybackStateCompat.ACTION_PAUSE
            or PlaybackStateCompat.ACTION_PLAY_PAUSE
            or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            or PlaybackStateCompat.ACTION_FAST_FORWARD
            or PlaybackStateCompat.ACTION_REWIND
            or PlaybackStateCompat.ACTION_SEEK_TO
            or PlaybackStateCompat.ACTION_STOP)

        val state = if (isPlaying)
            PlaybackStateCompat.STATE_PLAYING
        else
            PlaybackStateCompat.STATE_PAUSED

        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(state, positionMs, playbackSpeed)
                .setActions(actions)
                .build()
        )
    }

    // ── Media notification ─────────────────────────────────────────────────

    /**
     * Builds and posts a media-style notification with skip-back, play/pause,
     * and skip-forward actions. Silently ignores missing POST_NOTIFICATIONS permission.
     */
    private fun showNotification() {
        val session = mediaSession ?: return
        val token   = session.sessionToken

        val playPauseAction = if (isPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause, "Pause",
                androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
                    context, PlaybackStateCompat.ACTION_PAUSE
                )
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play, "Play",
                androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
                    context, PlaybackStateCompat.ACTION_PLAY
                )
            )
        }

        val skipBackAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Back 15s",
            androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
                context, PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
        )

        val skipFwdAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Fwd 15s",
            androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
                context, PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            )
        )

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title.ifEmpty { "SenzuPlayer" })
            .setContentText(artist)
            .setLargeIcon(cachedArtwork)
            .addAction(skipBackAction)
            .addAction(playPauseAction)
            .addAction(skipFwdAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(token)
                    .setShowActionsInCompactView(0, 1, 2)
                    .setShowCancelButton(true)
                    .setCancelButtonIntent(
                        androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
                            context, PlaybackStateCompat.ACTION_STOP
                        )
                    )
            )
            .setOngoing(isPlaying)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — fail silently
        }
    }

    // ── Artwork fetching ───────────────────────────────────────────────────

    /**
     * Fetches artwork from [artworkUrl] on a background thread if the URL
     * differs from the cached one. Invokes [onComplete] on the main thread
     * regardless of success or failure.
     */
    private fun fetchArtworkIfNeeded(onComplete: () -> Unit) {
        val url = artworkUrl ?: return
        if (url == cachedArtworkUrl && cachedArtwork != null) { onComplete(); return }

        artworkExecutor.execute {
            try {
                val bitmap = BitmapFactory.decodeStream(URL(url).openStream())
                mainHandler.post {
                    cachedArtwork    = bitmap
                    cachedArtworkUrl = url
                    onComplete()
                }
            } catch (_: Exception) {
                mainHandler.post { onComplete() }
            }
        }
    }

    // ── Notification channel ───────────────────────────────────────────────

    /** Creates the low-importance notification channel required on Android 8+. */
    private fun createNotificationChannel() {
        val channel = NotificationChannelCompat.Builder(
            NOTIFICATION_CHANNEL_ID,
            NotificationManagerCompat.IMPORTANCE_LOW
        )
            .setName("Media Playback")
            .setDescription("SenzuPlayer media controls")
            .setShowBadge(false)
            .build()
        NotificationManagerCompat.from(context).createNotificationChannel(channel)
    }

    // ── Teardown ───────────────────────────────────────────────────────────

    /**
     * Cancels the notification, deactivates, and releases the media session.
     */
    fun teardown() {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        isPlaying = false
    }
}