package dev.senzu.senzu_player

import android.app.Activity
import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.Context
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.EventChannel

/**
 * SenzuPipManager — Android Picture-in-Picture удирдлага
 *
 * iOS-тэй адил функциональ байдлыг хангана:
 *   • enablePip / disablePip
 *   • enterPip / exitPip
 *   • isPipSupported
 *   • Pip state event emission
 *
 * Android 8.0 (API 26)+ шаардлагатай.
 * Manifest-д android:supportsPictureInPicture="true" нэмэх шаардлагатай.
 */
class SenzuPipManager(private val getActivity: () -> Activity?) {

    private var pipEnabled: Boolean = false
    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    // ── PiP дэмжигдэж байгаа эсэх ─────────────────────────────────────────
    fun isSupported(): Boolean {
        val activity = getActivity() ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else false
    }

    // ── Enable / Disable ───────────────────────────────────────────────────
    fun enable() {
        pipEnabled = true
    }

    fun disable() {
        pipEnabled = false
    }

    // ── Enter PiP ─────────────────────────────────────────────────────────
    fun enter(): Boolean {
        if (!pipEnabled || !isSupported()) return false
        val activity = getActivity() ?: return false

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = buildPipParams()
            try {
                activity.enterPictureInPictureMode(params)
                true
            } catch (e: Exception) {
                false
            }
        } else false
    }

    // ── Exit PiP — Activity-г foreground руу буцаана ──────────────────────
    fun exit() {
        val activity = getActivity() ?: return
        val am = activity.getSystemService(android.content.Context.ACTIVITY_SERVICE) as? ActivityManager
        am?.moveTaskToFront(activity.taskId, 0)
    }

    // ── Activity PiP callback-уудыг хүлээн авна (FlutterActivity-аас) ────
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

    // ── PiP params builder ─────────────────────────────────────────────────
    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: auto-enter PiP when user swipes home
            builder.setAutoEnterEnabled(true)
            // Seamless resize animation
            builder.setSeamlessResizeEnabled(true)
        }

        return builder.build()
    }
}