package dev.senzu.senzu_player

import android.app.Activity
import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.EventChannel

// ─────────────────────────────────────────────────────────────────────────────
// SenzuPipManager
// Manages Android Picture-in-Picture (PiP) mode for the video player.
// Requires Android 8.0 (API 26)+ and
//   android:supportsPictureInPicture="true" in the activity manifest entry.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Encapsulates all PiP logic so [SenzuExoPlayerManager] stays focused on
 * media playback concerns.
 *
 * Usage:
 * 1. Call [enable] / [disable] to opt in or out of PiP.
 * 2. Call [enter] to request the system to enter PiP mode.
 * 3. Forward [Activity.onPictureInPictureModeChanged] results to
 *    [onPictureInPictureModeChanged] so the Flutter layer receives state events.
 *
 * @param getActivity  Lambda returning the current foreground [Activity], or null.
 */
class SenzuPipManager(private val getActivity: () -> Activity?) {

    private var pipEnabled: Boolean = false
    private var eventSink: EventChannel.EventSink? = null

    // ── EventSink ──────────────────────────────────────────────────────────

    /** Attaches the Flutter event sink used to emit PiP state changes. */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    // ── Support check ──────────────────────────────────────────────────────

    /**
     * Returns true if the device and OS version support PiP.
     * Requires Android 8.0 (API 26) and the
     * [PackageManager.FEATURE_PICTURE_IN_PICTURE] system feature.
     */
    fun isSupported(): Boolean {
        val activity = getActivity() ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else false
    }

    // ── Enable / Disable ───────────────────────────────────────────────────

    /** Opts the player in to PiP. [enter] will succeed only after this is called. */
    fun enable() {
        pipEnabled = true
    }

    /** Opts the player out of PiP. */
    fun disable() {
        pipEnabled = false
    }

    // ── Enter ──────────────────────────────────────────────────────────────

    /**
     * Requests the system to enter PiP mode.
     * Returns true on success, false if PiP is unsupported, not enabled,
     * or the activity is unavailable.
     */
    fun enter(): Boolean {
        if (!pipEnabled || !isSupported()) return false
        val activity = getActivity() ?: return false

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                activity.enterPictureInPictureMode(buildPipParams())
                true
            } catch (e: Exception) {
                false
            }
        } else false
    }

    // ── Exit ───────────────────────────────────────────────────────────────

    /**
     * Exits PiP by bringing the task back to the foreground via
     * [ActivityManager.moveTaskToFront].
     */
    fun exit() {
        val activity = getActivity() ?: return
        val am = activity.getSystemService(android.content.Context.ACTIVITY_SERVICE) as? ActivityManager
        am?.moveTaskToFront(activity.taskId, 0)
    }

    // ── Lifecycle callback ─────────────────────────────────────────────────

    /**
     * Forward this from [Activity.onPictureInPictureModeChanged] so the
     * Flutter layer receives a `pip` event with the current state.
     */
    fun onPictureInPictureModeChanged(isInPipMode: Boolean) {
        emitPipState(isActive = isInPipMode)
    }

    // ── Event emission ─────────────────────────────────────────────────────

    private fun emitPipState(isActive: Boolean) {
        eventSink?.success(
            mapOf(
                "type"       to "pip",
                "isPossible" to isSupported(),
                "isActive"   to isActive
            )
        )
    }

    // ── PiP params ─────────────────────────────────────────────────────────

    /**
     * Builds [PictureInPictureParams] with a 16:9 aspect ratio.
     * On Android 12+ (API 31) also enables auto-enter and seamless resize.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: automatically enter PiP when the user swipes home
            builder.setAutoEnterEnabled(true)
            // Smooth resize animation when PiP window is resized
            builder.setSeamlessResizeEnabled(true)
        }

        return builder.build()
    }
}